import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'onboarding_screen.dart';
import 'new_home_shell.dart';
import '../services/biometric_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _scanController;
  late final AnimationController _glowController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<double> _progressAnimation;
  late final Animation<double> _scanLine;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeInOut),
      ),
    );

    _scanLine = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );

    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    // Wait for both the animation AND preferences to load before navigating.
    // Previously we used a fixed 2800 ms timer which could fire before
    // loadPreferences() completed — causing hasCompletedOnboarding to always
    // be false and the app to flash through onboarding to home.
    Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      _waitForPreferences(),
    ]).then((_) => _navigateNext());
  }

  Future<void> _waitForPreferences() async {
    // Wait until AppState signals preferences are loaded (max 5 s)
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.preferencesLoaded) return;
    }
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.hasCompletedOnboarding) {
      // Check biometric lock
      if (appState.biometricLock) {
        final result = await BiometricService().authenticate(
          reason: 'Unlock your journal',
        );
        if (result != BiometricResult.success && mounted) {
          // If biometric fails, allow retry or go back; for now just continue
        }
      }
      if (!mounted) return;
      _push(const NewHomeShell());
    } else {
      _push(const OnboardingScreen());
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => screen,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _scanController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      body: Stack(
        children: [
          // ── Deep space grid background ─────────────────────────
          const Positioned.fill(child: _GridBackground()),

          // ── Corner accent glows ────────────────────────────────
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -80,
                  child: _AmbientGlow(
                    color: const Color(0xFF5B6EF5),
                    size: 320,
                    opacity: 0.08 * _glowAnim.value,
                  ),
                ),
                Positioned(
                  bottom: -100,
                  left: -60,
                  child: _AmbientGlow(
                    color: const Color(0xFF00D4FF),
                    size: 260,
                    opacity: 0.06 * _glowAnim.value,
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // ── Logo ────────────────────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _mainController,
                    _scanController,
                    _glowController,
                  ]),
                  builder: (_, __) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: _CursorLogo(
                          scanProgress: _scanLine.value,
                          glowIntensity: _glowAnim.value,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36),

                // ── App name ────────────────────────────────────
                FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      Text(
                        'FlowJournal',
                        style: GoogleFonts.dmSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your thoughts, beautifully understood.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.38),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // ── Progress bar ────────────────────────────────
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (_, __) => Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 48, 52),
                    child: Column(
                      children: [
                        // Thin line progress
                        ClipRRect(
                          borderRadius: BorderRadius.circular(1),
                          child: Container(
                            height: 1.5,
                            width: double.infinity,
                            color: Colors.white.withValues(alpha: 0.06),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progressAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF5B6EF5),
                                      Color(0xFF00D4FF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5B6EF5)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'v1.0.0',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            Text(
                              'Initializing',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Cursor-style sharp polygon logo
// ═══════════════════════════════════════════════════════════════

class _CursorLogo extends StatelessWidget {
  final double scanProgress;
  final double glowIntensity;

  const _CursorLogo({
    required this.scanProgress,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _CursorLogoPainter(
          scanProgress: scanProgress,
          glowIntensity: glowIntensity,
        ),
      ),
    );
  }
}

class _CursorLogoPainter extends CustomPainter {
  final double scanProgress;
  final double glowIntensity;

  const _CursorLogoPainter({
    required this.scanProgress,
    required this.glowIntensity,
  });

  Path _hexPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final hexPath = _hexPath(size);
    final cx = size.width / 2;
    final cy = size.height / 2;

    final outerGlowPaint = Paint()
      ..color = const Color(0xFF5B6EF5).withValues(alpha: 0.18 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 16);
    canvas.drawPath(hexPath, outerGlowPaint);

    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.0,
        colors: [
          const Color(0xFF1C1F2E),
          const Color(0xFF0A0C15),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(hexPath, fillPaint);

    canvas.save();
    canvas.clipPath(hexPath);

    final topFacetPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height / 2));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height / 2),
      topFacetPaint,
    );

    if (scanProgress > 0 && scanProgress < 1) {
      final scanY = size.height * scanProgress;
      final scanPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF00D4FF).withValues(alpha: 0.35),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromLTWH(0, scanY - 12, size.width, 24),
        );
      canvas.drawRect(
        Rect.fromLTWH(0, scanY - 12, size.width, 24),
        scanPaint,
      );
    }

    canvas.restore();

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF00D4FF).withValues(alpha: 0.9 * glowIntensity),
          const Color(0xFF5B6EF5).withValues(alpha: 0.6 * glowIntensity),
          const Color(0xFF00D4FF).withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(hexPath, borderPaint);

    final innerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF5B6EF5).withValues(alpha: 0.12 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 4);
    canvas.drawPath(hexPath, innerGlowPaint);

    final fColor = Colors.white.withValues(alpha: 0.92);

    final sw = 3.5;
    final lx = cx - 10.0;
    final ty = cy - 15.0;

    void drawBar(double x, double y, double w, double h) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(1.5),
        ),
        Paint()..color = fColor,
      );
    }

    drawBar(lx, ty, sw, 30);
    drawBar(lx, ty, 20, sw);
    drawBar(lx, ty + 13, 14, sw);

    final dotPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.7 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final dotR = size.width / 2 - 2;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + dotR * math.cos(angle);
      final y = cy + dotR * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_CursorLogoPainter old) =>
      old.scanProgress != scanProgress || old.glowIntensity != glowIntensity;
}

class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AmbientGlow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _AmbientGlow({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}
