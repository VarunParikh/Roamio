import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/config/phase2.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/auth/ui/google_logo.dart';
import 'package:roamio/features/auth/ui/privacy_notice_check.dart';
import 'package:roamio/features/home/ui/first_screen_cards.dart';
import 'package:roamio/features/splash/ui/splash_screen.dart';

/// The "18 or older and read the notice" tick from the first page, kept until
/// the account is set up, so the next screens don't ask again.
final termsAcceptedProvider = NotifierProvider<TermsAccepted, bool>(
  TermsAccepted.new,
);

class TermsAccepted extends Notifier<bool> {
  @override
  bool build() => false;

  // A provider's state, set from the tick; a setter would hide that it's one.
  // ignore: use_setters_to_change_properties
  void set({required bool accepted}) => state = accepted;
}

/// Whether the first page's photo drifts. Off in tests, so screens can settle.
final panSplashPhotoProvider = Provider<bool>((ref) => true);

/// Sign in (UC-2): a slowly moving destination photo under a gradient dark
/// enough for the text, then the tick and the ways in. Google's button keeps
/// its own white style, as Google's branding asks.
class LoginScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    // Whoever signs in next, say after a sign-out, ticks for themselves.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(termsAcceptedProvider.notifier).set(accepted: false);
      }
    });
  }

  /// With under-18s on (Phase 2), the date of birth comes first, later.
  bool get _asksTick => !ref.read(minorsEnabledProvider);

  /// True if they may go on; otherwise points at the tick.
  bool _canContinue() {
    if (!_asksTick || ref.read(termsAcceptedProvider)) return true;
    setState(() => _tried = true);
    return false;
  }

  Future<void> _google() async {
    if (!_canContinue()) return;
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

  void _open(String route) {
    if (_canContinue()) unawaited(context.push(route));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accepted = ref.watch(termsAcceptedProvider);
    final asksTick = !ref.watch(minorsEnabledProvider);
    return Scaffold(
      backgroundColor: RoamioColors.ink,
      body: Stack(
        children: [
          Positioned.fill(
            child: ref.watch(panSplashPhotoProvider)
                ? PanningPhoto(photo: ref.watch(splashPhotoProvider))
                : ExcludeSemantics(
                    child: Image.asset(
                      ref.watch(splashPhotoProvider),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: RoamioColors.ink),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    RoamioColors.ink.withValues(alpha: planCardTextScrimAlpha),
                    RoamioColors.ink.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 32),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        const RoamioWordmark(
                          size: 48,
                          color: RoamioColors.surface,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Split bills.\nNot friendships.',
                          style: text.displayLarge?.copyWith(
                            color: RoamioColors.surface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Instant peer splits. Zero awkward math.',
                          style: text.bodyLarge?.copyWith(
                            color: RoamioColors.surface,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Spacer(flex: 2),
                        if (asksTick) ...[
                          PrivacyNoticeCheck(
                            accepted: accepted,
                            onChanged: (v) {
                              ref
                                  .read(termsAcceptedProvider.notifier)
                                  .set(accepted: v);
                              setState(() => _tried = false);
                            },
                            showError: _tried && !accepted,
                            adultDeclaration: true,
                            onDark: true,
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: RoamioColors.surface,
                            foregroundColor: RoamioColors.ink,
                          ),
                          onPressed: _busy ? null : _google,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: RoamioColors.ink,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GoogleLogo(),
                                    SizedBox(width: 12),
                                    Flexible(
                                      child: Text('Continue with Google'),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RoamioColors.surface,
                            side: const BorderSide(color: RoamioColors.surface),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _open(AuthRoutes.loginEmail),
                          child: const Text('Sign in with email'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: RoamioColors.surface,
                          ),
                          onPressed: _busy
                              ? null
                              : () => _open(AuthRoutes.signup),
                          child: const Text('New here? Create an account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
