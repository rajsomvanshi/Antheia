import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
// Preferences State — Phase 3
//
// Phase 3 changes:
//   • themeMode now drives real MaterialApp themeMode
//   • animationIntensity maps to AnimationIntensity enum
//   • biometricLock kept: wired to BiometricService
//   • autoFormatting kept: read by ReflectionPipeline
//   • selectedFont kept: read by AppType.of(context)
//   • Added compatibility shims to support existing settings rows
// ═══════════════════════════════════════════════════════════════

class PreferencesState extends ChangeNotifier {
  bool _preferencesLoaded = false;
  bool get preferencesLoaded => _preferencesLoaded;

  int _aiLinkViews = 0;
  int get aiLinkViews => _aiLinkViews;
  void incrementAiLinkViews() {
    _aiLinkViews++;
    unawaited(_save());
    notifyListeners();
  }

  int _premiumThemesApplied = 0;
  int get premiumThemesApplied => _premiumThemesApplied;
  void incrementPremiumThemesApplied() {
    _premiumThemesApplied++;
    unawaited(_save());
    notifyListeners();
  }

  // ─── User Profile ───
  String _userName = '';
  String get userName => _userName;
  void setUserName(String name) {
    _userName = name;
    unawaited(_save());
    notifyListeners();
  }

  // ─── Theme — REAL ──────────────────────────────────────────
  // This now drives the MaterialApp themeMode in main.dart.
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    unawaited(_save());
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    unawaited(_save());
    notifyListeners();
  }

  // Legacy compatibility (ThemeType still used in model layer)
  ThemeType _activeThemeType = ThemeType.defaultLight;
  ThemeType get activeThemeType => _activeThemeType;
  void setThemeType(ThemeType type) {
    _activeThemeType = type;
    unawaited(_save());
    notifyListeners();
  }

  // ─── Animation Intensity — REAL ────────────────────────────
  // Mapped to AnimationIntensity enum, exposed via AnimationScale
  // InheritedWidget in main.dart.
  AnimationIntensity _animationIntensity = AnimationIntensity.full;
  AnimationIntensity get animationIntensity => _animationIntensity;

  // String getter for settings UI pills
  String get animationIntensityLabel {
    switch (_animationIntensity) {
      case AnimationIntensity.stillness:
        return 'None';
      case AnimationIntensity.reduced:
        return 'Subtle';
      case AnimationIntensity.full:
        return 'Full';
    }
  }

  void setAnimationIntensity(String label) {
    switch (label) {
      case 'None':
      case 'Reduced':
      case 'Stillness':
        _animationIntensity = AnimationIntensity.stillness;
      case 'Subtle':
      case 'Normal':
        _animationIntensity = AnimationIntensity.reduced;
      case 'Full':
      case 'Fluid':
      default:
        _animationIntensity = AnimationIntensity.full;
    }
    unawaited(_save());
    notifyListeners();
  }

  // ─── Typography — REAL ─────────────────────────────────────
  // Read by AppType.of(context) to resolve reading font family.
  // Cormorant Garamond is always used for editorial titles (not user-selectable).
  // This controls the body/reading font only.
  String _selectedFont = 'Inter';
  String get selectedFont => _selectedFont;
  void setSelectedFont(String value) {
    _selectedFont = value;
    unawaited(_save());
    notifyListeners();
  }

  // ─── Onboarding ───
  bool _hasCompletedOnboarding = false;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  int _onboardingPage = 0;
  int get onboardingPage => _onboardingPage;

  PersonalityStyle? _selectedPersonality;
  PersonalityStyle? get selectedPersonality => _selectedPersonality;

  void setOnboardingPage(int page) {
    _onboardingPage = page;
    notifyListeners();
  }

  void selectPersonality(PersonalityStyle style) {
    _selectedPersonality = style;
    switch (style) {
      case PersonalityStyle.calm:
        _reflectionTone = 'Thoughtful';
        break;
      case PersonalityStyle.energetic:
        _reflectionTone = 'Direct';
        break;
      case PersonalityStyle.nostalgic:
        _reflectionTone = 'Lyrical';
        break;
      case PersonalityStyle.minimal:
        _reflectionTone = 'Direct';
        break;
      case PersonalityStyle.creative:
        _reflectionTone = 'Lyrical';
        break;
      case PersonalityStyle.romantic:
        _reflectionTone = 'Lyrical';
        break;
    }
    unawaited(_save());
    notifyListeners();
  }

  void completeOnboarding() {
    _hasCompletedOnboarding = true;
    unawaited(_save());
    notifyListeners();
  }

  // ─── Premium ───
  bool _isPremium = false;
  bool get isPremium => _isPremium;
  void setPremium(bool value) {
    if (_isPremium == value) return;
    _isPremium = value;
    unawaited(_save());
    notifyListeners();
  }

  // ─── Reflection tone — REAL ────────────────────────────────
  // Read by ReflectionPipeline to tune reflection tone.
  String _reflectionTone = 'Thoughtful';
  String get reflectionTone => _reflectionTone;
  void setReflectionTone(String value) {
    _reflectionTone = value;
    unawaited(_save());
    notifyListeners();
  }

  // ─── Auto-formatting — REAL ────────────────────────────────
  // Read by MemoryEnrichmentService to control restructure depth.
  String _autoFormatting = 'Medium';
  String get autoFormatting => _autoFormatting;
  void setAutoFormatting(String value) {
    _autoFormatting = value;
    unawaited(_save());
    notifyListeners();
  }

  // ─── Biometric lock — REAL ────────────────────────────────
  // Wired to BiometricService in SplashScreen/AppOrchestrator.
  bool _biometricLock = false;
  bool get biometricLock => _biometricLock;
  void toggleBiometricLock() {
    _biometricLock = !_biometricLock;
    unawaited(_save());
    notifyListeners();
  }

  // ─── Compatibility Shims for Legacy Settings Rows ───
  String get aiPersonality => _reflectionTone;
  void setAiPersonality(String value) => setReflectionTone(value);
  bool get cloudBackup => false;
  bool get strictLocalMode => false;
  bool get e2eEncryption => true;
  String get ttsVoice => 'System voice';
  double get ttsPitch => 1.0;
  double get ttsSpeed => 1.0;
  String get voiceSensitivity => 'Normal';
  void toggleCloudBackup() {}
  void toggleStrictLocalMode() {}
  void toggleE2eEncryption() {}
  void setTtsVoice(String value) {}
  void setTtsPitch(double value) {}
  void setTtsSpeed(double value) {}
  void setVoiceSensitivity(String value) {}

  // ─── Persist ───
  Future<void> loadPreferences() async {
    final p = await SharedPreferences.getInstance();

    _userName = p.getString('userName') ?? '';
    _hasCompletedOnboarding = p.getBool('hasCompletedOnboarding') ?? false;
    _isPremium = p.getBool('isPremium') ?? false;

    final themeIndex = p.getInt('activeThemeType') ?? 0;
    if (themeIndex >= 0 && themeIndex < ThemeType.values.length) {
      _activeThemeType = ThemeType.values[themeIndex];
    }

    final themeModeStr = p.getString('themeMode') ?? 'dark';
    _themeMode =
        themeModeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

    final intensityStr = p.getString('animationIntensity') ?? 'Full';
    switch (intensityStr) {
      case 'None':
      case 'Reduced':
      case 'Stillness':
        _animationIntensity = AnimationIntensity.stillness;
      case 'Subtle':
      case 'Normal':
        _animationIntensity = AnimationIntensity.reduced;
      case 'Full':
      case 'Fluid':
      default:
        _animationIntensity = AnimationIntensity.full;
    }

    _selectedFont = p.getString('selectedFont') ?? 'Inter';
    _reflectionTone = p.getString('reflectionTone') ?? 'Thoughtful';
    _autoFormatting = p.getString('autoFormatting') ?? 'Medium';
    _biometricLock = p.getBool('biometricLock') ?? false;
    _aiLinkViews = p.getInt('aiLinkViews') ?? 0;
    _premiumThemesApplied = p.getInt('premiumThemesApplied') ?? 0;

    final personalityStr = p.getString('selectedPersonality');
    if (personalityStr != null) {
      try {
        _selectedPersonality = PersonalityStyle.values.firstWhere((e) => e.name == personalityStr);
      } catch (_) {}
    }

    _preferencesLoaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('userName', _userName);
    await p.setBool('hasCompletedOnboarding', _hasCompletedOnboarding);
    await p.setBool('isPremium', _isPremium);
    await p.setInt('activeThemeType', _activeThemeType.index);
    await p.setString(
        'themeMode', _themeMode == ThemeMode.light ? 'light' : 'dark');
    await p.setString('animationIntensity', animationIntensityLabel);
    await p.setString('selectedFont', _selectedFont);
    await p.setString('reflectionTone', _reflectionTone);
    await p.setString('autoFormatting', _autoFormatting);
    await p.setBool('biometricLock', _biometricLock);
    await p.setInt('aiLinkViews', _aiLinkViews);
    await p.setInt('premiumThemesApplied', _premiumThemesApplied);
    if (_selectedPersonality != null) {
      await p.setString('selectedPersonality', _selectedPersonality!.name);
    } else {
      await p.remove('selectedPersonality');
    }
  }

  Future<void> resetOnboardingOnly() async {
    _hasCompletedOnboarding = false;
    notifyListeners();
    await _save();
  }

  Future<void> resetPreferences() async {
    _userName = '';
    _hasCompletedOnboarding = false;
    _isPremium = false;
    _activeThemeType = ThemeType.defaultLight;
    _themeMode = ThemeMode.dark;
    _animationIntensity = AnimationIntensity.full;
    _selectedFont = 'Inter';
    _reflectionTone = 'Thoughtful';
    _autoFormatting = 'Medium';
    _biometricLock = false;
    _aiLinkViews = 0;
    _premiumThemesApplied = 0;
    _selectedPersonality = null;
    final p = await SharedPreferences.getInstance();
    await p.clear();
    notifyListeners();
  }
}
