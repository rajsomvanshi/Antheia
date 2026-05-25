import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// FlowJournal — Design System
// ═══════════════════════════════════════════════════════════════


enum ThemeType { defaultLight, earthyLuxury, chocolateTruffle, wisteriaBloom }

class AppColors {

  static void applyTheme(ThemeType type) {
    if (type == ThemeType.earthyLuxury) {
      accentPrimary = const Color(0xFF4A5D4E);
      accentSecondary = const Color(0xFF8B9A86);
      accentWarm = const Color(0xFFD4C9A8);
      accentSuccess = const Color(0xFF5F7A61);
      accentDanger = const Color(0xFFB85C4F);
      cyanAccent = const Color(0xFF8B9A86);
      cyanAccentLight = const Color(0xFFD4C9A8);
      cyanGlow = const Color(0x444A5D4E);
      bgPrimary = const Color(0xFFF4F1EB);
      bgSecondary = const Color(0xFFE3DEC6);
      surface = const Color(0xFFFCFBF8);
      surfaceElevated = const Color(0xFFFFFFFF);
      textPrimary = const Color(0xFF2C362F);
      textSecondary = const Color(0xFF707973);
      borderSubtle = const Color(0xFFE3DEC6);
    } else if (type == ThemeType.chocolateTruffle) {
      accentPrimary = const Color(0xFF3E2A21);
      accentSecondary = const Color(0xFF8A5A44);
      accentWarm = const Color(0xFFD4A373);
      accentSuccess = const Color(0xFF4A6B53);
      accentDanger = const Color(0xFF9D4A43);
      cyanAccent = const Color(0xFFD4A373);
      cyanAccentLight = const Color(0xFFF9F6F0);
      cyanGlow = const Color(0x443E2A21);
      bgPrimary = const Color(0xFFF9F6F0);
      bgSecondary = const Color(0xFFE6DED5);
      surface = const Color(0xFFFFFFFF);
      surfaceElevated = const Color(0xFFFDFBF7);
      textPrimary = const Color(0xFF2B1D16);
      textSecondary = const Color(0xFF7D685E);
      borderSubtle = const Color(0xFFE6DED5);
    } else if (type == ThemeType.wisteriaBloom) {
      accentPrimary = const Color(0xFF7B6B9E);
      accentSecondary = const Color(0xFFA89FCA);
      accentWarm = const Color(0xFFE5B8D9);
      accentSuccess = const Color(0xFF7A9EA3);
      accentDanger = const Color(0xFFD47A85);
      cyanAccent = const Color(0xFFA89FCA);
      cyanAccentLight = const Color(0xFFF8F7FA);
      cyanGlow = const Color(0x447B6B9E);
      bgPrimary = const Color(0xFFF8F7FA);
      bgSecondary = const Color(0xFFE8E4F2);
      surface = const Color(0xFFFFFFFF);
      surfaceElevated = const Color(0xFFFDFDFF);
      textPrimary = const Color(0xFF3A344A);
      textSecondary = const Color(0xFF857D96);
      borderSubtle = const Color(0xFFE8E4F2);
    } else {
      // Default
      accentPrimary = const Color(0xFF6C5CE7);
      accentSecondary = const Color(0xFF74B9FF);
      accentWarm = const Color(0xFFE17055);
      accentSuccess = const Color(0xFF00B894);
      accentDanger = const Color(0xFFD63031);
      cyanAccent = const Color(0xFF00B4D8);
      cyanAccentLight = const Color(0xFFE0F7FA);
      cyanGlow = const Color(0x4400B4D8);
      bgPrimary = const Color(0xFFFAF9F6);
      bgSecondary = const Color(0xFFF0EEE9);
      surface = const Color(0xFFFFFFFF);
      surfaceElevated = const Color(0xFFF5F3EF);
      textPrimary = const Color(0xFF2D3436);
      textSecondary = const Color(0xFF636E72);
      borderSubtle = const Color(0xFFDFE6E9);
    }
  }

  AppColors._();

  // ── Brand (purple family) ────────────────────────────
  static Color accentPrimary   = Color(0xFF6C5CE7); // purple
  static Color accentSecondary = Color(0xFF74B9FF); // sky blue
  static Color accentWarm      = Color(0xFFE17055); // coral
  static Color accentSuccess   = Color(0xFF00B894); // green
  static Color accentDanger    = Color(0xFFD63031); // red

  // ── NEW: Cyan accent for new UI ───────────────────────
  static Color cyanAccent      = Color(0xFF00B4D8); // calming cyan
  static Color cyanAccentLight = Color(0xFFE0F7FA); // light cyan bg
  static Color cyanGlow        = Color(0x4400B4D8); // cyan glow shadow

  // ── NEW: Glassmorphism ─────────────────────────────
  static Color glassSurface    = Color(0x1AFFFFFF); // white 10%
  static Color glassBorder     = Color(0x33FFFFFF); // white 20%
  static Color glassOverlay    = Color(0x80000000); // black 50%

  // ── NEW: Streak / special ───────────────────────────
  static Color streakBgStart       = Color(0xFFFFF9E6);
  static Color streakBgEnd         = Color(0xFFFFF3CD);
  static Color streakBorder        = Color(0xFFFFE082);
  static Color streakText          = Color(0xFF7B5800);
  static Color streakTextSecondary = Color(0xFF9A7200);

  // ── Light backgrounds ──────────────────────────────
  static Color bgPrimary       = Color(0xFFFAF9F6);
  static Color bgSecondary     = Color(0xFFF0EEE9);
  static Color surface         = Color(0xFFFFFFFF);
  static Color surfaceElevated = Color(0xFFF5F3EF);

  // ── Light text ─────────────────────────────────────
  static Color textPrimary   = Color(0xFF2D3436);
  static Color textSecondary = Color(0xFF636E72);

  // ── Light borders ────────────────────────────────
  static Color borderSubtle = Color(0xFFDFE6E9);

  // ── Dark backgrounds ──────────────────────────────
  static Color bgDark          = Color(0xFF1A1A2E);
  static Color bgDarkSecondary = Color(0xFF16213E);
  static Color surfaceDark     = Color(0xFF0F3460);
  static Color surfaceElevatedDark = Color(0xFF1E2A4A);

  // ── Dark text ────────────────────────────────────
  static Color textPrimaryDark   = Color(0xFFE8E8E8);
  static Color textSecondaryDark = Color(0xFFA0A8B8);

  // ── Dark borders ─────────────────────────────────
  static Color borderSubtleDark = Color(0xFF2A3A5C);
}

// ─── Border radii ─────────────────────────────────────────────

class AppRadius {
  AppRadius._();

  static const double pill   = 100.0;
  static const double card   = 16.0;
  static const double button = 14.0;
  static const double input  = 12.0;
  static const double small  = 8.0;
  static const double chip   = 20.0;
}

// ─── Spacing ──────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 20.0;
  static const double xl  = 24.0;
  static const double xxl = 32.0;
}

// ─── Shadows ──────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x406C5CE7),
      blurRadius: 20,
      spreadRadius: 2,
      offset: Offset(0, 4),
    ),
  ];

  // NEW: Cyan glow for new UI
  static const List<BoxShadow> cyanGlow = [
    BoxShadow(
      color: Color(0x5500B4D8),
      blurRadius: 20,
      spreadRadius: 4,
    ),
  ];

  // NEW: Card shadow for bento grid
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];
}

// ─── Material Theme ───────────────────────────────────────────

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    colorScheme: ColorScheme.light(
      primary: AppColors.accentPrimary,
      secondary: AppColors.accentSecondary,
      surface: AppColors.surface,
      error: AppColors.accentDanger,
    ),
    cardColor: AppColors.surface,
    dividerColor: AppColors.borderSubtle,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgSecondary,
      selectedColor: AppColors.accentPrimary,
      labelStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      side: BorderSide.none,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.accentPrimary : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.accentPrimary.withOpacity(0.4)
              : AppColors.borderSubtle),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accentPrimary,
      secondary: AppColors.accentSecondary,
      surface: AppColors.surfaceDark,
      error: AppColors.accentDanger,
    ),
    cardColor: AppColors.surfaceDark,
    dividerColor: AppColors.borderSubtleDark,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgDarkSecondary,
      selectedColor: AppColors.accentPrimary,
      labelStyle: TextStyle(color: AppColors.textPrimaryDark, fontSize: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      side: BorderSide.none,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.accentPrimary : AppColors.textSecondaryDark),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.accentPrimary.withOpacity(0.4)
              : AppColors.borderSubtleDark),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
    ),
  );
}
// ─── AppTheme wrapper class (used by main.dart) ───────────────

class AppTheme {
  AppTheme._();
  static ThemeData light() => buildLightTheme();
  static ThemeData dark() => buildDarkTheme();
}
