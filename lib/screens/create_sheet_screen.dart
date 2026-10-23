import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/hashing.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/splits.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import '../widgets/split_editor.dart';

/// Five steps: song and people, composition split, master split, audio, review and sign.
class CreateSheetScreen extends StatefulWidget {
  const CreateSheetScreen({super.key, this.initial});
  final SheetDraft? initial;

  @override
  State<CreateSheetScreen> createState() => _CreateSheetScreenState();
}

class _CreateSheetScreenState extends State<CreateSheetScreen> {
  late final SheetDraft _d;
  late final TextEditingController _title;
  late final TextEditingController _studio;
  late final TextEditingController _genre;
  late List<int> _comp;
  late List<int> _master;
  int _step = 0;
  bool _agreed = false;
  bool _hashing = false;
  bool _publishing = false;

  bool get _isAmendment => _d.previousId != null;

  @override
  void initState() {
    super.initState();
    _d = widget.initial ?? context.read<AppState>().newDraft();
    _title = TextEditingController(text: _d.title);
    _studio = TextEditingController(text: _d.studio);
    _genre = TextEditingController(text: _d.genre);
    _comp = [for (final c in _d.contributors) c.compositionBps];
    _master = [for (final c in _d.contributors) c.masterBps];
  }

  @override
  void dispose() {
    _title.dispose();
    _studio.dispose();
    _genre.dispose();
    super.dispose();
  }

  int get _barFilled {
    switch (_step) {
      case 0:
        return 1;
      case 1:
      case 2:
        return 2;
      case 3:
        return 3;
      default:
        return 4;
    }
  }

  void _syncSplitsToPeople() {
    final n = _d.contributors.length;
    if (_comp.length != n || sumBps(_comp) == 0) _comp = equalSplit(n);
    if (_master.length != n || sumBps(_master) == 0) _master = equalSplit(n);
  }

  void _applySplits() {
    _d.contributors = [
      for (var i = 0; i < _d.contributors.length; i++)
        _d.contributors[i].copyWith(compositionBps: _comp[i], masterBps: _master[i]),
    ];
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _title.text.trim().isNotEmpty && _d.contributors.length >= 2;
      case 1:
        return sumBps(_comp) == fullBps;
      case 2:
        return sumBps(_master) == fullBps;
      case 3:
        return _d.audioHash != null && !_hashing;
      default:
        return _agreed && !_publishing;
    }
  }

  void _next() {
    if (_step == 0) {
      _d.title = _title.text.trim();
      _d.studio = _studio.text.trim();
      _d.genre = _genre.text.trim();
      _syncSplitsToPeople();
    }
    if (_step == 2) _applySplits();
    if (_step == 4) {
      _publish();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      goBack(context, '/home');
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _addOrEdit([int? index]) async {
    final result = await showContributorSheet(context, initial: index == null ? null : _d.contributors[index]);
    if (result == null) return;
    setState(() {
      if (index == null) {
        _d.contributors = [..._d.contributors, result];
      } else {
        final list = List<Contributor>.of(_d.contributors);
        list[index] = result;
        _d.contributors = list;
      }
    });
  }

  void _remove(int index) {
    setState(() {
      final list = List<Contributor>.of(_d.contributors)..removeAt(index);
      _d.contributors = list;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _d.sessionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _d.sessionDate = picked);
  }

  Future<void> _pickAudio() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        if (mounted) showSnack(context, 'Could not read that file. Try another one.');
        return;
      }
      setState(() => _hashing = true);
      final hash = await compute(sha256Hex, bytes.toList());
      if (!mounted) return;
      setState(() {
        _d.audioName = f.name;
        _d.audioBytes = f.size;
        _d.audioHash = hash;
        _hashing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hashing = false);
      showSnack(context, 'Could not open the file picker: $e');
    }
  }

  void _useDemoTrack() {
    final seed = 'split-sheet-demo-track:${_d.title}:${DateTime.now().microsecondsSinceEpoch}';
    final name = slug(_d.title).isEmpty ? 'demo-track.wav' : '${slug(_d.title)}_demo.wav';
    setState(() {
      _d.audioName = name;
      _d.audioBytes = utf8.encode(seed).length;
      _d.audioHash = sha256Of(seed);
    });
  }

  Future<void> _publish() async {
    final state = context.read<AppState>();
    final me = _d.contributors.first;
    final pin = await showPinSheet(
      context,
      title: 'Enter your PIN to sign',
      subtitle: '${_d.title}, version ${_d.version}',
      summary: 'You: ${fmtPct(me.compositionBps)} composition · ${fmtPct(me.masterBps)} master',
      validate: state.checkPin,
    );
    if (pin == null || !mounted) return;
    setState(() => _publishing = true);
    try {
      final sheet = await state.publish(_d);
      if (!mounted) return;
      context.go('/sheet/${sheet.id}/invite');
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      showSnack(context, 'Could not record the sheet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(children: [
              TopBar(
                onBack: _publishing ? null : _back,
                icon: _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
                label: _isAmendment ? 'Version ${_d.version} · Step $_barFilled of 4' : 'Step $_barFilled of 4',
              ),
              const SizedBox(height: 14),
              StepBar(filled: _barFilled),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: PrimaryButton(
              label: _buttonLabel,
              loading: _publishing,
              onPressed: _canContinue ? _next : null,
            ),
          ),
        ]),
      ),
    );
  }

  String get _buttonLabel {
    switch (_step) {
      case 0:
        return 'Continue to splits';
      case 1:
        return 'Next: master split';
      case 2:
        return 'Next: attach audio';
      case 3:
        return 'Review and sign';
      default:
        return 'Sign and invite others';
    }
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _details();
      case 1:
        return _splitStep(SplitType.composition);
      case 2:
        return _splitStep(SplitType.master);
      case 3:
        return _audio();
      default:
        return _review();
    }
  }

  Widget _details() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_isAmendment ? 'Update the sheet' : 'The song and who made it', style: T.display(28)),
      if (_isAmendment) ...[
        const SizedBox(height: 6),
        Text('Everyone signs the new version. The old one stays in the history.',
            style: T.body(14, color: C.muted)),
      ],
      const SizedBox(height: 20),
      TextField(
        controller: _title,
        textCapitalization: TextCapitalization.words,
        style: T.body(16),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Song title'),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Session date'),
              child: Text(fmtDate(_d.sessionDate), style: T.body(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _studio,
            textCapitalization: TextCapitalization.words,
            style: T.body(16),
            decoration: const InputDecoration(labelText: 'Studio'),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _genre,
        textCapitalization: TextCapitalization.words,
        style: T.body(16),
        decoration: const InputDecoration(labelText: 'Genre (optional)'),
      ),
      const SizedBox(height: 26),
      Row(children: [
        Expanded(child: Text('Contributors', style: T.body(17, weight: FontWeight.w700))),
        Text('${_d.contributors.length} ${_d.contributors.length == 1 ? 'person' : 'people'}',
            style: T.body(13, color: C.muted)),
      ]),
      const SizedBox(height: 12),
      for (var i = 0; i < _d.contributors.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SurfaceCard(
            padding: const EdgeInsets.all(12),
            onTap: () => _addOrEdit(i),
            child: Row(children: [
              Avatar(_d.contributors[i].displayName,
                  foreground: C.split(i) == C.accent ? C.accent : C.accentSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i == 0 ? '${_d.contributors[i].displayName} (you)' : _d.contributors[i].displayName,
                      overflow: TextOverflow.ellipsis, style: T.body(15, weight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final r in _d.contributors[i].roles)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: C.accentBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(r, style: T.body(12, color: C.accentSoft)),
                      ),
                  ]),
                ]),
              ),
              if (i > 0)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _remove(i),
                  icon: const Icon(Icons.close_rounded, color: C.muted, size: 20),
                ),
            ]),
          ),
        ),
      SecondaryButton(
        label: 'Add contributor',
        icon: Icons.add_rounded,
        borderColor: C.line2,
        onPressed: _d.contributors.length >= 10 ? null : () => _addOrEdit(),
      ),
      if (_d.contributors.length < 2) ...[
        const SizedBox(height: 10),
        Text('Add at least one more person to continue.', style: T.body(13, color: C.muted)),
      ],
    ]);
  }

  Widget _splitStep(SplitType type) {
    final isComp = type == SplitType.composition;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Who owns what', style: T.display(28)),
      const SizedBox(height: 16),
      SplitTabsHeader(type: type),
      const SizedBox(height: 10),
      Text(
        isComp
            ? 'Composition is the song itself: lyrics and melody. Usually writers and producers.'
            : 'Master is this recording. Usually the artist and whoever paid for the session. It can differ from composition.',
        style: T.body(13, color: C.muted, height: 1.45),
      ),
      const SizedBox(height: 18),
      SplitEditor(
        key: ValueKey('${type.name}-${_d.contributors.length}'),
        contributors: _d.contributors,
        initial: isComp ? _comp : _master,
        subtitleFor: isComp
            ? null
            : (i) => _comp[i] > 0 ? '${fmtPct(_comp[i])} of the composition' : _d.contributors[i].rolesLabel,
        onChanged: (v) => setState(() {
          if (isComp) {
            _comp = v;
          } else {
            _master = v;
          }
        }),
      ),
    ]);
  }

  Widget _audio() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Tie it to the recording', style: T.display(28)),
      const SizedBox(height: 6),
      Text('We fingerprint the audio on this device so the sheet can only ever match this song.',
          style: T.body(14, color: C.muted, height: 1.45)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: _BigOption(
            icon: Icons.upload_rounded,
            label: 'Upload bounce',
            selected: true,
            onTap: _hashing ? null : _pickAudio,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BigOption(
            icon: Icons.auto_awesome_rounded,
            label: 'Use a demo track',
            selected: false,
            onTap: _hashing ? null : _useDemoTrack,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      if (_hashing)
        SurfaceCard(
          child: Row(children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 14),
            Text('Creating the fingerprint…', style: T.body(14, color: C.text2)),
          ]),
        )
      else if (_d.audioHash != null)
        SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle),
                child: const Icon(Icons.graphic_eq_rounded, color: C.onAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_d.audioName ?? '', overflow: TextOverflow.ellipsis, style: T.body(15, weight: FontWeight.w500)),
                  Text(fmtBytes(_d.audioBytes), style: T.body(13, color: C.muted)),
                ]),
              ),
            ]),
            const Divider(height: 28),
            Row(children: [
              const Icon(Icons.check_rounded, color: C.green, size: 18),
              const SizedBox(width: 8),
              Text('Fingerprint created on this device', style: T.body(13, color: C.green, weight: FontWeight.w500)),
            ]),
            const SizedBox(height: 6),
            Text(groupedHash(_d.audioHash), style: T.mono(13, color: C.text2)),
          ]),
        ),
      const SizedBox(height: 14),
      Text('The audio file itself never leaves your device. Only its fingerprint is recorded.',
          style: T.body(13, color: C.muted, height: 1.45)),
    ]);
  }

  Widget _review() {
    final preview = SplitSheet(
      id: 'preview',
      version: _d.version,
      title: _d.title,
      sessionDate: _d.sessionDate,
      studio: _d.studio,
      genre: _d.genre,
      inviteCode: '',
      contributors: _d.contributors,
      creatorAddress: '',
      createdAt: DateTime.now(),
      audioName: _d.audioName,
      audioHash: _d.audioHash,
    );
    final meta = [fmtDate(_d.sessionDate), if (_d.studio.isNotEmpty) _d.studio, if (_d.genre.isNotEmpty) _d.genre];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Check it, then sign', style: T.display(28)),
      const SizedBox(height: 4),
      Text('${_d.title} · ${meta.join(' · ')}', style: T.body(13, color: C.muted)),
      const SizedBox(height: 18),
      SplitTableLite(sheet: preview),
      const SizedBox(height: 12),
      SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_d.audioName ?? '', overflow: TextOverflow.ellipsis, style: T.body(14)),
              Text(groupedHash(_d.audioHash), style: T.mono(12, color: C.muted)),
            ]),
          ),
          TextButton(
            onPressed: () => setState(() => _step = 3),
            child: Text('Change', style: T.body(14, color: C.accent)),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _agreed = !_agreed),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'These shares are what we agreed in the session. I understand this is a record of our agreement, not legal advice.',
                  style: T.body(14, color: C.text2, height: 1.4),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text('You sign first. The others sign by scanning your QR code or on this phone.',
          textAlign: TextAlign.center, style: T.body(12, color: C.faint)),
    ]);
  }
}

class _BigOption extends StatelessWidget {
  const _BigOption({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? C.surfaceWarm : C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? C.accent : C.line2, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 104,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: selected ? C.accent : C.text, size: 26),
            const SizedBox(height: 8),
            Text(label, style: T.body(14, weight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

/// Static header showing which split is being edited in the wizard.
class SplitTabsHeader extends StatelessWidget {
  const SplitTabsHeader({super.key, required this.type});
  final SplitType type;

  @override
  Widget build(BuildContext context) {
    Widget tab(SplitType t) {
      final active = t == type;
      final done = t == SplitType.composition && type == SplitType.master;
      return Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: active ? C.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (done) ...[
              const Icon(Icons.check_rounded, size: 15, color: C.green),
              const SizedBox(width: 6),
            ],
            Text(t.label,
                style: T.body(14, color: active ? C.text : C.muted, weight: active ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Row(children: [tab(SplitType.composition), const SizedBox(width: 4), tab(SplitType.master)]),
    );
  }
}

/// Review table used before the sheet exists (no "you" highlight or signatures).
class SplitTableLite extends StatelessWidget {
  const SplitTableLite({super.key, required this.sheet});
  final SplitSheet sheet;

  @override
  Widget build(BuildContext context) {
    Widget line(Widget a, Widget b, Widget c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(flex: 5, child: a),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: b)),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: c)),
          ]),
        );
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(children: [
        line(Text('Contributor', style: T.body(12, color: C.muted)), Text('Comp.', style: T.body(12, color: C.muted)),
            Text('Master', style: T.body(12, color: C.muted))),
        for (final c in sheet.contributors)
          line(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.displayName, overflow: TextOverflow.ellipsis, style: T.body(14, weight: FontWeight.w500)),
              Text(c.rolesLabel, overflow: TextOverflow.ellipsis, style: T.body(12, color: C.muted)),
            ]),
            Text(fmtPct(c.compositionBps), style: T.mono(14)),
            Text(fmtPct(c.masterBps), style: T.mono(14)),
          ),
        const Divider(height: 14),
        line(Text('Total', style: T.body(14, color: C.text2)), Text('100%', style: T.mono(14, color: C.green)),
            Text('100%', style: T.mono(14, color: C.green))),
      ]),
    );
  }
}
