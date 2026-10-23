import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/splits.dart';
import '../widgets/common.dart';

/// Pay royalties into a signed sheet; each share is paid out in the same transaction.
class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key, required this.id});
  final String id;

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  SplitType _type = SplitType.composition;
  final _amount = TextEditingController(text: '500');
  bool _busy = false;
  Payout? _done;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pay(AppState state, SplitSheet s) async {
    final micros = parseUsdc(_amount.text);
    if (micros == null || micros <= 0) {
      showSnack(context, 'Enter an amount above zero');
      return;
    }
    if (micros > 1000000000000) {
      showSnack(context, 'That is more than this demo allows');
      return;
    }
    setState(() => _busy = true);
    try {
      final p = await state.deposit(s.id, _type, micros);
      if (mounted) setState(() => _done = p);
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.byId(widget.id);
    if (s == null) return const NotFoundView();
    final micros = parseUsdc(_amount.text) ?? 0;
    final shares = splitAmount(micros < 0 ? 0 : micros, s.bpsFor(_type));
    final me = state.myIndex(s);

    if (_done != null) return _success(context, s, _done!, me);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              children: [
                TopBar(onBack: () => goBack(context, '/sheet/${s.id}'), label: 'Testnet demo'),
                const SizedBox(height: 20),
                Text('Pay royalties into ${s.title}', style: T.display(28)),
                const SizedBox(height: 6),
                Text('Everyone is paid their signed share at once.', style: T.body(14, color: C.muted)),
                const SizedBox(height: 20),
                if (s.status != SheetStatus.executed)
                  SurfaceCard(
                    child: Text('This sheet is not fully signed yet, so it cannot receive royalties.',
                        style: T.body(14, color: C.text2)),
                  )
                else ...[
                  Text('Which royalties are these?', style: T.body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _TypeOption(
                    title: 'Composition (publishing)',
                    subtitle: 'Pays writers and producers on the song',
                    selected: _type == SplitType.composition,
                    onTap: () => setState(() => _type = SplitType.composition),
                  ),
                  const SizedBox(height: 10),
                  _TypeOption(
                    title: 'Master (recording)',
                    subtitle: 'Pays the owners of this recording',
                    selected: _type == SplitType.master,
                    onTap: () => setState(() => _type = SplitType.master),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: T.mono(22),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: 'USDC',
                      suffixStyle: T.body(15, color: C.muted, weight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    for (final v in const ['100', '500', '1000'])
                      SelectChip(
                        label: '${fmtUsdc(int.parse(v) * 1000000)} USDC',
                        selected: _amount.text == v,
                        onTap: () => setState(() => _amount.text = v),
                      ),
                  ]),
                  const SizedBox(height: 20),
                  SurfaceCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Who gets what', style: T.body(15, weight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      SplitBar(bps: s.bpsFor(_type), height: 10),
                      const SizedBox(height: 8),
                      for (var i = 0; i < s.contributors.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                '${s.contributors[i].displayName}${i == me ? ' (you)' : ''} · ${fmtPct(s.contributors[i].bps(_type))}',
                                overflow: TextOverflow.ellipsis,
                                style: T.body(14),
                              ),
                            ),
                            Text(fmtUsdc(shares[i]), style: T.mono(14)),
                          ]),
                        ),
                      const Divider(height: 18),
                      Row(children: [
                        Expanded(child: Text('Total', style: T.body(14, weight: FontWeight.w700))),
                        Text('${fmtUsdc(micros)} USDC', style: T.mono(14, weight: FontWeight.w500)),
                      ]),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          if (s.status == SheetStatus.executed)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: PrimaryButton(
                label: 'Pay ${fmtUsdc(micros)} USDC',
                loading: _busy,
                onPressed: micros > 0 ? () => _pay(state, s) : null,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _success(BuildContext context, SplitSheet s, Payout p, int? me) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: C.greenBg, shape: BoxShape.circle, border: Border.all(color: C.green, width: 2)),
                child: const Icon(Icons.check_rounded, color: C.green, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text('${fmtUsdc(p.amountMicros)} USDC paid out', textAlign: TextAlign.center, style: T.display(28)),
            const SizedBox(height: 6),
            Text('${s.title} · ${p.splitType.label} split', textAlign: TextAlign.center, style: T.body(14, color: C.muted)),
            const SizedBox(height: 22),
            SurfaceCard(
              child: Column(children: [
                for (var i = 0; i < s.contributors.length; i++)
                  if (p.shares[i] > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Expanded(
                          child: Text('${s.contributors[i].displayName}${i == me ? ' (you)' : ''}',
                              overflow: TextOverflow.ellipsis, style: T.body(14)),
                        ),
                        Text('+${fmtUsdc(p.shares[i])}', style: T.mono(14, color: C.green)),
                      ]),
                    ),
                const Divider(height: 18),
                InfoRow(label: 'Record', value: shortHex(p.txHash, head: 8, tail: 6), copyValue: p.txHash),
              ]),
            ),
            const Spacer(),
            PrimaryButton(label: 'Done', onPressed: () => context.go('/payouts')),
          ]),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: SurfaceCard(
        color: selected ? C.surfaceWarm : C.surface,
        borderColor: selected ? C.accent : C.line2,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? C.accent : C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.body(15, weight: FontWeight.w500)),
              Text(subtitle, style: T.body(13, color: C.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
