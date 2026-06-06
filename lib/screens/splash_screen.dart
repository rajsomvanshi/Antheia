import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/biometric_state.dart';
import '../state/preferences_state.dart';
import '../theme/app_theme.dart';
import '../theme/interaction_system.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/revenuecat_service.dart';
import 'new_home_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _envController;
  late final Animation<double> _envAnim;
  late final AnimationController _grainController;
  late final Animation<double> _grainAnim;
  late final AnimationController _logoController;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoBlur;
  late final Animation<double> _logoY;
  late final Animation<double> _sublineOpacity;

  bool _isNavigated = false;

  @override
  void initState() {
    super.initState();

    // Set status bar styles always dark on splash screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    _envController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat(reverse: true);
    _envAnim = CurvedAnimation(
      parent: _envController,
      curve: Curves.easeInOut,
    );

    _grainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _grainAnim = CurvedAnimation(
      parent: _grainController,
      curve: Curves.easeInOut,
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..forward();

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOut),
      ),
    );
    _logoBlur = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOut),
      ),
    );
    _logoY = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.20, 0.50, curve: Curves.easeOut),
      ),
    );
    _sublineOpacity = Tween<double>(begin: 0.0, end: 0.70).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.38, 0.65, curve: Curves.easeOut),
      ),
    );

    Future.wait([
      Future.delayed(const Duration(milliseconds: 5200)),
      _waitForPreferences(),
    ]).then((_) => _navigateNext());
  }

  Future<void> _waitForPreferences() async {
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      final prefsState = Provider.of<PreferencesState>(context, listen: false);
      if (prefsState.preferencesLoaded) return;
    }
  }

  Future<void> _navigateNext() async {
    if (_isNavigated || !mounted) return;
    _isNavigated = true;

    final prefsState = Provider.of<PreferencesState>(context, listen: false);

    if (prefsState.hasCompletedOnboarding) {
      // ── REINSTALL GUARD ──────────────────────────────────────────
      // On Android, SharedPreferences survives reinstall via Auto-Backup,
      // but the Keystore (Supabase session) is wiped. If onboarding says
      // "done" but there's no active session, it's a stale reinstall.
      // Reset the onboarding flag so the user goes through auth again.
      final hasSession = AuthService().isSignedIn;
      final supabaseConfigured = AuthService().isSupabaseReady;
      final isGuest = AuthService().sessionState == AuthSessionState.guest;
      if (!hasSession && supabaseConfigured && !isGuest) {
        await prefsState.resetOnboardingOnly();
        if (mounted) _push(const OnboardingScreen());
        return;
      }
      // ─────────────────────────────────────────────────────────────

      // Re-verify Premium status on launch
      try {
        final info = await RevenueCatService()
            .getCustomerInfo()
            .timeout(const Duration(seconds: 3));
        if (info != null) {
          final isActive = RevenueCatService().isPremiumActive(info);
          prefsState.setPremium(isActive);
        }
      } catch (e) {
        debugPrint('[SplashScreen] RevenueCat check failed or timed out, using cached status: $e');
      }

      if (prefsState.biometricLock) {
        context.read<BiometricState>().lock();
      }
      if (AuthService().isSignedIn) {
        // Sync is handled safely by NewHomeShell._safeSync() after navigation.
        // DO NOT call syncNow() here — it creates a race condition with the
        // home shell sync, causing data loss when both run concurrently.
        debugPrint('[SplashScreen] User signed in — sync will run in NewHomeShell');
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
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  void dispose() {
    _envController.dispose();
    _grainController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final type = AppType.of(context);

    return Scaffold(
      // Always absolute dark theme on Splash Screen per visual guidelines
      backgroundColor: const Color(0xFF100F0E),
      body: GestureDetector(
        onTap: () {
          AppHaptics.subtle();
          _navigateNext();
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _envAnim,
                builder: (_, __) => CustomPaint(
                  painter: _AtmospherePainter(breathe: _envAnim.value),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.25,
                      colors: [
                        Colors.transparent,
                        Color(0x33000000),
                        Color(0x77000000),
                      ],
                      stops: [0.38, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _grainAnim,
                builder: (_, __) => Opacity(
                  opacity: (1.0 - _grainAnim.value).clamp(0.0, 1.0),
                  child: const CinematicGrain(seed: 7, animate: false),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _grainAnim,
                builder: (_, __) => Opacity(
                  opacity: _grainAnim.value.clamp(0.0, 1.0),
                  child: const CinematicGrain(seed: 42, animate: false),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _logoController,
              builder: (_, __) {
                return Positioned(
                  left: 0,
                  right: 0,
                  top: size.height * 0.44 - 32,
                  child: Transform.translate(
                    offset: Offset(0, _logoY.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: _logoOpacity.value,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: _logoBlur.value,
                              sigmaY: _logoBlur.value,
                            ),
                            child: Text(
                              'Antheia',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 36,
                                fontWeight: FontWeight.normal,
                                color: const Color(0xFFD0B08A), // Muted premium gold
                                letterSpacing: 6.0,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: _sublineOpacity.value,
                          child: Text(
                            'A place for what remains.',
                            textAlign: TextAlign.center,
                            style: type.small.copyWith(
                              color: const Color(0x9CF2F0EB), // Faint warm ivory
                              letterSpacing: 2.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  final double breathe;

  const _AtmospherePainter({required this.breathe});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Surgical gold accent glow (8% max opacity) per P8
    final warmOpacity = 0.040 + (0.040 * breathe);
    final warmPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.30),
        radius: 1.05,
        colors: [
          const Color(0xFFD0B08A).withValues(alpha: warmOpacity),
          const Color(0xFF9B7A4A).withValues(alpha: warmOpacity * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, warmPaint);

    final shadowOpacity = 0.050 - (0.020 * breathe);
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: const Alignment(0, 0.3),
        colors: [
          Colors.black.withValues(alpha: shadowOpacity.clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, shadowPaint);
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) => old.breathe != breathe;
}
