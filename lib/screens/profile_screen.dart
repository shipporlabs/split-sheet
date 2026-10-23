import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _seeding = false;

  Future<void> _edit(AppState state, String field, String current) async {
    final label = {'legal': 'Legal name', 'stage': 'Stage name', 'society': 'Collecting society ID'}[field]!;
    final v = await promptText(context, title: label, initial: current);
    if (v == null) return;
    if (field == 'legal' && v.length < 2) {
      if (mounted) showSnack(context, 'Your legal name is needed on signed sheets');
      return;
    }
    await state.updateProfile(
      legalName: field == 'legal' ? v : null,
      stageName: field == 'stage' ? v : null,
      societyId: field == 'society' ? v : null,
    );
    if (mounted) showSnack(context, 'Saved. New sheets will use it.');
  }

  Future<void> _changePin(AppState state) async {
    final current = await showPinSheet(context, title: 'Current PIN', validate: state.checkPin);
    if (current == null || !mounted) return;
    final next = await showPinSheet(context, title: 'New PIN', subtitle: 'Choose 4 digits', createNew: true);
    if (next == null) return;
    await state.changePin(next);
    if (mounted) showSnack(context, 'PIN changed');
  }

  Future<void> _seed(AppState state) async {
    setState(() => _seeding = true);
    try {
      await state.seedDemo();
      if (mounted) showSnack(context, 'Demo sheets added');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not load the demo: $e');
    }
    if (mounted) setState(() => _seeding = false);
  }

  Future<void> _erase(AppState state) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete your account?',
      message:
          'This removes your login and profile. Sheets you signed stay, because the other people on them signed too.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await state.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      if (AppState.authMessage(e).startsWith('For your security')) {
        final password = await promptText(context, title: 'Enter your password to confirm', hint: 'Password');
        if (password == null || password.isEmpty || !mounted) return;
        try {
          await state.deleteAccount(password: password);
        } catch (e2) {
          if (mounted) showSnack(context, AppState.authMessage(e2));
          return;
        }
      } else {
        showSnack(context, AppState.authMessage(e));
        return;
      }
    }
    if (mounted) context.go('/welcome');
  }

  Future<void> _resendVerification(AppState state) async {
    try {
      await state.resendVerification();
      if (mounted) showSnack(context, 'Verification link sent to ${state.authUser?.email}');
    } catch (e) {
      if (mounted) showSnack(context, AppState.authMessage(e));
    }
  }

  Future<void> _checkVerified(AppState state) async {
    await state.refreshAuthUser();
    if (mounted) showSnack(context, state.emailVerified ? 'Email confirmed' : 'Not confirmed yet. Open the link in your inbox.');
  }

  Widget _row(String label, String value, {VoidCallback? onTap, Color? color, bool mono = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(child: Text(label, style: T.body(15, color: color ?? C.text2))),
          if (value.isNotEmpty)
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: mono ? T.mono(13, color: C.muted) : T.body(15, color: C.text)),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: color ?? C.muted, size: 20),
          ],
        ]),
      ),
    );
  }

  Widget _group(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: T.body(13, color: C.muted, weight: FontWeight.w500)),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            rows[i],
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final u = state.user;
    if (u == null) return const SizedBox.shrink();
    final count = state.sheets.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(children: [
          Avatar(u.displayName, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.displayName, overflow: TextOverflow.ellipsis, style: T.display(24)),
              Text('${u.email} · $count ${count == 1 ? 'sheet' : 'sheets'}',
                  overflow: TextOverflow.ellipsis, style: T.body(13, color: C.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 22),
        if (!state.emailVerified)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SurfaceCard(
              color: C.surfaceWarm,
              borderColor: C.lineWarm,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Confirm your email', style: T.body(15, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('We sent a link to ${u.email}. Confirming helps you recover your account.',
                    style: T.body(13, color: C.text2, height: 1.4)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  SelectChip(label: 'I have confirmed it', selected: false, onTap: () => _checkVerified(state)),
                  SelectChip(label: 'Send the link again', selected: false, onTap: () => _resendVerification(state)),
                ]),
              ]),
            ),
          ),
        _group('On your sheets', [
          _row('Legal name', u.legalName, onTap: () => _edit(state, 'legal', u.legalName)),
          _row('Stage name', u.stageName.isEmpty ? 'Add' : u.stageName, onTap: () => _edit(state, 'stage', u.stageName)),
          _row('Society ID', u.societyId.isEmpty ? 'Add' : u.societyId, onTap: () => _edit(state, 'society', u.societyId)),
        ]),
        _group('Security', [
          _row('Email', state.emailVerified ? 'Confirmed' : 'Not confirmed'),
          _row('Change password', '', onTap: () async {
            await state.sendPasswordReset(u.email);
            if (context.mounted) showSnack(context, 'A password reset link is on its way to ${u.email}');
          }),
          _row('Change PIN', '', onTap: () => _changePin(state)),
          _row('Signing key', shortHex(u.address), mono: true, onTap: () => copyText(context, u.address, 'Signing key address')),
        ]),
        _group('Your data', [
          _row('Load demo sheets', _seeding ? 'Loading…' : '', onTap: _seeding ? null : () => _seed(state)),
          _row('Export my sheets', 'JSON', onTap: () => copyText(context, state.exportJson(), 'Your sheets')),
          _row('Sign out', '', onTap: () => state.signOut()),
          _row('Delete account', '', color: C.red, onTap: () => _erase(state)),
        ]),
        const SizedBox(height: 4),
        Text(
          'Split Sheet records what you agreed. It is not legal advice and does not replace a publishing, label or distribution contract.',
          style: T.body(12, color: C.faint, height: 1.45),
        ),
        const SizedBox(height: 8),
        Text('Version 0.1.0 · ${state.chain.networkName}', style: T.body(12, color: C.faint)),
      ],
    );
  }
}
