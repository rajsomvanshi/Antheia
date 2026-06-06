import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

// ═══════════════════════════════════════════════════════════════
// BiometricService — Fingerprint / Face ID authentication
// ═══════════════════════════════════════════════════════════════

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  // ── Check availability ────────────────────────────────────────
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canAuthenticate = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticate && isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  Future<bool> hasFaceId() async {
    final biometrics = await availableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  Future<bool> hasFingerprint() async {
    final biometrics = await availableBiometrics();
    return biometrics.contains(BiometricType.fingerprint) ||
        biometrics.contains(BiometricType.strong);
  }

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      debugPrint('Device support check failed: $e');
      return false;
    }
  }

  // ── Authenticate ──────────────────────────────────────────────
  Future<BiometricResult> authenticate({
    String reason = 'Authenticate to unlock Antheia',
  }) async {
    final available = await isAvailable();
    final supported = await isDeviceSupported();
    
    if (!available && !supported) {
      return BiometricResult.unavailable;
    }

    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern fallback
        ),
      );
      return success ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        // If device supports PIN/passcode fallback, let local_auth handle it.
        // But if not, return unavailable.
        if (supported) {
          try {
            final success = await _auth.authenticate(
              localizedReason: reason,
              options: const AuthenticationOptions(
                stickyAuth: true,
                biometricOnly: false,
              ),
            );
            return success ? BiometricResult.success : BiometricResult.failed;
          } catch (_) {}
        }
        return BiometricResult.unavailable;
      }
      return BiometricResult.failed;
    }
  }

  // ── Stop ongoing auth ─────────────────────────────────────────
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}

enum BiometricResult {
  success,
  failed,
  unavailable,
}
