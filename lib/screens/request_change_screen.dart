import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class RequestChangeScreen extends StatefulWidget {
  const RequestChangeScreen({super.key, required this.id, required this.index});
  final String id;
  final int index;

  @override
  State<RequestChangeScreen> createState() => _RequestChangeScreenState();
}

class _RequestChangeScreenState extends State<RequestChangeScreen> {
  static const _reasons = ['My share', 'Someone is missing', 'Wrong role', 'Wrong recording', 'Song details'];
  String _reason = _reasons.first;
  final _note = TextEditingController();
  final _suggested = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    _suggested.dispose();
    super.dispose();
  }

  Future<void> _send(AppState state) async {
    final s = state.byId(widget.id);
    if (s == null) return;
    if (_note.text.trim().isEmpty) {
      showSnack(context, 'Add a short note so ${s.creator.displayName} knows what to fix');
      return;
    }
    final pct = double.tryParse(_suggested.text.replaceAll('%', '').trim());
    setState(() => _busy = true);
    await state.requestChange(
      s.id,
      widget.index,
      reason: _reason,
      note: _note.text.trim(),
      suggestedCompositionBps: pct == null ? null : (pct * 100).round().clamp(0, 10000).toInt(),
    );
    if (!mounted) return;
    showSnack(context, 'Sent to ${s.creator.displayName}');
    context.go(state.isCreator(s) ? '/sheet/${s.id}/invite' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.byId(widget.id);
    if (s == null || widget.index >= s.contributors.length) return const NotFoundView();
    final c = s.contributors[widget.index];
    final creator = s.creator.displayName;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              children: [
                TopBar(onBack: () => goBack(context, '/sheet/${s.id}/sign/${widget.index}')),
                const SizedBox(height: 20),
                Text("Something's not right?", style: T.display(28)),
                const SizedBox(height: 6),
                Text('Tell $creator what to fix. Nothing counts until everyone signs the same version.',
                    style: T.body(14, color: C.muted, height: 1.45)),
                const SizedBox(height: 20),
                Text('What needs changing?', style: T.body(13, color: C.muted)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final r in _reasons)
                    SelectChip(label: r, selected: _reason == r, onTap: () => setState(() => _reason = r)),
                ]),
                const SizedBox(height: 18),
                TextField(
                  controller: _note,
                  maxLines: 5,
                  minLines: 4,
                  style: T.body(15, height: 1.45),
                  decoration: InputDecoration(
                    labelText: 'Note to $creator',
                    alignLabelWithHint: true,
                    hintText: 'For example: I wrote the second verse as well as the hook.',
                  ),
                ),
                if (_reason == 'My share') ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Suggest a composition share', style: T.body(14)),
                          Text('Now ${fmtPct(c.compositionBps)} · optional', style: T.body(12, color: C.muted)),
                        ]),
                      ),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _suggested,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          style: T.mono(16),
                          decoration: InputDecoration(
                            isDense: true,
                            fillColor: C.bg,
                            suffixText: '%',
                            suffixStyle: T.mono(15, color: C.muted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PrimaryButton(label: 'Send to $creator', loading: _busy, onPressed: () => _send(state)),
              const SizedBox(height: 8),
              Text('$creator can then issue an updated sheet for everyone to sign.',
                  textAlign: TextAlign.center, style: T.body(12, color: C.faint)),
            ]),
          ),
        ]),
      ),
    );
  }
}
