import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AmbientPulseGlow extends StatefulWidget {
  const AmbientPulseGlow({super.key});

  @override
  State<AmbientPulseGlow> createState() => _AmbientPulseGlowState();
}

class _AmbientPulseGlowState extends State<AmbientPulseGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _primaryGlow;
  late Animation<double> _secondaryGlow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    // Primary glow: warm accent, closer to top
    _primaryGlow = Tween<double>(begin: 0.04, end: 0.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    // Secondary glow: wider, softer, slightly offset timing
    _secondaryGlow = Tween<double>(begin: 0.02, end: 0.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.easeInOutSine),
      ),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intensity = AnimationScale.of(context);
    if (intensity == AnimationIntensity.stillness) {
      return const SizedBox.shrink();
    }
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -1.0),
              radius: 1.2,
              colors: [
                colors.accent.withValues(alpha: _primaryGlow.value),
                colors.accent.withValues(alpha: _secondaryGlow.value * 0.3),
                colors.accent.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.8),
                radius: 1.8,
                colors: [
                  colors.accent.withValues(alpha: _secondaryGlow.value),
                  colors.accent.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}
