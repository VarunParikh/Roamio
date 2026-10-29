import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/invites/ui/invites_on_home.dart';

/// Opened from an invite link (`/i/<code>`, spec UC-12): saves the invite to
/// the person's Invites and takes them Home to see it.
class InviteLinkScreen extends ConsumerStatefulWidget {
  const new({required this.code, super.key});

  final String code;

  @override
  ConsumerState<InviteLinkScreen> createState() => _InviteLinkScreenState();
}

class _InviteLinkScreenState extends ConsumerState<InviteLinkScreen> {
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final message = await addInviteCode(ref, widget.code);
      if (!mounted) return;
      if (message.startsWith('Invite to')) {
        final messenger = ScaffoldMessenger.of(context);
        context.go(AuthRoutes.home);
        messenger.showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      } else {
        setState(() => _message = message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_message == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AuthScaffold(
      title: 'This invite can’t be used',
      subtitle: _message,
      body: const SizedBox.shrink(),
      primary: OutlinedButton(
        onPressed: () => context.go(AuthRoutes.home),
        child: const Text('Go to Home'),
      ),
    );
  }
}
