import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/chain_service.dart';
import '../services/hashing.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';

/// Public verification page. No account needed.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key, this.id});
  final String? id;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  Future<(LedgerRecord?, SplitSheet?)>? _future;
  final _idCtl = TextEditingController();
  bool _checking = false;
  bool? _fileMatch;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VerifyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _fileMatch = null;
      _fileName = null;
      _load();
    }
  }

  void _load() {
    final id = widget.id;
    _future = id == null ? null : _fetch(context.read<AppState>(), id);
  }

  /// The ledger record is public. Names and roles come from the sheet, which only people on it
  /// (or anyone signed in, while it is still open) can read.
  static Future<(LedgerRecord?, SplitSheet?)> _fetch(AppState state, String id) async {
    LedgerRecord? record;
    try {
      record = await state.chain.getSheet(id);
    } catch (_) {
      record = null;
    }
    final sheet = record == null || state.signedOut ? null : await state.fetchSheet(id);
    return (record, sheet);
  }

  @override
  void dispose() {
    _idCtl.dispose();
    super.dispose();
  }

  Future<void> _checkFile(LedgerRecord r) async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) return;
      setState(() => _checking = true);
      final hash = await compute(sha256Hex, bytes.toList());
      if (!mounted) return;
      setState(() {
        _checking = false;
        _fileName = f.name;
        _fileMatch = r.audioHash != null && hash == r.audioHash;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      showSnack(context, 'Could not read that file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          const SiteNav(subtitle: 'Verify'),
          SiteBand(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 64),
            child: widget.id == null ? _lookup() : _result(),
          ),
          const SiteFooter(),
        ]),
      ),
    );
  }

  Widget _lookup() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verify a split sheet', style: T.display(isWide(context) ? 52 : 36, height: 1.05)),
        const SizedBox(height: 12),
        Text('Scan the QR code on a signed PDF, or enter the sheet ID printed under it.',
            style: T.body(17, color: C.text2, height: 1.5)),
        const SizedBox(height: 28),
        TextField(
          controller: _idCtl,
          style: T.mono(17),
          onSubmitted: (_) => _go(),
          decoration: const InputDecoration(labelText: 'Sheet ID', hintText: 'ss_…'),
        ),
        const SizedBox(height: 14),
        PillButton(label: 'Check this sheet', icon: Icons.arrow_forward_rounded, onTap: _go),
      ]),
    );
  }

  void _go() {
    final id = _idCtl.text.trim();
    if (id.isEmpty) return;
    context.go('/verify/$id');
  }

  Widget _result() {
    return FutureBuilder<(LedgerRecord?, SplitSheet?)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
        }
        final r = snap.data?.$1;
        if (r == null) return _notFound();
        final sheet = context.watch<AppState>().byId(r.sheetId) ?? snap.data?.$2;
        final genuine = sheet == null ? null : computeDocHash(sheet) == r.docHash;
        return _record(r, sheet, genuine);
      },
    );
  }

  Widget _notFound() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Pill('Not found', background: C.redBg, foreground: C.red, border: C.redLine),
        const SizedBox(height: 16),
        Text('No record for ${widget.id}', style: T.display(36, height: 1.1)),
        const SizedBox(height: 12),
        Text(
          'Check the ID and try again. The ID is printed under the QR code on the signed PDF.',
          style: T.body(16, color: C.text2, height: 1.5),
        ),
        const SizedBox(height: 22),
        PillButton(label: 'Check another sheet', filled: false, onTap: () => context.go('/verify')),
      ]),
    );
  }

  Widget _record(LedgerRecord r, SplitSheet? sheet, bool? genuine) {
    final wide = isWide(context);
    final Pill status;
    final String headline;
    if (genuine == false) {
      status = const Pill('Does not match the record', background: C.redBg, foreground: C.red, border: C.redLine);
      headline = 'These terms differ from what was signed.';
    } else {
      switch (r.status) {
        case 'executed':
          status = const Pill('Genuine · Executed', background: C.green, foreground: C.onGreen);
          headline = 'Signed by all ${r.partyCount} parties. Unchanged since.';
          break;
        case 'pending':
          status = const Pill('Collecting signatures', background: C.accentBg, foreground: C.accentSoft, border: C.lineWarm);
          headline = '${r.signatures.length} of ${r.partyCount} parties have signed so far.';
          break;
        case 'superseded':
          status = const Pill('Superseded', background: C.line, foreground: C.muted);
          headline = 'A newer signed version replaced this one.';
          break;
        default:
          status = const Pill('Cancelled', background: C.redBg, foreground: C.red, border: C.redLine);
          headline = 'This version was cancelled before everyone signed.';
      }
    }
    final lastSig = r.signatures.values.isEmpty
        ? null
        : r.signatures.values.map((s) => s.at).reduce((a, b) => a.isAfter(b) ? a : b);

    final parties = SurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Parties and shares', style: T.body(18, weight: FontWeight.w700)),
        const SizedBox(height: 14),
        _tableRow(
          [Text('Party', style: T.body(13, color: C.muted)), Text('Composition', style: T.body(13, color: C.muted)),
            Text('Master', style: T.body(13, color: C.muted)), Text('Signed', style: T.body(13, color: C.muted))],
        ),
        for (var i = 0; i < r.partyCount; i++) ...[
          const Divider(height: 1),
          _tableRow([
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sheet == null ? 'Party ${i + 1}' : sheet.contributors[i].displayName,
                  overflow: TextOverflow.ellipsis, style: T.body(15)),
              if (sheet != null)
                Text(sheet.contributors[i].rolesLabel, overflow: TextOverflow.ellipsis, style: T.body(12, color: C.muted)),
            ]),
            Text(fmtPct(r.compositionBps[i]), style: T.mono(14)),
            Text(fmtPct(r.masterBps[i]), style: T.mono(14)),
            Text(r.signatures[i] == null ? 'Not yet' : fmtTime(r.signatures[i]!.at),
                style: T.body(14, color: r.signatures[i] == null ? C.muted : C.text2)),
          ]),
        ],
        const SizedBox(height: 14),
        Text(
          sheet == null
              ? 'Names are private to the people on the sheet. Sign in as one of them to see who is who. The public record holds only shares, fingerprints and times.'
              : 'This page shows a record of the parties\' agreement on ownership shares. It is not legal advice and does not replace a publishing, label or distribution contract.',
          style: T.body(13, color: C.faint, height: 1.5),
        ),
      ]),
    );

    final fileCheck = SurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Check the recording', style: T.body(18, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Pick the audio file. It is checked on this device and never uploaded.',
            style: T.body(14, color: C.text2, height: 1.45)),
        const SizedBox(height: 14),
        SecondaryButton(
          label: _checking ? 'Checking…' : 'Choose a file',
          icon: Icons.upload_file_rounded,
          onPressed: _checking || r.audioHash == null ? null : () => _checkFile(r),
        ),
        if (r.audioHash == null) ...[
          const SizedBox(height: 10),
          Text('No recording was attached to this sheet.', style: T.body(13, color: C.muted)),
        ],
        if (_fileMatch != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _fileMatch! ? C.greenBg : C.redBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _fileMatch! ? C.greenLine : C.redLine),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_fileMatch! ? Icons.check_rounded : Icons.close_rounded, color: _fileMatch! ? C.green : C.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _fileMatch!
                      ? 'Match. $_fileName is the recording on this sheet.'
                      : 'No match. $_fileName is not the recording that was signed.',
                  style: T.body(14, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );

    final proof = SurfaceCard(
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Proof', style: T.body(18, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        InfoRow(label: 'Sheet ID', value: r.sheetId, copyValue: r.sheetId),
        InfoRow(label: 'Document hash', value: shortHex(r.docHash, head: 8, tail: 6), copyValue: r.docHash),
        InfoRow(label: 'Audio fingerprint', value: shortHex(r.audioHash, head: 8, tail: 6), copyValue: r.audioHash),
        if (r.events.isNotEmpty)
          InfoRow(label: 'Created', value: fmtDateTime(r.events.first.at), mono: false),
        if (lastSig != null) InfoRow(label: 'Last signature', value: fmtDateTime(lastSig), mono: false),
        InfoRow(label: 'Network', value: context.read<AppState>().chain.networkName, mono: false),
      ]),
    );

    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      status,
      const SizedBox(height: 16),
      Text(sheet?.title ?? 'Split sheet', style: T.display(wide ? 56 : 38, height: 1.05)),
      const SizedBox(height: 10),
      Text(headline, style: T.body(17, color: C.text2)),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const SizedBox(height: 32),
      wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: parties),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: Column(children: [fileCheck, const SizedBox(height: 24), proof])),
            ])
          : Column(children: [parties, const SizedBox(height: 16), fileCheck, const SizedBox(height: 16), proof]),
    ]);
  }

  Widget _tableRow(List<Widget> cells) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(flex: 4, child: cells[0]),
          Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: cells[1])),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: cells[2])),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: cells[3])),
        ]),
      );
}
