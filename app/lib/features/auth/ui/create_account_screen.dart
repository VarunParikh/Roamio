import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/auth/ui/dob_field.dart';
import 'package:roamio/features/auth/ui/email_sign_in_screen.dart';
import 'package:roamio/features/auth/ui/privacy_notice_check.dart';

/// Create an email account (UC-3). Under-13s are refused here, before any
/// account exists; the server re-checks the age either way.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  DateTime? _dob;
  bool _accepted = false;
  bool _submitted = false;
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final today = ref.read(todayProvider);
    setState(() => _submitted = true);
    final fieldsOk = _form.currentState!.validate();
    if (!fieldsOk || dobMessage(_dob, today) != null || !_accepted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(authServiceProvider)
          .createAccount(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            dob: _dob!,
          );
    } on AuthException catch (e) {
      if (mounted) showAuthMessage(context, e.failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    return AuthScaffold(
      showBack: true,
      title: 'Create your account',
      subtitle: 'Takes a minute. Then grab your squad.',
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Your name'),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              validator: (v) {
                final name = (v ?? '').trim();
                if (name.isEmpty) return 'Tell us what to call you.';
                return name.length > 60 ? 'Keep it under 60 characters.' : null;
              },
            ),
            const SizedBox(height: 16),
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
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters.',
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Show password' : 'Hide password',
                  icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              validator: (v) =>
                  (v ?? '').length < 8 ? 'Use at least 8 characters.' : null,
            ),
            const SizedBox(height: 16),
            DobField(
              value: _dob,
              today: today,
              onChanged: (d) => setState(() => _dob = d),
              errorText: _submitted || _dob != null
                  ? dobMessage(_dob, today)
                  : null,
            ),
            const SizedBox(height: 8),
            PrivacyNoticeCheck(
              accepted: _accepted,
              onChanged: (v) => setState(() => _accepted = v),
              showError: _submitted && !_accepted,
            ),
          ],
        ),
      ),
      primary: PrimaryButton(
        label: 'Create account',
        busy: _busy,
        onPressed: _submit,
      ),
      footer: TextButton(
        onPressed: () => context.pushReplacement(AuthRoutes.loginEmail),
        child: const Text('Already have an account? Sign in'),
      ),
    );
  }
}
