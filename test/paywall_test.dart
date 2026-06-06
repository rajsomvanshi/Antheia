import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antheia/state/preferences_state.dart';
import 'package:antheia/services/paywall_service.dart';

void main() {
  group('PaywallService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is not premium and checks standard gates', () async {
      final prefs = PreferencesState();
      await prefs.loadPreferences();
      final paywall = PaywallService(prefs: prefs);

      expect(paywall.isPro, isFalse);
      expect(paywall.checkGate(ProFeature.mapView), isNull);
      expect(paywall.checkGate(ProFeature.narration), ProFeature.narration);
      expect(paywall.checkGate(ProFeature.cloudSync), isNull);
      expect(paywall.checkGate(ProFeature.export), ProFeature.export);
      expect(paywall.checkGate(ProFeature.themes), ProFeature.themes);
      expect(paywall.checkGate(ProFeature.calendarFull), ProFeature.calendarFull);
    });

    test('enforces entry limits for free tier', () async {
      final prefs = PreferencesState();
      await prefs.loadPreferences();
      final paywall = PaywallService(prefs: prefs);

      // Under the 30 entries limit
      paywall.syncCounts(29, 0);
      expect(paywall.checkGate(ProFeature.unlimitedEntries), isNull);
      expect(paywall.remainingFreeEntries, 1);

      // Reaching the 30 entries limit
      paywall.syncCounts(30, 0);
      expect(paywall.checkGate(ProFeature.unlimitedEntries), ProFeature.unlimitedEntries);
      expect(paywall.remainingFreeEntries, 0);
    });

    test('enforces photo limits for free tier', () async {
      final prefs = PreferencesState();
      await prefs.loadPreferences();
      final paywall = PaywallService(prefs: prefs);

      // Under the 5 photos limit
      paywall.syncCounts(0, 4);
      expect(paywall.checkGate(ProFeature.unlimitedMedia), isNull);
      expect(paywall.remainingFreePhotos, 1);

      // Reaching the 5 photos limit
      paywall.syncCounts(0, 5);
      expect(paywall.checkGate(ProFeature.unlimitedMedia), ProFeature.unlimitedMedia);
      expect(paywall.remainingFreePhotos, 0);
    });

    test('pro status unlocks all gates regardless of counts', () async {
      final prefs = PreferencesState();
      await prefs.loadPreferences();
      final paywall = PaywallService(prefs: prefs);

      // Set counts past the limit
      paywall.syncCounts(45, 10);

      // Upgrade to Pro
      await paywall.activatePro();

      expect(paywall.isPro, isTrue);
      expect(paywall.checkGate(ProFeature.mapView), isNull);
      expect(paywall.checkGate(ProFeature.narration), isNull);
      expect(paywall.checkGate(ProFeature.unlimitedEntries), isNull);
      expect(paywall.checkGate(ProFeature.unlimitedMedia), isNull);
    });
  });
}
