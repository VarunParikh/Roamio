import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? emailMessage(String value) => _emailPattern.hasMatch(value.trim())
    ? null
    : 'Enter a valid email address.';

/// Email + password sign-in, with a password reset so nobody gets stuck.
class EmailSignInScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && done != null) showAuthMessage(context, done);
    } on AuthException catch (e) {
      if (mounted) showAuthMessage(context, e.failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    return AuthScaffold(
      showBack: true,
      title: 'Welcome back',
      subtitle: 'Sign in with your email.',
      body: Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: (v) => emailMessage(v ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _hidden,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Show password' : 'Hide password',
                  icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Enter your password.' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        final problem = emailMessage(_email.text);
                        if (problem != null) {
                          showAuthMessage(
                            context,
                            'Enter your email above first.',
                          );
                          return;
                        }
                        unawaited(
                          _run(
                            () => auth.sendPasswordReset(_email.text.trim()),
                            done: 'Check your inbox for a reset link.',
                          ),
                        );
                      },
                child: const Text('Forgot password?'),
              ),
            ),
          ],
        ),
      ),
      primary: PrimaryButton(
        label: 'Sign in',
        busy: _busy,
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          unawaited(
            _run(
              () => auth.signInWithEmail(
                email: _email.text.trim(),
                password: _password.text,
              ),
            ),
          );
        },
      ),
      footer: TextButton(
        onPressed: () => context.pushReplacement(AuthRoutes.signup),
        child: const Text('New here? Create an account'),
      ),
    );
  }
}
