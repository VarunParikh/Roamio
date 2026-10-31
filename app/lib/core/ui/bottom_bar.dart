import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

class BottomBarItem {
  const new({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Floating frosted pill navigation (design/DESIGN.md → Floating Bottom Bar).
class RoamioBottomBar extends StatelessWidget {
  const new({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final List<BottomBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RoamioRadii.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RoamioColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(RoamioRadii.full),
              border: Border.all(
                color: RoamioColors.ink.withValues(alpha: 0.08),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _BarButton(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const new({required this.item, required this.selected, required this.onTap});

  final BottomBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? RoamioColors.ink : RoamioColors.slate;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? RoamioColors.chartreuse : Colors.transparent,
            borderRadius: BorderRadius.circular(RoamioRadii.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 20, color: color),
              const SizedBox(width: 6),
              // Shrinks rather than overflows on a small phone or large text.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
