import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/config/phase2.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/auth/ui/dob_field.dart';
import 'package:roamio/features/auth/ui/privacy_notice_check.dart';

/// Google sign-ups give their date of birth once (UC-3). An under-13 is
/// signed out and their new sign-in removed.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  DateTime? _dob;
  bool _accepted = false;
  bool _submitted = false;
  bool _busy = false;

  Future<void> _submit() async {
    final today = ref.read(todayProvider);
    final auth = ref.read(authServiceProvider);
    setState(() => _submitted = true);
    // The pilot asks no birth date (lib/core/config/phase2.dart): the tick
    // says they're 18 or older.
    if (!ref.read(minorsEnabledProvider)) {
      if (!_accepted) return;
      setState(() => _busy = true);
      try {
        await auth.completeProfile(dob: null);
      } on AuthException catch (e) {
        if (mounted) showAuthMessage(context, e.failure.message);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    final dob = _dob;
    if (dob == null || dobProblem(dob, today) != null || !_accepted) return;

    setState(() => _busy = true);
    try {
      if (bracketFor(dob, today) == AgeBracket.underThirteen) {
        await auth.deleteCurrentUser();
        await auth.signOut();
        if (mounted) {
          showAuthMessage(
            context,
            'Sorry, Roamio is for people aged 13 and over.',
          );
        }
        return;
      }
      await auth.completeProfile(dob: dob);
    } on AuthException catch (e) {
      if (mounted) showAuthMessage(context, e.failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final name = ref.read(authServiceProvider).displayName?.split(' ').first;
    final dobError = _submitted || _dob != null
        ? dobProblem(_dob, today)
        : null;
    final asksDob = ref.watch(minorsEnabledProvider);
    return AuthScaffold(
      title: name == null ? 'One last thing' : 'One last thing, $name',
      subtitle: asksDob
          ? 'We need your date of birth to keep under-18s safe.'
          : 'Please confirm you’re 18 or older and accept the privacy notice.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (asksDob) ...[
            DobField(
              value: _dob,
              today: today,
              onChanged: (d) => setState(() => _dob = d),
              errorText: dobError == null ? null : dobMessage(_dob, today),
            ),
            const SizedBox(height: 8),
          ],
          PrivacyNoticeCheck(
            accepted: _accepted,
            onChanged: (v) => setState(() => _accepted = v),
            showError: _submitted && !_accepted,
            adultDeclaration: !asksDob,
          ),
        ],
      ),
      primary: PrimaryButton(
        label: 'Continue',
        busy: _busy,
        onPressed: _submit,
      ),
      footer: TextButton(
        onPressed: _busy ? null : ref.read(authServiceProvider).signOut,
        child: const Text('Use a different account'),
      ),
    );
  }
}
