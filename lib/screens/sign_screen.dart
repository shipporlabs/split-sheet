import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheet_widgets.dart';
import '../widgets/sheets.dart';

/// A collaborator reviews their share and signs, asks for a change, or declines.
class SignScreen extends StatefulWidget {
  const SignScreen({super.key, required this.id, required this.index});
  final String id;
  final int index;

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  bool _agreed = false;
  bool _busy = false;

  Future<void> _sign(AppState state, SplitSheet s, bool isMe) async {
    final c = s.contributors[widget.index];
    final summary = '${fmtPct(c.compositionBps)} composition · ${fmtPct(c.masterBps)} master';
    final String? pin;
    if (isMe) {
      pin = await showPinSheet(
        context,
        title: 'Enter your PIN to sign',
        subtitle: '${s.title}, version ${s.version}',
        summary: 'You are agreeing to $summary',
        validate: state.checkPin,
      );
    } else {
      pin = await showPinSheet(
        context,
        title: 'Choose a PIN, ${firstName(c.name)}',
        subtitle: 'It protects your signature on this phone',
        summary: 'Signing as ${c.name}: $summary',
        createNew: true,
      );
    }
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = isMe
          ? await state.signAsMe(s.id, widget.index)
          : await state.signAsGuest(s.id, widget.index, pin);
      if (!mounted) return;
      showSnack(context, updated.status == SheetStatus.executed ? 'Everyone has signed. Locked in.' : 'Signed. Thank you, ${firstName(c.name)}.');
      if (updated.status == SheetStatus.executed) {
        context.go('/sheet/${s.id}/invite');
      } else if (state.isCreator(updated)) {
        context.go('/sheet/${s.id}/invite');
      } else {
        context.go('/sheet/${s.id}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, '$e');
    }
  }

  Future<void> _decline(AppState state, SplitSheet s) async {
    final note = await promptText(
      context,
      title: 'Decline this sheet?',
      hint: 'Tell ${s.creator.displayName} why (optional)',
      maxLines: 3,
    );
    if (note == null || !mounted) return;
    await state.requestChange(s.id, widget.index, reason: 'Declined', note: note.isEmpty ? 'No reason given' : note, decline: true);
    if (!mounted) return;
    showSnack(context, '${s.creator.displayName} has been told');
    context.go(state.isCreator(s) ? '/sheet/${s.id}/invite' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.byId(widget.id);
    if (s == null || widget.index < 0 || widget.index >= s.contributors.length) return const NotFoundView();
    final c = s.contributors[widget.index];
    final isMe = state.myIndex(s) == widget.index;
    final holder = s.claims[widget.index];
    final elsewhere = holder != null && !isMe;
    final signed = s.isSigned(widget.index);
    final open = s.status == SheetStatus.pending && !signed && !elsewhere;
    final invitedBy = widget.index == 0 ? 'Review and sign' : '${s.creator.displayName} invited ${isMe ? 'you' : firstName(c.name)} to sign';

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              children: [
                TopBar(onBack: () => goBack(context, '/home'), label: 'Version ${s.version}'),
                const SizedBox(height: 18),
                Row(children: [
                  Avatar(s.creator.displayName, size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Text(invitedBy, style: T.body(14, color: C.text2))),
                ]),
                const SizedBox(height: 14),
                Text(s.title, style: T.display(30)),
                const SizedBox(height: 4),
                Text(
                  ['Session ${fmtDate(s.sessionDate)}', if (s.studio.isNotEmpty) s.studio].join(' · '),
                  style: T.body(13, color: C.muted),
                ),
                const SizedBox(height: 18),
                SurfaceCard(
                  color: C.surfaceWarm,
                  borderColor: C.lineWarm,
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isMe ? 'Your share' : 'Share for ${c.name}', style: T.body(13, color: C.accentSoft)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _BigShare(value: fmtPct(c.compositionBps), label: 'Composition')),
                      Expanded(child: _BigShare(value: fmtPct(c.masterBps), label: 'Master')),
                    ]),
                    const SizedBox(height: 6),
                    Text(c.rolesLabel, style: T.body(13, color: C.text2)),
                  ]),
                ),
                const SizedBox(height: 12),
                SplitTable(sheet: s, highlight: widget.index),
                const SizedBox(height: 12),
                AudioCard(sheet: s),
                const SizedBox(height: 16),
                if (signed)
                  SurfaceCard(
                    color: C.greenBg,
                    borderColor: C.greenLine,
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: C.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Signed ${fmtDateTime(s.signatureFor(widget.index)!.signedAt)}',
                            style: T.body(14, color: C.text)),
                      ),
                    ]),
                  )
                else if (!open)
                  SurfaceCard(
                    child: Text(
                      elsewhere && s.status == SheetStatus.pending
                          ? '${c.displayName} joined from their own account and signs on their phone. You will see it here the moment they do.'
                          : s.status == SheetStatus.executed
                              ? 'This sheet is already locked in.'
                              : 'This sheet is no longer open for signing.',
                      style: T.body(14, color: C.text2, height: 1.45),
                    ),
                  )
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _agreed = !_agreed),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'I have read these shares and agree to them. This is a record of our agreement, not legal advice.',
                            style: T.body(14, color: C.text2, height: 1.4),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: open
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    PrimaryButton(
                      label: isMe ? 'Sign with PIN' : 'Sign as ${firstName(c.name)}',
                      icon: Icons.lock_outline_rounded,
                      loading: _busy,
                      onPressed: _agreed ? () => _sign(state, s, isMe) : null,
                    ),
                    if (widget.index != 0) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Request change',
                            onPressed: _busy ? null : () => context.push('/sheet/${s.id}/change/${widget.index}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Decline',
                            foreground: C.red,
                            borderColor: C.redLine,
                            onPressed: _busy ? null : () => _decline(state, s),
                          ),
                        ),
                      ]),
                    ],
                  ])
                : PrimaryButton(label: 'View the sheet', onPressed: () => context.go('/sheet/${s.id}')),
          ),
        ]),
      ),
    );
  }
}

class _BigShare extends StatelessWidget {
  const _BigShare({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: T.display(38)),
      Text(label, style: T.body(13, color: C.text2)),
    ]);
  }
}
