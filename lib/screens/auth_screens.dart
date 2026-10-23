import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            Row(children: [
              const Logo(),
              const Spacer(),
              if (kIsWeb)
                TextButton(
                  onPressed: () => context.go('/'),
                  child: Text('About', style: T.body(14, color: C.muted)),
                ),
            ]),
            const SizedBox(height: 32),
            Text('Who wrote that hook? Settle it before you leave the studio.',
                style: T.display(36, height: 1.05)),
            const SizedBox(height: 28),
            const _SampleCard(),
            const SizedBox(height: 24),
            for (final t in const [
              'Sign with your email and a PIN',
              'Tied to the exact recording',
              'Proof anyone can verify',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  const Icon(Icons.check_rounded, color: C.accent, size: 20),
                  const SizedBox(width: 12),
                  Text(t, style: T.body(15, color: C.text2)),
                ]),
              ),
            const Spacer(),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Create an account', onPressed: () => context.push('/sign-up')),
            const SizedBox(height: 12),
            SecondaryButton(label: 'I already have an account', onPressed: () => context.push('/sign-in')),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                state.afterAuthPath = '/join';
                context.push('/sign-up');
              },
              child: Text('I have an invite code', style: T.body(14, color: C.accent, weight: FontWeight.w700)),
            ),
            Text('A record of your agreement, not legal advice.',
                textAlign: TextAlign.center, style: T.body(12, color: C.faint)),
          ],
        ),
      ),
    );
  }
}

class _SampleCard extends StatelessWidget {
  const _SampleCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lagos Summer', style: T.body(16, weight: FontWeight.w700)),
              Text('Composition split', style: T.body(13, color: C.muted)),
            ]),
          ),
          const Pill('3 of 3 signed', background: C.green, foreground: C.onGreen),
        ]),
        const SizedBox(height: 14),
        const SplitBar(bps: [4000, 3500, 2500], height: 14),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Tobi · 40%', style: T.body(13, color: C.text2)),
          Text('Ada · 35%', style: T.body(13, color: C.text2)),
          Text('Kemi · 25%', style: T.body(13, color: C.text2)),
        ]),
      ]),
    );
  }
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.label, this.onSubmitted, this.autofillHints});
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      autofillHints: widget.autofillHints,
      style: T.body(16),
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.muted),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters for your password.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().signUp(email, _password.text);
      // The router moves on to profile setup once the account exists.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppState.authMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: FillScroll(
            children: [
              TopBar(onBack: () => goBack(context, '/welcome')),
              const SizedBox(height: 24),
              Text('Create your account', style: T.display(32)),
              const SizedBox(height: 8),
              Text("We'll send a link to confirm your email. Your signing key is set up for you.",
                  style: T.body(15, color: C.muted, height: 1.45)),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                style: T.body(16),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              _PasswordField(controller: _password, label: 'Password (8+ characters)', autofillHints: const [AutofillHints.newPassword]),
              const SizedBox(height: 12),
              _PasswordField(controller: _confirm, label: 'Repeat password', onSubmitted: (_) => _submit()),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: T.body(13, color: C.red)),
              ],
              const SizedBox(height: 20),
              SurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.verified_user_outlined, color: C.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('No seed phrase and no wallet app. You confirm each signature with a 4-digit PIN.',
                        style: T.body(13, color: C.text2, height: 1.45)),
                  ),
                ]),
              ),
              const Spacer(),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Create account', loading: _busy, onPressed: _submit),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pushReplacement('/sign-in'),
                child: Text('I already have an account', style: T.body(14, color: C.text2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email) || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().signIn(email, _password.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppState.authMessage(e);
      });
    }
  }

  Future<void> _reset() async {
    final email = await promptText(
      context,
      title: 'Reset your password',
      initial: _email.text.trim(),
      hint: 'Your account email',
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await context.read<AppState>().sendPasswordReset(email);
      if (mounted) showSnack(context, 'If $email has an account, a reset link is on its way.');
    } catch (e) {
      if (mounted) showSnack(context, AppState.authMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: FillScroll(
            children: [
              TopBar(onBack: () => goBack(context, '/welcome')),
              const SizedBox(height: 24),
              Text('Welcome back', style: T.display(32)),
              const SizedBox(height: 8),
              Text('Sign in to see your sheets and anything waiting for your signature.',
                  style: T.body(15, color: C.muted, height: 1.45)),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                style: T.body(16),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _password,
                label: 'Password',
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _reset,
                  child: Text('Forgot password?', style: T.body(14, color: C.accent)),
                ),
              ),
              if (_error != null) Text(_error!, style: T.body(13, color: C.red)),
              const Spacer(),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Sign in', loading: _busy, onPressed: _submit),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pushReplacement('/sign-up'),
                child: Text('Create an account instead', style: T.body(14, color: C.text2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _legal = TextEditingController();
  final _stage = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _legal.dispose();
    _stage.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_legal.text.trim().length < 2) {
      setState(() => _error = 'Add your legal name. It appears on the signed sheet.');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'Choose a 4-digit PIN.');
      return;
    }
    if (_pin.text != _pin2.text) {
      setState(() => _error = 'The two PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().completeProfile(
            legalName: _legal.text,
            stageName: _stage.text,
            pin: _pin.text,
          );
      // The router moves on automatically once the profile exists.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save your profile: $e';
      });
    }
  }

  InputDecoration _pinDecoration(String label) => InputDecoration(labelText: label, counterText: '');

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: FillScroll(
          children: [
            TopBar(
              label: state.authUser?.email ?? 'Last step',
              trailing: TextButton(
                onPressed: () => context.read<AppState>().signOut(),
                child: Text('Sign out', style: T.body(13, color: C.muted)),
              ),
            ),
            const SizedBox(height: 24),
            Text('How should we name you?', style: T.display(30)),
            const SizedBox(height: 8),
            Text('Your legal name goes on signed sheets. Collaborators see your stage name.',
                style: T.body(15, color: C.muted, height: 1.45)),
            const SizedBox(height: 22),
            TextField(
              controller: _legal,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              style: T.body(16),
              decoration: const InputDecoration(labelText: 'Legal name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stage,
              textCapitalization: TextCapitalization.words,
              style: T.body(16),
              decoration: const InputDecoration(labelText: 'Stage name (optional)'),
            ),
            const SizedBox(height: 24),
            Text('Signing PIN', style: T.body(15, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('You confirm every signature with this PIN.', style: T.body(13, color: C.muted)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: T.mono(18),
                  decoration: _pinDecoration('PIN'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pin2,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: T.mono(18),
                  onSubmitted: (_) => _submit(),
                  decoration: _pinDecoration('Repeat PIN'),
                ),
              ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: T.body(13, color: C.red)),
            ],
            const Spacer(),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Finish setup', loading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
