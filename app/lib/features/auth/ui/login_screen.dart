import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/splash/ui/splash_screen.dart';

/// Sign in (UC-2): Google is the one primary action; email is secondary.
class LoginScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted && e.failure != AuthFailure.cancelled) {
        showAuthMessage(context, e.failure.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const RoamioWordmark(size: 48),
              const SizedBox(height: 16),
              Text('Split bills.\nNot friendships.', style: text.displayLarge),
              const SizedBox(height: 12),
              Text(
                'Instant peer splits. Zero awkward math.',
                style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
              ),
              const Spacer(flex: 2),
              PrimaryButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                busy: _busy,
                onPressed: _google,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => context.push(AuthRoutes.loginEmail),
                child: const Text('Sign in with email'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => context.push(AuthRoutes.signup),
                child: const Text('New here? Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
