import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Wallet-style view of royalties received.
class PayoutsScreen extends StatelessWidget {
  const PayoutsScreen({super.key});

  Future<void> _pickSheet(BuildContext context, AppState state) async {
    final options = state.allSheets.where((s) => s.status == SheetStatus.executed).toList();
    if (options.isEmpty) {
      showSnack(context, 'Royalties can only go into a fully signed sheet.');
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 440),
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            Text('Pay into which song?', style: T.display(22)),
            const SizedBox(height: 14),
            for (final s in options)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: CoverArt(s.title, size: 44, radius: 8),
                title: Text(s.title, style: T.body(15, weight: FontWeight.w700)),
                subtitle: Text('${s.contributors.length} people · v${s.version}', style: T.body(13, color: C.muted)),
                trailing: const Icon(Icons.chevron_right_rounded, color: C.muted),
                onTap: () => Navigator.of(c).pop(s.id),
              ),
          ],
        ),
      ),
    );
    if (id != null && context.mounted) context.push('/deposit/$id');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final payouts = state.allPayouts.where((p) => state.myShare(p) > 0).toList();
    final bySheet = <String, int>{};
    for (final p in payouts) {
      bySheet[p.sheetId] = (bySheet[p.sheetId] ?? 0) + state.myShare(p);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(children: [
          Expanded(child: Text('Payouts', style: T.display(28))),
          const Pill('Testnet demo', background: Colors.transparent, foreground: C.accentSoft, border: C.lineWarm),
        ]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A2A0E), Color(0xFF1E1B14)],
            ),
            border: Border.all(color: C.lineWarm),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total earned', style: T.body(13, color: C.accentSoft)),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Flexible(child: Text(fmtUsdc(state.balanceMicros), overflow: TextOverflow.ellipsis, style: T.display(40))),
              const SizedBox(width: 8),
              Text('USDC', style: T.body(17, color: C.text2, weight: FontWeight.w500)),
            ]),
            const SizedBox(height: 4),
            Text(
              bySheet.isEmpty ? 'Nothing received yet' : 'From ${bySheet.length} ${bySheet.length == 1 ? 'song' : 'songs'}',
              style: T.body(13, color: C.muted),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.south_west_rounded,
                  label: 'Pay into a song',
                  onTap: () => _pickSheet(context, state),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.account_balance_outlined,
                  label: 'Withdraw',
                  onTap: () => showSnack(context, 'Cash-out to naira is on the roadmap. These are testnet funds.'),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 26),
        if (bySheet.isNotEmpty) ...[
          SectionHeader('By song'),
          const SizedBox(height: 10),
          for (final e in bySheet.entries)
            if (state.byId(e.key) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => context.push('/sheet/${e.key}'),
                  child: Row(children: [
                    CoverArt(state.byId(e.key)!.title, size: 48, radius: 8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(state.byId(e.key)!.title,
                          overflow: TextOverflow.ellipsis, style: T.body(15, weight: FontWeight.w700)),
                    ),
                    Text('+${fmtUsdc(e.value)}', style: T.mono(15, color: C.green)),
                  ]),
                ),
              ),
          const SizedBox(height: 16),
          SectionHeader('Activity'),
          const SizedBox(height: 10),
          for (final p in payouts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: C.greenBg, shape: BoxShape.circle),
                  child: const Icon(Icons.south_west_rounded, color: C.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(state.byId(p.sheetId)?.title ?? 'Song', style: T.body(15, weight: FontWeight.w500)),
                    Text('${p.splitType.label} split · ${fmtDate(p.createdAt)} · ${shortHex(p.txHash)}',
                        overflow: TextOverflow.ellipsis, style: T.body(12, color: C.muted)),
                  ]),
                ),
                Text('+${fmtUsdc(state.myShare(p))}', style: T.mono(15, color: C.green)),
              ]),
            ),
        ] else
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.savings_outlined, color: C.accent, size: 32),
              const SizedBox(height: 12),
              Text('No royalties yet', style: T.display(22)),
              const SizedBox(height: 6),
              Text(
                'Once a sheet is locked in, a label or distributor can pay into it and every share arrives at the same moment.',
                style: T.body(14, color: C.muted, height: 1.45),
              ),
            ]),
          ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: C.accent),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: T.body(14, weight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}
