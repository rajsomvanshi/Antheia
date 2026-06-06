import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════
// Antheia — Interaction System
// 
// This centralizes how the app physically feels.
// Cinematic motion, tactile haptics, and atmospheric textures.
// ═══════════════════════════════════════════════════════════════

/// Semantic animation timings and curves.
class AppMotion {
  AppMotion._();

  // ─── Durations ───
  /// For almost imperceptible, ambient breathing effects
  static const Duration breathe = Duration(milliseconds: 6000);
  
  /// For smooth, sweeping cinematic reveals
  static const Duration cinematic = Duration(milliseconds: 1200);
  
  /// For settling UI components like opening bottom sheets
  static const Duration settle = Duration(milliseconds: 600);
  
  /// Standard UI transitions
  static const Duration glide = Duration(milliseconds: 300);

  /// Quick feedback responses
  static const Duration snap = Duration(milliseconds: 150);

  // ─── Curves ───
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.easeOutQuart;
  static const Curve gentle = Curves.easeInOutSine;
}

/// Semantic haptics — rare, soft, emotionally intentional.
/// Use sparingly: reflection saved, memory resurfaced, long press.
class AppHaptics {
  AppHaptics._();

  /// Very faint, use for scrolling or subtle states.
  static void subtle() => HapticFeedback.selectionClick();

  /// Light tap, use for normal buttons.
  static void light() => HapticFeedback.lightImpact();

  /// Medium tap, use for primary actions.
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy impact, use for errors or finalizing a memory.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Sustained success feel.
  static void success() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
  }
}

/// Atmospheric film grain overlay.
/// Placed over dark backgrounds to give a tactile, warm analog feel.
class CinematicGrain extends StatelessWidget {
  final int seed;
  final bool animate;
  
  const CinematicGrain({
    super.key, 
    this.seed = 7, 
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return CustomPaint(
        painter: _GrainPainter(seed: seed),
        size: Size.infinite,
      );
    }
    
    // Subtle shifting grain for dynamic screens
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return CustomPaint(
          painter: _GrainPainter(seed: DateTime.now().millisecondsSinceEpoch),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GrainPainter extends CustomPainter {
  final int seed;
  const _GrainPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paint = Paint()..isAntiAlias = false;

    const blockSize = 6.0;
    final cols = (size.width / blockSize).ceil();
    final rows = (size.height / blockSize).ceil();

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (rng.nextDouble() > 0.45) continue;

        final opacity = rng.nextDouble() * 0.022;
        paint.color = rng.nextBool()
            ? Colors.white.withValues(alpha: opacity)
            : Colors.black.withValues(alpha: opacity * 0.5);

        canvas.drawRect(
          Rect.fromLTWH(
            x * blockSize + rng.nextDouble() * blockSize,
            y * blockSize + rng.nextDouble() * blockSize,
            1.0,
            1.0,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.seed != seed;
}
