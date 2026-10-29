import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';

/// Seconds between verification-email resends (UC-2).
const resendCooldown = 60;

/// "Check your inbox" for email sign-ups (UC-2).
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  // The email was sent at sign-up, so the first resend also waits.
  int _wait = resendCooldown;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _wait = resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) t.cancel();
      setState(() => _wait--);
    });
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
    final email = auth.email ?? 'your email';
    return AuthScaffold(
      title: 'Check your inbox 📬',
      subtitle:
          'We sent a link to $email. Tap it, then come back here. '
          'Can’t see it? Look in spam.',
      body: const SizedBox.shrink(),
      primary: PrimaryButton(
        label: 'I’ve verified my email',
        busy: _busy,
        onPressed: () => _run(() async {
          final verified = await auth.refreshUser();
          // Verified: the router moves on. Otherwise say why we stayed.
          if (!verified && mounted) {
            showAuthMessage(
              this.context,
              'Not verified yet. Tap the link in the email first.',
            );
          }
        }),
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy || _wait > 0
                ? null
                : () async {
                    await _run(
                      auth.sendVerificationEmail,
                      done: 'Sent again. Check your inbox.',
                    );
                    if (mounted) _startCooldown();
                  },
            child: Text(
              _wait > 0 ? 'Resend email in ${_wait}s' : 'Resend email',
            ),
          ),
          TextButton(
            onPressed: _busy ? null : auth.signOut,
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}
