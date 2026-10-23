import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/hashing.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Join a sheet by code, link or QR, then pick which person you are.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.code});
  final String? code;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final TextEditingController _ctl = TextEditingController(text: widget.code ?? '');
  bool _searched = false;
  bool _searching = false;
  int? _claiming;
  SplitSheet? _found;

  @override
  void initState() {
    super.initState();
    if ((widget.code ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _find());
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final code = extractInviteCode(_ctl.text) ?? _ctl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _ctl.text = code;
      _searching = true;
    });
    final s = await context.read<AppState>().findByCode(code);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      _found = s;
    });
  }

  Future<void> _scan() async {
    final raw = await context.push<String>('/scan');
    if (raw == null || !mounted) return;
    final code = extractInviteCode(raw);
    if (code == null) {
      showSnack(context, 'That QR code is not a Split Sheet invite');
      return;
    }
    _ctl.text = code;
    await _find();
  }

  Future<void> _join(SplitSheet s, int index) async {
    final state = context.read<AppState>();
    if (state.myIndex(s) == index) {
      context.push('/sheet/${s.id}/sign/$index');
      return;
    }
    setState(() => _claiming = index);
    try {
      final joined = await state.claimSlot(s.id, index);
      if (!mounted) return;
      setState(() {
        _claiming = null;
        _found = joined;
      });
      context.push('/sheet/${s.id}/sign/$index');
    } catch (e) {
      if (!mounted) return;
      setState(() => _claiming = null);
      showSnack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = _found == null ? null : (state.byId(_found!.id) ?? _found);
    final mine = s == null ? null : state.myIndex(s);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            TopBar(onBack: () => goBack(context, '/home')),
            const SizedBox(height: 20),
            Text('Join a split sheet', style: T.display(28)),
            const SizedBox(height: 6),
            Text('Scan the QR code on the creator\'s phone, or type the code under it.',
                style: T.body(14, color: C.muted, height: 1.45)),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Scan QR code', icon: Icons.qr_code_scanner_rounded, onPressed: _scan),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or enter the code', style: T.body(13, color: C.muted)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  textCapitalization: TextCapitalization.characters,
                  style: T.mono(18),
                  onSubmitted: (_) => _find(),
                  decoration: const InputDecoration(hintText: 'ABC-1234'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: PrimaryButton(label: 'Find', loading: _searching, onPressed: _find),
              ),
            ]),
            const SizedBox(height: 22),
            if (_searched && s == null)
              SurfaceCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('No open sheet with that code', style: T.body(15, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Check the code with the person who made the sheet. Codes stop working once everyone has signed or the sheet is cancelled.',
                    style: T.body(14, color: C.muted, height: 1.45),
                  ),
                ]),
              ),
            if (s != null) ...[
              SurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  CoverArt(s.title, size: 56, radius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.title, style: T.body(16, weight: FontWeight.w700)),
                      Text('From ${s.creator.displayName} · ${fmtDate(s.sessionDate)}', style: T.body(13, color: C.muted)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text(mine == null ? 'Which one are you?' : 'You joined as ${s.contributors[mine].displayName}',
                  style: T.display(20)),
              const SizedBox(height: 4),
              Text('Pick your name. You will see your share before you sign.', style: T.body(13, color: C.muted)),
              const SizedBox(height: 12),
              for (var i = 0; i < s.contributors.length; i++)
                _slot(context, state, s, i, mine),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, AppState state, SplitSheet s, int i, int? mine) {
    final c = s.contributors[i];
    final holder = s.claims[i];
    final signed = s.isSigned(i);
    final isMine = mine == i;
    final takenByOther = holder != null && !isMine;
    final canPick = !signed && !takenByOther && (mine == null || isMine) && s.status == SheetStatus.pending;
    final String status;
    if (signed) {
      status = 'Signed';
    } else if (isMine) {
      status = 'You · review and sign';
    } else if (takenByOther) {
      status = 'Joined on their phone';
    } else {
      status = '';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(12),
        borderColor: isMine ? C.lineWarm : C.line,
        onTap: canPick && _claiming == null ? () => _join(s, i) : null,
        child: Row(children: [
          Avatar(c.displayName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.displayName, style: T.body(15, weight: FontWeight.w500)),
              Text(status.isEmpty ? c.rolesLabel : '${c.rolesLabel} · $status',
                  style: T.body(12, color: signed ? C.green : C.muted)),
            ]),
          ),
          if (_claiming == i)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (canPick)
            const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      ),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _done = true;
        context.pop(v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: MobileScanner(controller: _controller, onDetect: _onDetect)),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: C.accent, width: 3),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              TopBar(icon: Icons.close_rounded, onBack: () => context.pop()),
              const Spacer(),
              Text('Point at the QR code on the creator\'s phone',
                  textAlign: TextAlign.center, style: T.body(15, weight: FontWeight.w500)),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }
}
