import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

/// Shared layout for the sign-in screens: a title block, a scrolling body,
/// and the screen's one primary action pinned at the bottom.
class AuthScaffold extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    required this.primary,
    this.subtitle,
    this.footer,
    this.showBack = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget primary;
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: showBack
          ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  Text(title, style: text.headlineLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: text.bodyLarge?.copyWith(
                        color: RoamioColors.slate,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  body,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [primary, ?footer],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [message] as a floating snackbar.
void showAuthMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
