import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/home/ui/home_screen.dart';

/// The 10 photos behind the image card (spec UC-6), bundled with the app.
const List<String> destinationPhotos = [
  'assets/destinations/alpine.webp',
  'assets/destinations/amalfi.webp',
  'assets/destinations/brooklyn.webp',
  'assets/destinations/dubai.webp',
  'assets/destinations/fuji.webp',
  'assets/destinations/himalaya.webp',
  'assets/destinations/machu_picchu.webp',
  'assets/destinations/maldives.webp',
  'assets/destinations/paris.webp',
  'assets/destinations/santorini.webp',
];

/// A new pick each time the app opens, the same until then.
final destinationPhotoProvider = Provider<String>(
  (ref) => destinationPhotos[Random().nextInt(destinationPhotos.length)],
);

/// How dark the scrim is, at its lightest, wherever text sits. Checked against
/// every pixel of the 10 photos in `first_screen_test`, so white text keeps
/// 4.5:1 whichever photo comes up and however it's cropped.
const planCardTextScrimAlpha = 0.58;

/// "Plan your next adventure", shown with nothing ahead (spec UC-6). The photo
/// is decoration, so TalkBack skips it.
class PlanAdventureCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(RoamioRadii.lg),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: Image.asset(
                ref.watch(destinationPhotoProvider),
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
                  stops: const [0, 0.75, 1],
                  colors: [
                    RoamioColors.ink.withValues(alpha: 0.66),
                    RoamioColors.ink.withValues(alpha: planCardTextScrimAlpha),
                    RoamioColors.ink.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Plan your next adventure',
                  style: text.displayLarge?.copyWith(
                    color: RoamioColors.surface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track expenses, split bills and create unforgettable trips '
                  'with your squad.',
                  style: text.bodyLarge?.copyWith(color: RoamioColors.surface),
                ),
                const SizedBox(height: 40),
                PrimaryButton(
                  label: 'Create a new adventure',
                  icon: Icons.add,
                  pulse: true,
                  onPressed: () => context.push(newAdventureRoute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "No adventures yet" card, with a polaroid drawn in plain Flutter.
class NoAdventuresCard extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const ExcludeSemantics(child: _Polaroids()),
            const SizedBox(height: 16),
            Text(
              'No adventures yet',
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Once you add an adventure, your expenses, splits and activity '
              'will appear here.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _Polaroids extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    height: 130,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -0.14,
          child: Transform.translate(
            offset: const Offset(-18, 4),
            child: const _Polaroid(sky: [Color(0xFFD5DBFB), Color(0xFFE8EAFD)]),
          ),
        ),
        Transform.translate(
          offset: const Offset(10, 0),
          child: const _Polaroid(
            sky: [Color(0xFF4FC3F7), Color(0xFFFFF3C4)],
            scene: true,
          ),
        ),
      ],
    ),
  );
}

class _Polaroid extends StatelessWidget {
  const new({required this.sky, this.scene = false});

  final List<Color> sky;
  final bool scene;

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    height: 124,
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
    decoration: BoxDecoration(
      color: RoamioColors.surface,
      borderRadius: BorderRadius.circular(RoamioRadii.sm),
      border: Border.all(color: RoamioColors.hairline),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: sky,
          ),
        ),
        child: !scene
            ? null
            : Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFC53D),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Positioned(
                    bottom: 2,
                    child: Text('🌴', style: TextStyle(fontSize: 34)),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 10,
                      color: const Color(0xFF0288D1),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}
