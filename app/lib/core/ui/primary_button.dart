import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

/// The one chartreuse call-to-action a screen may have (CLAUDE.md, spec §12).
/// Shows a spinner while [busy]; disabled when [onPressed] is null. With
/// [pulse] it breathes three times to draw the eye, unless the system asks
/// for reduced motion.
class PrimaryButton extends StatefulWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.pulse = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool pulse;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.pulse && !reduced && !_controller.isAnimating) {
      // 1.6 s per breath (out and back), three times, then still.
      _controller.repeat(reverse: true, count: 3);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FilledButton(
        onPressed: widget.busy
            ? null
            : widget.onPressed == null
            ? null
            : () {
                _controller.stop();
                widget.onPressed!();
              },
        style: FilledButton.styleFrom(
          backgroundColor: RoamioColors.chartreuse,
          foregroundColor: RoamioColors.ink,
          disabledBackgroundColor: RoamioColors.chartreuse.withValues(
            alpha: 0.45,
          ),
          disabledForegroundColor: RoamioColors.ink.withValues(alpha: 0.6),
        ),
        child: widget.busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: RoamioColors.ink,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(widget.label),
                ],
              ),
      ),
    );
  }
}
