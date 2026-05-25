import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/journal_processing_service.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
// FlowJournal App State (ChangeNotifier)
// ═══════════════════════════════════════════════════════════════

class AppState extends ChangeNotifier {
  // ─── User Profile ───
  String _userName = 'User';
  String get userName => _userName;
  void setUserName(String name) {
    _userName = name;
    _savePreferences();
    notifyListeners();
  }

  // ─── Theme ───
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeType _activeThemeType = ThemeType.defaultLight;
  ThemeType get activeThemeType => _activeThemeType;

  void setThemeType(ThemeType type) {
    if (_activeThemeType == type) return;
    _activeThemeType = type;
    AppColors.applyTheme(type);
    _savePreferences();
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
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
    notifyListeners();
  }

  void completeOnboarding() {
    _hasCompletedOnboarding = true;
    _savePreferences();
    notifyListeners();
  }

  // ─── Premium / RevenueCat ───
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  void setPremium(bool value) {
    if (_isPremium == value) return;
    _isPremium = value;
    _savePreferences();
    notifyListeners();
  }

  // ─── Preferences persistence ───
  bool _preferencesLoaded = false;
  bool get preferencesLoaded => _preferencesLoaded;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('userName') ?? 'User';
    _hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
    _isPremium = prefs.getBool('isPremium') ?? false;
    final themeIndex = prefs.getInt('activeThemeType') ?? 0;
    if (themeIndex >= 0 && themeIndex < ThemeType.values.length) {
      _activeThemeType = ThemeType.values[themeIndex];
      AppColors.applyTheme(_activeThemeType);
    }
    _preferencesLoaded = true;
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _userName);
    await prefs.setBool('hasCompletedOnboarding', _hasCompletedOnboarding);
    await prefs.setBool('isPremium', _isPremium);
    await prefs.setInt('activeThemeType', _activeThemeType.index);
  }

  // ─── Navigation ───
  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  // ─── Entries ───
  List<JournalEntry> _entries = [];
  List<JournalEntry> get entries => List.unmodifiable(_entries);

  // FIX: null-safe entry access — never crashes when list is empty
  JournalEntry? _currentEntry;
  JournalEntry? get currentEntry => _currentEntry;

  /// Safe getter: returns currentEntry, first entry, or null — never throws
  JournalEntry? get safeCurrentEntry =>
      _currentEntry ?? (_entries.isNotEmpty ? _entries.first : null);

  Future<void> loadEntries() async {
    _entries = await DatabaseService().loadEntries();
    notifyListeners();
  }

  void setCurrentEntry(JournalEntry? entry) {
    _currentEntry = entry;
    notifyListeners();
  }

  /// Computed getters for the new premium UI
  int get mediaCount =>
      _entries.fold(0, (sum, e) => sum + e.photoUrls.length);
  int get voiceEntryCount =>
      _entries.where((e) => e.isVoiceEntry).length;
  DateTime? get journalStartDate =>
      _entries.isEmpty ? null : _entries.reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b).createdAt;
  int get uniqueDaysJournaled =>
      _entries.map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day).toIso8601String()).toSet().length;

  Future<void> addEntry(JournalEntry entry) async {
    _entries.insert(0, entry);
    notifyListeners();
    await DatabaseService().insertEntry(entry);
  }

  Future<void> updateEntry(JournalEntry entry) async {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      _entries[idx] = entry;
    }
    if (_currentEntry?.id == entry.id) {
      _currentEntry = entry;
    }
    notifyListeners();
    await DatabaseService().updateEntry(entry);
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    if (_currentEntry?.id == id) {
      _currentEntry = null;
    }
    notifyListeners();
    await DatabaseService().deleteEntry(id);
  }

  // ─── Recording ───
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  void setRecording(bool value) {
    _isRecording = value;
    notifyListeners();
  }

  // ─── Processing ───
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  double _processingProgress = 0.0;
  double get processingProgress => _processingProgress;
  String _processingStep = '';
  String get processingStep => _processingStep;
  String? _processingError;
  String? get processingError => _processingError;

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  /// Full AI processing pipeline using cascading API fallbacks.
  Future<JournalEntry?> processVoiceEntry({
    required String rawText,
    double? latitude,
    double? longitude,
    int durationMinutes = 0,
  }) async {
    _isProcessing = true;
    _processingProgress = 0.0;
    _processingStep = 'Starting…';
    _processingError = null;
    notifyListeners();

    final service = ProcessingService();
    service.onProgress = (progress, step) {
      _processingProgress = progress;
      _processingStep = step;
      notifyListeners();
    };

    try {
      final entry = await service.processEntry(
        rawText: rawText,
        latitude: latitude,
        longitude: longitude,
      );

      // Store GPS as 'lat,lon' string so map screen can parse it
      final locationString = (latitude != null && longitude != null)
          ? '$latitude,$longitude'
          : entry.location;

      final finalEntry = JournalEntry(
        id: entry.id,
        title: entry.title,
        content: entry.content,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        mood: entry.mood,
        location: locationString,
        temperature: entry.temperature,
        weatherIcon: entry.weatherIcon,
        tags: entry.tags,
        durationMinutes: durationMinutes,
        isVoiceEntry: true,
        sections: entry.sections,
      );

      await addEntry(finalEntry);
      setCurrentEntry(finalEntry);

      _isProcessing = false;
      notifyListeners();
      return finalEntry;
    } catch (e) {
      _processingError = e.toString();
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Settings ───
  String _aiPersonality = 'Supportive Friend';
  String get aiPersonality => _aiPersonality;
  void setAiPersonality(String value) {
    _aiPersonality = value;
    notifyListeners();
  }

  String _autoFormatting = 'Medium';
  String get autoFormatting => _autoFormatting;
  void setAutoFormatting(String value) {
    _autoFormatting = value;
    notifyListeners();
  }

  bool _biometricLock = false;
  bool get biometricLock => _biometricLock;
  void toggleBiometricLock() {
    _biometricLock = !_biometricLock;
    notifyListeners();
  }

  bool _cloudBackup = false;
  bool get cloudBackup => _cloudBackup;
  void toggleCloudBackup() {
    _cloudBackup = !_cloudBackup;
    notifyListeners();
  }

  bool _strictLocalMode = false;
  bool get strictLocalMode => _strictLocalMode;
  void toggleStrictLocalMode() {
    _strictLocalMode = !_strictLocalMode;
    notifyListeners();
  }

  bool _e2eEncryption = true;
  bool get e2eEncryption => _e2eEncryption;
  void toggleE2eEncryption() {
    _e2eEncryption = !_e2eEncryption;
    notifyListeners();
  }

  // ─── TTS Companion Voice Settings ───
  String _ttsVoice = 'English Female';
  String get ttsVoice => _ttsVoice;
  void setTtsVoice(String value) {
    _ttsVoice = value;
    notifyListeners();
  }

  double _ttsPitch = 1.0;
  double get ttsPitch => _ttsPitch;
  void setTtsPitch(double value) {
    _ttsPitch = value;
    notifyListeners();
  }

  double _ttsSpeed = 0.9;
  double get ttsSpeed => _ttsSpeed;
  void setTtsSpeed(double value) {
    _ttsSpeed = value;
    notifyListeners();
  }

  // ─── Offline Sync State ───
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  // ─── Streak ───
  int get currentStreak {
    if (_entries.isEmpty) return 0;
    int streak = 0;
    DateTime check = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final day = DateTime(check.year, check.month, check.day)
          .subtract(Duration(days: i));
      final hasEntry = _entries.any((e) =>
          e.createdAt.year == day.year &&
          e.createdAt.month == day.month &&
          e.createdAt.day == day.day);
      if (hasEntry) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  int get bestStreak => 7;

  // ─── People ───
  List<PersonMention> get people => const [
        PersonMention(
            name: 'Rahul',
            initial: 'R',
            entryCount: 8,
            emotionalScore: 4.2,
            emotionalIcon: Icons.auto_awesome_rounded),
        PersonMention(
            name: 'Priya',
            initial: 'P',
            entryCount: 5,
            emotionalScore: 3.8,
            emotionalIcon: Icons.auto_awesome_rounded),
        PersonMention(
            name: 'Mom',
            initial: 'M',
            entryCount: 6,
            emotionalScore: 2.1,
            emotionalIcon: Icons.favorite_rounded),
        PersonMention(
            name: 'Arjun',
            initial: 'A',
            entryCount: 3,
            emotionalScore: 3.5,
            emotionalIcon: Icons.celebration_rounded),
      ];

  // ─── Locations ───
  List<LocationMemory> get locations => const [
        LocationMemory(
            name: 'Campus',
            icon: Icons.school_rounded,
            entryCount: 12,
            latestEntry: 'A Strange Nostalgic Day',
            latitude: 28.6139,
            longitude: 77.2090),
        LocationMemory(
            name: 'City Café',
            icon: Icons.local_cafe_rounded,
            entryCount: 5,
            latestEntry: 'Coffee & Conversations',
            latitude: 28.6225,
            longitude: 77.2195),
        LocationMemory(
            name: 'Central Library',
            icon: Icons.menu_book_rounded,
            entryCount: 7,
            latestEntry: 'Found an old poem',
            latitude: 28.6180,
            longitude: 77.2150),
        LocationMemory(
            name: 'Home',
            icon: Icons.home_rounded,
            entryCount: 14,
            latestEntry: 'Rainy Afternoon',
            latitude: 28.6100,
            longitude: 77.2050),
        LocationMemory(
            name: 'City Park',
            icon: Icons.park_rounded,
            entryCount: 4,
            latestEntry: 'Sunday morning run',
            latitude: 28.6250,
            longitude: 77.2120),
      ];
}
