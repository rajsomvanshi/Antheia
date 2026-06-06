import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/biometric_state.dart';
import '../state/preferences_state.dart';
import '../screens/biometric_blocker_page.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';

// ═══════════════════════════════════════════════════════════════
// SecureAppWrapper — Defense-in-Depth Security Gate
//
// Architecture:
//   This widget wraps the entire MaterialApp navigator.
//   It is the single structural enforcement point for:
//   1. Privacy Curtain — hides content from task switcher
//   2. Biometric Lock — blocks all content when locked
//   3. Biometric-removed detection — warns if user removed
//      all biometrics from device while lock was enabled
//
//   A future developer cannot bypass this by adding a new route,
//   because it wraps the entire navigator tree, not individual
//   screens. The only way to break it is to remove it from
//   main.dart — which is immediately obvious in code review.
// ═══════════════════════════════════════════════════════════════

class SecureAppWrapper extends StatefulWidget {
  final Widget child;
  const SecureAppWrapper({super.key, required this.child});

  @override
  State<SecureAppWrapper> createState() => _SecureAppWrapperState();
}

class _SecureAppWrapperState extends State<SecureAppWrapper>
    with WidgetsBindingObserver {
  DateTime? _backgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prefs = context.read<PreferencesState>();
    final biometric = context.read<BiometricState>();
    final imagePickerInProgress = AuthService().isImagePickerInProgress;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // 1. Show Privacy Curtain immediately when app is backgrounded
      //    This fires BEFORE the OS takes the task switcher screenshot
      //    on iOS (inactive) and Android (paused).
      //    Don't show privacy curtain if image picker is open — it's a system sheet, not a privacy risk.
      if (!imagePickerInProgress) {
        biometric.setPrivacyCurtain(true);
      }
      
      // 2. Persist background time instead of locking immediately (30-second grace period)
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // 3. Check grace period limit before locking
      if (prefs.hasCompletedOnboarding && prefs.biometricLock && _backgroundTime != null) {
        final secondsBackgrounded = DateTime.now().difference(_backgroundTime!).inSeconds;
        final oauthInProgress = AuthService().isOAuthInProgress;
        if (secondsBackgrounded >= 30 && !oauthInProgress && !imagePickerInProgress) {
          biometric.lock();
        }
      }
      _backgroundTime = null; // Reset background state

      // 4. Remove privacy curtain when app returns
      biometric.setPrivacyCurtain(false);
      
      // 5. Check if biometrics were removed from device
      if (prefs.biometricLock) {
        _checkBiometricsStillEnrolled(biometric);
      }
      
      // 6. Trigger authentication prompt if locked
      if (biometric.isLocked) {
        biometric.authenticate();
      }
    }
  }

  /// Detect if the user removed all biometric profiles from their device
  /// while the app was in background. If so, flag it so the blocker page
  /// can show an appropriate warning instead of silently failing.
  Future<void> _checkBiometricsStillEnrolled(BiometricState biometric) async {
    try {
      final service = BiometricService();
      final available = await service.isAvailable();
      if (!available) {
        final enrolled = await service.availableBiometrics();
        if (enrolled.isEmpty) {
          biometric.setBiometricsRemoved(true);
        }
      }
    } catch (_) {
      // Non-critical check — don't block app resume
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometric = context.watch<BiometricState>();

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          // The actual application Navigator and routes
          widget.child,

          // Privacy Curtain: Rendered when backgrounded to prevent
          // recent apps task switcher screenshots leaking journal content
          if (biometric.isPrivacyCurtainActive)
            const _PrivacyCurtain(),

          // Hardened Biometric Lock Blocker Page: Rendered on top of
          // Navigator when locked — cannot be bypassed by any route
          if (biometric.isLocked && !biometric.isPrivacyCurtainActive)
            const BiometricBlockerPage(),
        ],
      ),
    );
  }
}

class _PrivacyCurtain extends StatelessWidget {
  const _PrivacyCurtain();

  @override
  Widget build(BuildContext context) {
    // Pure dark/warm background with no journal contents
    return Material(
      child: Container(
        color: const Color(0xFF100F0E), // Match AppColors.bg
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Antheia',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF2F0EB),
                  letterSpacing: 4.0,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Sanctuary is shielded',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0x5CF2F0EB),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
