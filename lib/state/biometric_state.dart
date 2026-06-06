import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';
import 'preferences_state.dart';

enum BiometricLockStatus {
  unlocked,
  locked,
  authenticating,
  lockoutTemp,
  lockoutPerm,
  unavailable,
  unsupported,
  notEnrolled,
  biometricsRemoved,
}

class BiometricState extends ChangeNotifier {
  BiometricLockStatus _status = BiometricLockStatus.unlocked;
  BiometricLockStatus get status => _status;

  bool get isLocked => _status != BiometricLockStatus.unlocked;
  bool get isAuthenticating => _status == BiometricLockStatus.authenticating;

  int _failureCount = 0;
  int get failureCount => _failureCount;

  bool _showRecovery = false;
  bool get showRecovery => _showRecovery;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isPrivacyCurtainActive = false;
  bool get isPrivacyCurtainActive => _isPrivacyCurtainActive;

  bool _biometricsRemoved = false;
  bool get biometricsRemoved => _biometricsRemoved;

  void setBiometricsRemoved(bool removed) {
    _biometricsRemoved = removed;
    if (removed) {
      _status = BiometricLockStatus.biometricsRemoved;
      _showRecovery = true;
    }
    notifyListeners();
  }

  void setPrivacyCurtain(bool active) {
    if (_isPrivacyCurtainActive == active) return;
    _isPrivacyCurtainActive = active;
    notifyListeners();
  }

  void lock() {
    if (_status == BiometricLockStatus.unlocked) {
      _status = BiometricLockStatus.locked;
      _showRecovery = _failureCount >= 5;
      notifyListeners();
    }
  }

  void unlock() {
    _status = BiometricLockStatus.unlocked;
    _failureCount = 0;
    _showRecovery = false;
    _biometricsRemoved = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> authenticate() async {
    if (_status == BiometricLockStatus.unlocked) return;
    _status = BiometricLockStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final service = BiometricService();
      
      final available = await service.isAvailable();
      final supported = await service.isDeviceSupported();

      if (!available && !supported) {
        _status = BiometricLockStatus.unavailable;
        _errorMessage = 'Biometric sensors and device credentials are currently unavailable.';
        _failureCount++;
        if (_failureCount >= 5) _showRecovery = true;
        notifyListeners();
        return;
      }

      final result = await service.authenticate(
        reason: 'Unlock Antheia to access your memories.',
      );

      if (result == BiometricResult.success) {
        unlock();
      } else {
        _failureCount++;
        if (!available) {
          _status = BiometricLockStatus.biometricsRemoved;
          _errorMessage = 'Biometrics removed or unavailable. Use your device passcode to unlock.';
        } else {
          _status = BiometricLockStatus.locked;
          _errorMessage = 'Authentication failed. Please try again.';
        }
        if (_failureCount >= 5) {
          _showRecovery = true;
        }
        notifyListeners();
      }
    } on PlatformException catch (e) {
      _failureCount++;
      if (_failureCount >= 5) _showRecovery = true;

      final service = BiometricService();
      final available = await service.isAvailable();

      if (e.code == 'LockedOut') {
        _status = BiometricLockStatus.lockoutTemp;
        _errorMessage = 'Too many failed attempts. Biometrics temporarily locked.';
      } else if (e.code == 'PermanentlyLockedOut') {
        _status = BiometricLockStatus.lockoutPerm;
        _errorMessage = 'Biometrics permanently locked. Use device PIN/pattern.';
      } else {
        _status = !available ? BiometricLockStatus.biometricsRemoved : BiometricLockStatus.locked;
        _errorMessage = e.message ?? 'Authentication error occurred.';
      }
      notifyListeners();
    } catch (e) {
      _failureCount++;
      if (_failureCount >= 5) _showRecovery = true;
      _status = BiometricLockStatus.locked;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
    }
  }

  Future<bool> recoverWithGoogle(PreferencesState prefs) async {
    _status = BiometricLockStatus.authenticating;
    notifyListeners();

    try {
      final auth = AuthService();
      if (!auth.isSignedIn) {
        _status = BiometricLockStatus.locked;
        _errorMessage = 'No active Google session found for recovery.';
        notifyListeners();
        return false;
      }

      // Record current email before re-authentication
      final currentEmail = auth.currentUserEmail;

      // Reauthenticate with Google
      final user = await auth.signInWithGoogle();
      if (user != null) {
        // Validate email matches the active session
        final newEmail = user.email ?? '';
        if (currentEmail.isNotEmpty && newEmail != currentEmail) {
          _status = BiometricLockStatus.locked;
          _errorMessage = 'Account mismatch. Sign in with the same Google account to recover.';
          notifyListeners();
          return false;
        }

        // Email matches — disable biometric lock in preferences
        if (prefs.biometricLock) {
          prefs.toggleBiometricLock(); // Sets it to false
        }
        unlock();
        return true;
      } else {
        _status = BiometricLockStatus.locked;
        _errorMessage = 'Google verification failed.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = BiometricLockStatus.locked;
      _errorMessage = 'Recovery failed: $e';
      notifyListeners();
      return false;
    }
  }
}
