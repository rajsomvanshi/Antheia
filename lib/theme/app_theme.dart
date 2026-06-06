import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/preferences_state.dart';

// ═══════════════════════════════════════════════════════════════
// Antheia — Design System  Phase 3
//
// Changes from Phase 2:
//   • Real light mode: warm ivory, charcoal type, paper warmth
//   • Typography token architecture — font propagates everywhere
//   • Animation intensity exposed as multiplier (respected app-wide)
//   • AppColors becomes theme-aware via static getters
//   • Removed ThemeType fake presets (cosmetic, unimplemented)
// ═══════════════════════════════════════════════════════════════

// ─── Animation Intensity ──────────────────────────────────────
//
// Read via AnimationScale.of(context) anywhere in the tree.
// PreferencesState feeds this through an InheritedWidget.
//
enum AnimationIntensity {
  stillness,  // No motion. Full accessibility.
  reduced,    // Subtle. Short durations.
  full,       // Default. All atmosphere active.
}

extension AnimationIntensityExtensions on AnimationIntensity {
  /// Scale factor: multiply base duration by this value.
  double get durationScale {
    switch (this) {
      case AnimationIntensity.stillness:
        return 0.0;
      case AnimationIntensity.reduced:
        return 0.4;
      case AnimationIntensity.full:
        return 1.0;
    }
  }

  /// Whether ambient/looping animations (orbs, drift) should run.
  bool get ambientEnabled => this == AnimationIntensity.full;
}

class AnimationScale extends InheritedWidget {
  final AnimationIntensity intensity;

  const AnimationScale({
    super.key,
    required this.intensity,
    required super.child,
  });

  static AnimationScale? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnimationScale>();

  static AnimationIntensity of(BuildContext context) =>
      maybeOf(context)?.intensity ?? AnimationIntensity.full;

  @override
  bool updateShouldNotify(AnimationScale old) => old.intensity != intensity;
}

// Helper to get a scaled duration
extension ScaledDuration on Duration {
  Duration scaled(BuildContext context) {
    final scale = AnimationScale.of(context).durationScale;
    if (scale == 0.0) return Duration.zero;
    return Duration(
      microseconds: (inMicroseconds * scale).round(),
    );
  }
}

// ─── Theme type (kept for data compatibility only) ────────────
enum ThemeType { defaultLight, earthyLuxury, chocolateTruffle, wisteriaBloom }

// ─── Color Palettes ───────────────────────────────────────────

class _DarkPalette {
  // Backgrounds
  static const Color bg = Color(0xFF100F0E);
  static const Color surface = Color(0xFF181714);
  static const Color surfaceElevated = Color(0xFF1E1C19);
  static const Color surfaceHover = Color(0xFF23211D);

  // Text
  static const Color text = Color(0xFFF2F0EB);
  static const Color textSecondary = Color(0x8CF2F0EB);
  static const Color textTertiary = Color(0x5CF2F0EB);
  static const Color textFaint = Color(0x2EF2F0EB);

  // Borders
  static const Color border = Color(0x0FF2F0EB);
  static const Color borderLight = Color(0x1AF2F0EB);

  // Accent
  static const Color accent = Color(0xFFD0B08A);
  static const Color accentMuted = Color(0x66D0B08A);
  static const Color accentFaint = Color(0x1AD0B08A);

  // Semantic
  static const Color success = Color(0xFF30A46C);
  static const Color error = Color(0xFFE5484D);
}

class _LightPalette {
  // ── Warm ivory paper — editorial, literary, archival ──
  // NOT white startup UI. Paper warmth. Charcoal typography.

  // Backgrounds
  static const Color bg = Color(0xFFF7F4EE);       // warm ivory
  static const Color surface = Color(0xFFEFEBE3);  // slightly deeper paper
  static const Color surfaceElevated = Color(0xFFE8E4DB);
  static const Color surfaceHover = Color(0xFFE2DDD4);

  // Text — charcoal with warmth, not cold black
  static const Color text = Color(0xFF2A2520);          // warm charcoal
  static const Color textSecondary = Color(0x992A2520); // 60%
  static const Color textTertiary = Color(0x662A2520);  // 40%
  static const Color textFaint = Color(0x332A2520);     // 20%

  // Borders — warm sepia, very subtle
  static const Color border = Color(0x1A2A2520);        // 10%
  static const Color borderLight = Color(0x262A2520);   // 15%

  // Accent — deeper warm gold (readable on ivory)
  static const Color accent = Color(0xFF9B7A4A);
  static const Color accentMuted = Color(0x669B7A4A);
  static const Color accentFaint = Color(0x1A9B7A4A);

  // Semantic
  static const Color success = Color(0xFF2A8A5A);
  static const Color error = Color(0xFFBF3030);
}

// ─── AppColors — resolved at runtime based on brightness ─────
//
// Usage: AppColors.of(context).bg
// Static fallback (dark) retained for files that don't have context.
//
class AppColors {
  AppColors._();

  // ── Static dark constants (legacy compatibility) ──
  static const Color bg = _DarkPalette.bg;
  static const Color surface = _DarkPalette.surface;
  static const Color surfaceElevated = _DarkPalette.surfaceElevated;
  static const Color surfaceHover = _DarkPalette.surfaceHover;
  static const Color text = _DarkPalette.text;
  static const Color textSecondary = _DarkPalette.textSecondary;
  static const Color textTertiary = _DarkPalette.textTertiary;
  static const Color textFaint = _DarkPalette.textFaint;
  static const Color border = _DarkPalette.border;
  static const Color borderLight = _DarkPalette.borderLight;
  static const Color accent = _DarkPalette.accent;
  static const Color accentMuted = _DarkPalette.accentMuted;
  static const Color accentFaint = _DarkPalette.accentFaint;
  static const Color reflection = Color(0xFF8B9E7C);
  static const Color reflectionMuted = Color(0x668B9E7C);
  static const Color reflectionFaint = Color(0x1A8B9E7C);
  static const Color error = _DarkPalette.error;
  static const Color success = _DarkPalette.success;
  static const Color hairline = Color(0x1AF2F0EB);
  static const Color atmosphericGlow = Color(0x14D0B08A);

  // ── Context-aware palette ──
  static ResolvedColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    ThemeType themeType = ThemeType.defaultLight;
    try {
      final prefs = Provider.of<PreferencesState>(context, listen: true);
      themeType = prefs.activeThemeType;
    } catch (_) {}
    return ResolvedColors.resolve(brightness, themeType);
  }
}

class ResolvedColors {
  final Color bg;
  final Color surface;
  final Color surfaceElevated;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color textFaint;
  final Color border;
  final Color borderLight;
  final Color accent;
  final Color accentMuted;
  final Color accentFaint;
  final Color success;
  final Color error;
  final Color hairline;
  final Color atmosphericGlow;

  const ResolvedColors({
    required this.bg,
    required this.surface,
    required this.surfaceElevated,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.textFaint,
    required this.border,
    required this.borderLight,
    required this.accent,
    required this.accentMuted,
    required this.accentFaint,
    required this.success,
    required this.error,
    required this.hairline,
    required this.atmosphericGlow,
  });

  factory ResolvedColors.resolve(Brightness brightness, ThemeType type) {
    if (brightness == Brightness.light) {
      switch (type) {
        case ThemeType.earthyLuxury:
          return const ResolvedColors(
            bg: Color(0xFFF4F6F0),
            surface: Color(0xFFEBEFE5),
            surfaceElevated: Color(0xFFE2E9DB),
            text: Color(0xFF282C22),
            textSecondary: Color(0x99282C22),
            textTertiary: Color(0x66282C22),
            textFaint: Color(0x33282C22),
            border: Color(0x1A282C22),
            borderLight: Color(0x26282C22),
            accent: Color(0xFF8F9E7C),
            accentMuted: Color(0x668F9E7C),
            accentFaint: Color(0x1A8F9E7C),
            success: Color(0xFF2A8A5A),
            error: Color(0xFFBF3030),
            hairline: Color(0x1A282C22),
            atmosphericGlow: Color(0x148F9E7C),
          );
        case ThemeType.chocolateTruffle:
          return const ResolvedColors(
            bg: Color(0xFFF8F5F2),
            surface: Color(0xFFEFEBDE),
            surfaceElevated: Color(0xFFE4DFD0),
            text: Color(0xFF2E2420),
            textSecondary: Color(0x992E2420),
            textTertiary: Color(0x662E2420),
            textFaint: Color(0x332E2420),
            border: Color(0x1A2E2420),
            borderLight: Color(0x262E2420),
            accent: Color(0xFFC0A080),
            accentMuted: Color(0x66C0A080),
            accentFaint: Color(0x1AC0A080),
            success: Color(0xFF2A8A5A),
            error: Color(0xFFBF3030),
            hairline: Color(0x1A2E2420),
            atmosphericGlow: Color(0x14C0A080),
          );
        case ThemeType.wisteriaBloom:
          return const ResolvedColors(
            bg: Color(0xFFF5F3F8),
            surface: Color(0xFFEBE7F2),
            surfaceElevated: Color(0xFFE1DBEB),
            text: Color(0xFF262035),
            textSecondary: Color(0x99262035),
            textTertiary: Color(0x66262035),
            textFaint: Color(0x33262035),
            border: Color(0x1A262035),
            borderLight: Color(0x26262035),
            accent: Color(0xFFB39DDB),
            accentMuted: Color(0x66B39DDB),
            accentFaint: Color(0x1AB39DDB),
            success: Color(0xFF2A8A5A),
            error: Color(0xFFBF3030),
            hairline: Color(0x1A262035),
            atmosphericGlow: Color(0x14B39DDB),
          );
        case ThemeType.defaultLight:
          return const ResolvedColors._light();
      }
    }
    
    switch (type) {
      case ThemeType.earthyLuxury:
        return const ResolvedColors(
          bg: Color(0xFF1E1F1A),
          surface: Color(0xFF282922),
          surfaceElevated: Color(0xFF32332B),
          text: Color(0xFFECEBE6),
          textSecondary: Color(0xFF9E9D96),
          textTertiary: Color(0xFF76756F),
          textFaint: Color(0xFF4C4B47),
          border: Color(0xFF3B3C35),
          borderLight: Color(0xFF2D2E27),
          accent: Color(0xFF8F9E7C),
          accentMuted: Color(0x668F9E7C),
          accentFaint: Color(0x1A8F9E7C),
          success: Color(0xFF2A8A5A),
          error: Color(0xFFBF3030),
          hairline: Color(0x1AECEBE6),
          atmosphericGlow: Color(0x148F9E7C),
        );
      case ThemeType.chocolateTruffle:
        return const ResolvedColors(
          bg: Color(0xFF1C1412),
          surface: Color(0xFF271D1A),
          surfaceElevated: Color(0xFF332723),
          text: Color(0xFFF2ECE9),
          textSecondary: Color(0xFFBFB2AD),
          textTertiary: Color(0xFF8F807B),
          textFaint: Color(0xFF5E504C),
          border: Color(0xFF3D302C),
          borderLight: Color(0xFF2D201C),
          accent: Color(0xFFC0A080),
          accentMuted: Color(0x66C0A080),
          accentFaint: Color(0x1AC0A080),
          success: Color(0xFF2A8A5A),
          error: Color(0xFFBF3030),
          hairline: Color(0x1AF2ECE9),
          atmosphericGlow: Color(0x14C0A080),
        );
      case ThemeType.wisteriaBloom:
        return const ResolvedColors(
          bg: Color(0xFF181524),
          surface: Color(0xFF221E33),
          surfaceElevated: Color(0xFF2E2A44),
          text: Color(0xFFECEAF0),
          textSecondary: Color(0xFFACA5BD),
          textTertiary: Color(0xFF7E7694),
          textFaint: Color(0xFF504966),
          border: Color(0xFF332E4D),
          borderLight: Color(0xFF25213B),
          accent: Color(0xFFB39DDB),
          accentMuted: Color(0x66B39DDB),
          accentFaint: Color(0x1AB39DDB),
          success: Color(0xFF2A8A5A),
          error: Color(0xFFBF3030),
          hairline: Color(0x1AECEAF0),
          atmosphericGlow: Color(0x14B39DDB),
        );
      case ThemeType.defaultLight:
        return const ResolvedColors._dark();
    }
  }

  const ResolvedColors._dark()
      : bg = _DarkPalette.bg,
        surface = _DarkPalette.surface,
        surfaceElevated = _DarkPalette.surfaceElevated,
        text = _DarkPalette.text,
        textSecondary = _DarkPalette.textSecondary,
        textTertiary = _DarkPalette.textTertiary,
        textFaint = _DarkPalette.textFaint,
        border = _DarkPalette.border,
        borderLight = _DarkPalette.borderLight,
        accent = _DarkPalette.accent,
        accentMuted = _DarkPalette.accentMuted,
        accentFaint = _DarkPalette.accentFaint,
        success = _DarkPalette.success,
        error = _DarkPalette.error,
        hairline = const Color(0x1AF2F0EB), // warm ivory at 10% opacity
        atmosphericGlow = const Color(0x14D0B08A); // warm gold at 8% opacity

  const ResolvedColors._light()
      : bg = _LightPalette.bg,
        surface = _LightPalette.surface,
        surfaceElevated = _LightPalette.surfaceElevated,
        text = _LightPalette.text,
        textSecondary = _LightPalette.textSecondary,
        textTertiary = _LightPalette.textTertiary,
        textFaint = _LightPalette.textFaint,
        border = _LightPalette.border,
        borderLight = _LightPalette.borderLight,
        accent = _LightPalette.accent,
        accentMuted = _LightPalette.accentMuted,
        accentFaint = _LightPalette.accentFaint,
        success = _LightPalette.success,
        error = _LightPalette.error,
        hairline = const Color(0x1A2A2520), // warm charcoal at 10% opacity
        atmosphericGlow = const Color(0x149B7A4A); // deep gold at 8% opacity
}

// ─── Typography Token Architecture ───────────────────────────
//
// P3 requirement: font selection propagates across all surfaces.
// Use AppType.of(context) to get context-aware styles.
// Cormorant Garamond: emotional/editorial moments only.
// Inter: UI chrome, labels, metadata.
// User-selected body font: journal reading + editor.
//
class AppType {
  AppType._();

  // ── Static constants (dark theme fallback) ──
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w600,
    color: _DarkPalette.text, letterSpacing: -0.5, height: 1.2,
  );
  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600,
    color: _DarkPalette.text, letterSpacing: -0.3, height: 1.3,
  );
  static const TextStyle title = TextStyle(
    fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w500,
    color: _DarkPalette.text, letterSpacing: -0.2, height: 1.4,
  );
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400,
    color: _DarkPalette.text, height: 1.5,
  );
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400,
    color: _DarkPalette.textSecondary, height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
    color: _DarkPalette.textSecondary, height: 1.4,
  );
  static const TextStyle captionFaint = TextStyle(
    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
    color: _DarkPalette.textTertiary, height: 1.4,
  );
  static const TextStyle small = TextStyle(
    fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500,
    color: _DarkPalette.textTertiary, letterSpacing: 0.3, height: 1.3,
  );
  static const TextStyle label = TextStyle(
    fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600,
    color: _DarkPalette.textTertiary, letterSpacing: 0.8, height: 1.2,
  );

  // ── Editorial / emotional moments — Cormorant Garamond ──
  // Used in: editor reading view, hero cards, splash quotes.
  // NOT used globally. Not in settings chrome. Not in UI labels.
  static const TextStyle readingTitle = TextStyle(
    fontFamily: 'Cormorant Garamond', fontSize: 24, fontWeight: FontWeight.w600,
    color: _DarkPalette.text, letterSpacing: -0.3, height: 1.3,
  );
  static const TextStyle readingBody = TextStyle(
    fontFamily: 'Cormorant Garamond', fontSize: 18, fontWeight: FontWeight.w400,
    color: _DarkPalette.text, height: 1.7, letterSpacing: 0.1,
  );
  static const TextStyle readingBodySecondary = TextStyle(
    fontFamily: 'Cormorant Garamond', fontSize: 18, fontWeight: FontWeight.w400,
    color: _DarkPalette.textSecondary, height: 1.7, letterSpacing: 0.1,
  );

  // ── Context-aware typography (respects theme + user font) ──
  static ResolvedType of(BuildContext context, {String? fontOverride}) {
    final brightness = Theme.of(context).brightness;
    final colors = brightness == Brightness.dark
        ? const ResolvedColors._dark()
        : const ResolvedColors._light();
    String userFont = fontOverride ?? 'Inter';
    if (fontOverride == null) {
      try {
        final prefs = Provider.of<PreferencesState>(context, listen: true);
        userFont = prefs.selectedFont;
      } catch (_) {}
    }
    return ResolvedType(colors: colors, userFont: userFont);
  }
}

class ResolvedType {
  final ResolvedColors colors;
  final String userFont;

  const ResolvedType({required this.colors, required this.userFont});

  TextStyle get displayLarge => TextStyle(
        fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w600,
        color: colors.text, letterSpacing: -0.5, height: 1.2);

  TextStyle get displayMedium => TextStyle(
        fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600,
        color: colors.text, letterSpacing: -0.3, height: 1.3);

  TextStyle get title => TextStyle(
        fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w500,
        color: colors.text, letterSpacing: -0.2, height: 1.4);

  TextStyle get body => TextStyle(
        fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400,
        color: colors.text, height: 1.5);

  TextStyle get bodySecondary => TextStyle(
        fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400,
        color: colors.textSecondary, height: 1.5);

  TextStyle get caption => TextStyle(
        fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
        color: colors.textSecondary, height: 1.4);

  TextStyle get captionFaint => TextStyle(
        fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
        color: colors.textTertiary, height: 1.4);

  TextStyle get small => TextStyle(
        fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500,
        color: colors.textTertiary, letterSpacing: 0.3, height: 1.3);

  TextStyle get label => TextStyle(
        fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600,
        color: colors.textTertiary, letterSpacing: 0.8, height: 1.2);

  // Reading: uses user-selected font (Playfair Display, Caveat, or Inter)
  // Cormorant Garamond reserved for editorial titles only
  TextStyle get readingTitle => TextStyle(
        fontFamily: 'Cormorant Garamond', fontSize: 24, fontWeight: FontWeight.w600,
        color: colors.text, letterSpacing: -0.3, height: 1.3);

  TextStyle get readingBody => GoogleFonts.getFont(
        userFont,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: colors.text,
        height: 1.7,
        letterSpacing: 0.1,
      );

  TextStyle get readingBodySecondary => GoogleFonts.getFont(
        userFont,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.7,
        letterSpacing: 0.1,
      );
}

// ─── Transitions ──────────────────────────────────────────────
class AppTransitions {
  AppTransitions._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  static const Duration micro = Duration(milliseconds: 200);
  static const Duration short = Duration(milliseconds: 300);
  static const Duration medium = Duration(milliseconds: 450);
  static const Duration long = Duration(milliseconds: 600);

  static PageRouteBuilder<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curve = const Cubic(0.16, 1.0, 0.3, 1.0); // easeOutExpo
        final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

        final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(curvedAnimation);
        final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
        final blurAnimation = Tween<double>(begin: 8.0, end: 0.0).animate(curvedAnimation);

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, childWidget) {
            final blurVal = blurAnimation.value;
            Widget container = childWidget!;
            if (blurVal > 0.05) {
              container = ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
                child: container,
              );
            }
            return Opacity(
              opacity: opacityAnimation.value,
              child: Transform.scale(
                scale: scaleAnimation.value,
                child: container,
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 400),
    );
  }

  static PageRouteBuilder<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final curved = CurvedAnimation(parent: a, curve: standard);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      transitionDuration: long,
    );
  }
}

// ─── Surface Widget ───────────────────────────────────────────
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final bool bordered;

  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 20,
    this.color,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: c.border, width: 1) : null,
      ),
      child: child,
    );
  }
}

// ─── Layout Tokens ────────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double pill = 100.0;
  static const double card = 20.0;
  static const double button = 12.0;
  static const double input = 12.0;
  static const double small = 8.0;
  static const double chip = 16.0;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

// AppShadows: subtle depth for Liquid Glass surfaces
class AppShadows {
  AppShadows._();

  /// Subtle depth — for glass cards, entry items
  static List<BoxShadow> subtle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
        blurRadius: 12,
        offset: const Offset(0, 3),
        spreadRadius: -2,
      ),
    ];
  }

  /// Elevated depth — for floating panels, modals
  static List<BoxShadow> elevated(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  // Legacy compatibility — empty lists for old call sites
  static const List<BoxShadow> sm = [];
  static const List<BoxShadow> md = [];
  static const List<BoxShadow> lg = [];
  static const List<BoxShadow> glow = [];
  static const List<BoxShadow> card = [];
}

// ─── Theme Builders ───────────────────────────────────────────

ThemeData _buildTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final bg = isDark ? _DarkPalette.bg : _LightPalette.bg;
  final surface = isDark ? _DarkPalette.surface : _LightPalette.surface;
  final text = isDark ? _DarkPalette.text : _LightPalette.text;
  final accent = isDark ? _DarkPalette.accent : _LightPalette.accent;
  final border = isDark ? _DarkPalette.border : _LightPalette.border;
  final accentMuted = isDark ? _DarkPalette.accentMuted : _LightPalette.accentMuted;
  final textSecondary = isDark ? _DarkPalette.textSecondary : _LightPalette.textSecondary;
  final textTertiary = isDark ? _DarkPalette.textTertiary : _LightPalette.textTertiary;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isDark ? _DarkPalette.bg : Colors.white,
      secondary: accent,
      onSecondary: isDark ? _DarkPalette.bg : Colors.white,
      error: isDark ? _DarkPalette.error : _LightPalette.error,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    ),
    cardColor: surface,
    dividerColor: border,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: text),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? accent : textTertiary),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? accentMuted : border),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: surface,
      contentTextStyle: TextStyle(color: text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentMuted, width: 1.5),
      ),
      hintStyle: TextStyle(color: textTertiary),
      labelStyle: TextStyle(color: textSecondary),
    ),
    textTheme: TextTheme(
      headlineLarge:
          TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: text),
      headlineMedium:
          TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: text),
      titleLarge:
          TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: text),
      titleMedium:
          TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: text),
      bodyLarge:
          TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: text),
      bodyMedium: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w400, color: textSecondary),
      bodySmall: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w400, color: textTertiary),
      labelLarge:
          TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: text),
      labelSmall: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w500, color: textTertiary),
    ),
  );
}

class AppTheme {
  AppTheme._();

  // Real light mode — warm ivory paper, charcoal typography
  static ThemeData light() => _buildTheme(brightness: Brightness.light);

  // Dark mode — warm charcoal
  static ThemeData dark() => _buildTheme(brightness: Brightness.dark);
}
