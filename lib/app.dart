import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'state/app_state.dart';
import 'theme.dart';

class SplitSheetApp extends StatefulWidget {
  const SplitSheetApp({super.key});

  @override
  State<SplitSheetApp> createState() => _SplitSheetAppState();
}

class _SplitSheetAppState extends State<SplitSheetApp> {
  late final GoRouter _router = buildRouter(context.read<AppState>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Split Sheet',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
    );
  }
}
