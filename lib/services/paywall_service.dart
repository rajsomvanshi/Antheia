import 'package:flutter/material.dart';
import '../state/preferences_state.dart';

enum ProFeature {
  unlimitedEntries,
  voiceUnlimited,
  cloudSync,
  unlimitedMedia,
  mapView,
  calendarFull,
  narration,
  export,
  themes,
}

class PaywallService extends ChangeNotifier {
  final PreferencesState _prefs;
  int _entryCount = 0;
  int _photoCount = 0;

  static const _freeEntryLimit = 30;
  static const _freePhotoLimit = 5;
  static const _freeVoiceSeconds = 120;

  PaywallService({required PreferencesState prefs}) : _prefs = prefs {
    _prefs.addListener(_onPrefsChanged);
  }

  void _onPrefsChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefsChanged);
    super.dispose();
  }

  bool get isPro => _prefs.isPremium;

  Future<void> activatePro() async {
    _prefs.setPremium(true);
  }

  void syncCounts(int entries, int photos) {
    if (_entryCount != entries || _photoCount != photos) {
      _entryCount = entries;
      _photoCount = photos;
    }
  }

  // Returns null if allowed, returns the blocking feature if gated
  ProFeature? checkGate(ProFeature feature) {
    if (isPro) return null;
    return switch (feature) {
      ProFeature.unlimitedEntries =>
          _entryCount >= _freeEntryLimit ? feature : null,
      ProFeature.unlimitedMedia =>
          _photoCount >= _freePhotoLimit ? feature : null,
      ProFeature.cloudSync       => null,
      ProFeature.mapView         => null,
      ProFeature.narration       => feature,
      ProFeature.export          => feature,
      ProFeature.themes          => feature,
      ProFeature.voiceUnlimited  => null, // Checked separately by duration
      ProFeature.calendarFull    => feature, // Basic calendar is free (dots only), full details is gated
    };
  }

  int get freeVoiceSeconds => _freeVoiceSeconds;
  int get remainingFreeEntries => (_freeEntryLimit - _entryCount).clamp(0, _freeEntryLimit);
  int get remainingFreePhotos => (_freePhotoLimit - _photoCount).clamp(0, _freePhotoLimit);
}
