import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../screens/editor_screen.dart';
import '../screens/aurora_voice_screen.dart';

// ═══════════════════════════════════════════════════════════════
// FloatingMascotFab — Animated expandable bottom-center FAB
//
// Collapsed: small '+ Journal' pill at bottom center.
// Expanded:  3 options fan out — Text (left), Mascot (center),
//            Voice (right) — with a spring animation and a
//            semi-transparent scrim that dismisses on tap-outside.
// ═══════════════════════════════════════════════════════════════

class FloatingMascotFab extends StatefulWidget {
  const FloatingMascotFab({super.key});

  @override
  State<FloatingMascotFab> createState() => _FloatingMascotFabState();
}

class _FloatingMascotFabState extends State<FloatingMascotFab>
    with TickerProviderStateMixin {
  // ─── Primary expand/collapse controller ────────────────────
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  // ─── Sparkle rotation controller ───────────────────────────
  late final AnimationController _sparkleController;

  // ─── Mascot pulse (glow) controller ────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ─── Scrim fade ────────────────────────────────────────────
  late final Animation<double> _scrimOpacity;

  bool _isExpanded = false;

  // ── Spring-like physics using CurvedAnimation ──────────────
  static const _springCurve = Curves.elasticOut;
  static const _collapseCurve = Curves.easeInCubic;

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: _springCurve,
      reverseCurve: _collapseCurve,
    );

    _scrimOpacity = Tween<double>(begin: 0, end: 0.55).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: const Interval(0, 0.4, curve: Curves.easeOut),
        reverseCurve: const Interval(0, 0.6, curve: Curves.easeIn),
      ),
    );

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _sparkleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  void _collapse() {
    if (_isExpanded) {
      HapticFeedback.lightImpact();
      setState(() {
        _isExpanded = false;
        _expandController.reverse();
      });
    }
  }

  void _onTextTap(BuildContext ctx) {
    _collapse();
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!ctx.mounted) return;
      ctx.read<AppState>().setCurrentEntry(null);
      // NOTE: EditorScreen handles null by creating a new entry now.
      Navigator.of(ctx).push(
        PageRouteBuilder(
          pageBuilder: (c, a, s) => const EditorScreen(),
          transitionsBuilder: (c, a, s, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  void _onVoiceTap(BuildContext ctx) {
    _collapse();
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!ctx.mounted) return;
      Navigator.of(ctx).push(
        PageRouteBuilder(
          pageBuilder: (c, a, s) => const AuroraVoiceScreen(),
          transitionsBuilder: (c, a, s, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // ── Scrim ─────────────────────────────────────────────
        if (_isExpanded)
          AnimatedBuilder(
            animation: _scrimOpacity,
            builder: (context, _) {
              return GestureDetector(
                onTap: _collapse,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withOpacity(_scrimOpacity.value),
                ),
              );
            },
          ),

        // ── Bottom area with expanded options + pill ──────────
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expanded options row
              AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  final t = _expandAnimation.value;
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - t.clamp(0.0, 1.0))),
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // LEFT — Text button
                      _TextOptionButton(onTap: () => _onTextTap(context)),
                      const SizedBox(width: 16),

                      // CENTER — Mascot
                      _MascotOrb(
                        sparkleController: _sparkleController,
                        pulseAnimation: _pulseAnimation,
                        onTap: _collapse,
                      ),
                      const SizedBox(width: 16),

                      // RIGHT — Voice button
                      _VoiceOptionButton(onTap: () => _onVoiceTap(context)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Collapsed pill / expand trigger
              GestureDetector(
                onTap: _toggle,
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, _) {
                    final t = _expandAnimation.value.clamp(0.0, 1.0);
                    return Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 0),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          AppColors.accentPrimary,
                          Colors.white,
                          t * 0.15,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.accentPrimary.withOpacity(0.4),
                            blurRadius: 16 + (t * 8),
                            spreadRadius: t * 3,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isExpanded ? 'Close' : 'Journal',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Text Option Button ─────────────────────────────────────────

class _TextOptionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TextOptionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✏️', style: TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              'Text',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Voice Option Button ────────────────────────────────────────

class _VoiceOptionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _VoiceOptionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF00B4D8).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_rounded, size: 26, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              'Voice',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mascot Orb ─────────────────────────────────────────────────
// 80px animated circle with rotating sparkles + pulsing cyan glow.

class _MascotOrb extends StatelessWidget {
  final AnimationController sparkleController;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _MascotOrb({
    required this.sparkleController,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([sparkleController, pulseAnimation]),
        builder: (context, _) {
          final pulse = pulseAnimation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 96 * pulse,
                height: 96 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00B4D8).withOpacity(0.15 * pulse),
                ),
              ),

              // Core orb (Dark for mascot PNG)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black, // Dark background to fit the PNG
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55 * pulse),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mascot.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.error_outline_rounded, size: 30, color: Colors.white),
                    ),
                  ),
                ),
              ),

            ],
          );
        },
      ),
    );
  }
}
