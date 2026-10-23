import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Bottom tabs, a Spotify-style "now playing" bar for the sheet that needs attention, and live
/// messages when collaborators sign on their own phones.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppState _state = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _state.toast.addListener(_onToast);
  }

  @override
  void dispose() {
    _state.toast.removeListener(_onToast);
    super.dispose();
  }

  void _onToast() {
    final msg = _state.toast.value;
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    _state.toast.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: widget.child),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const _MiniBar(),
        _NavBar(location: widget.location),
      ]),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.spotlight;
    if (s == null) return const SizedBox.shrink();
    final mine = state.awaitingMe(s);
    final me = state.myIndex(s);
    final n = s.contributors.length;
    final subtitle = mine ? 'Waiting on your signature' : '${s.signedCount} of $n signed · tap to collect the rest';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Material(
        color: C.surface2,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => mine && me != null
              ? context.push('/sheet/${s.id}/sign/$me')
              : context.push('/sheet/${s.id}/invite'),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(children: [
                CoverArt(s.title, size: 40, radius: 6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(14, weight: FontWeight.w700)),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(12, color: C.muted)),
                  ]),
                ),
                Icon(mine ? Icons.draw_rounded : Icons.qr_code_2_rounded, color: C.accent),
              ]),
            ),
            LinearProgressIndicator(
              value: n == 0 ? 0 : s.signedCount / n,
              minHeight: 2,
              backgroundColor: C.line,
              color: C.accent,
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, IconData activeIcon, String label, String path, {bool push = false}) {
      final active = location.startsWith(path);
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => push ? context.push(path) : context.go(path),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(active ? activeIcon : icon, size: 24, color: active ? C.accent : C.muted),
                const SizedBox(height: 4),
                Text(label, style: T.body(12, color: active ? C.accent : C.muted, weight: active ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: C.nav, border: Border(top: BorderSide(color: C.line))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          item(Icons.description_outlined, Icons.description_rounded, 'Sheets', '/home'),
          item(Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, 'Join', '/join', push: true),
          item(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Payouts', '/payouts'),
          item(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', '/profile'),
        ]),
      ),
    );
  }
}
