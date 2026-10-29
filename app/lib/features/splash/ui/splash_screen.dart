import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';

/// Shown while sign-in state loads and while the server sets up a new
/// account (UC-1). The router moves on as soon as the stage is known.
class SplashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final settingUp =
        ref.watch(sessionStageProvider).value == SessionStage.settingUp;
    return Scaffold(
      backgroundColor: RoamioColors.ink,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RoamioWordmark(color: RoamioColors.surface, size: 44),
              const SizedBox(height: 12),
              Text(
                'Split bills. Not friendships.',
                style: text.headlineSmall?.copyWith(
                  color: RoamioColors.surface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Instant peer splits. Zero awkward math.',
                style: text.bodyMedium?.copyWith(color: RoamioColors.muted),
              ),
              const SizedBox(height: 40),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: RoamioColors.chartreuse,
                ),
              ),
              if (settingUp) ...[
                const SizedBox(height: 16),
                Text(
                  'Setting up your account…',
                  style: text.bodyMedium?.copyWith(color: RoamioColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "roamio." with the chartreuse full stop from the design references.
class RoamioWordmark extends StatelessWidget {
  const new({this.color = RoamioColors.ink, this.size = 32, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge
        ?.copyWith(fontSize: size, color: color);
    return Semantics(
      label: 'Roamio',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: 'roamio',
          style: style,
          children: [
            TextSpan(
              text: '.',
              style: style?.copyWith(color: RoamioColors.chartreuse),
            ),
          ],
        ),
      ),
    );
  }
}
