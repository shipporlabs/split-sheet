import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/firestore_chain.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(FirebaseSetupNeeded(error: '$e'));
    return;
  }
  final db = FirebaseFirestore.instance;
  final state = AppState(auth: FirebaseAuth.instance, db: db, chain: FirestoreChainService(db));
  await state.init();
  runApp(ChangeNotifierProvider<AppState>.value(value: state, child: const SplitSheetApp()));
}

/// Shown when the app runs before `flutterfire configure` has created real Firebase options.
class FirebaseSetupNeeded extends StatelessWidget {
  const FirebaseSetupNeeded({super.key, required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Connect Firebase to start', style: T.display(28)),
                  const SizedBox(height: 12),
                  Text(
                    'Run `flutterfire configure` in the project folder, enable Email/Password sign-in, '
                    'create a Firestore database and deploy firestore.rules. The README has the steps.',
                    style: T.body(15, color: C.text2, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(error, style: T.mono(12, color: C.muted)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
