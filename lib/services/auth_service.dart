import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_config.dart';

// ═══════════════════════════════════════════════════════════════
// AuthService — Supabase Authentication
// ═══════════════════════════════════════════════════════════════

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Current user ──────────────────────────────────────────────
  User? get currentUser => ApiConfig.hasSupabase ? _client.auth.currentUser : null;

  String get currentUserEmail => currentUser?.email ?? '';

  String get currentUserDisplayName {
    final email = currentUserEmail;
    if (email.isEmpty) return 'You';
    final name = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
    return name.isNotEmpty
        ? name[0].toUpperCase() + name.substring(1)
        : 'You';
  }

  bool get isSignedIn => currentUser != null;

  // ── Auth state stream ─────────────────────────────────────────
  Stream<AuthState> get authStateChanges =>
      ApiConfig.hasSupabase ? _client.auth.onAuthStateChange : const Stream.empty();

  // ── Sign up ───────────────────────────────────────────────────
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (!ApiConfig.hasSupabase) {
      return AuthResult.success(null, isOffline: true);
    }

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      return AuthResult.success(response.user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Sign up failed. Please try again.');
    }
  }

  // ── Sign in ───────────────────────────────────────────────────
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!ApiConfig.hasSupabase) {
      return AuthResult.success(null, isOffline: true);
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return AuthResult.success(response.user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Sign in failed. Please check your credentials.');
    }
  }

  // ── Anonymous sign-in ─────────────────────────────────────────
  Future<AuthResult> continueAnonymously() async {
    if (!ApiConfig.hasSupabase) {
      return AuthResult.success(null, isOffline: true);
    }

    try {
      final response = await _client.auth.signInAnonymously();
      return AuthResult.success(response.user);
    } on AuthException catch (e) {
      debugPrint('Anonymous auth: ${e.message}');
      return AuthResult.success(null, isOffline: true);
    } catch (e) {
      return AuthResult.success(null, isOffline: true);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    if (!ApiConfig.hasSupabase) return;
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  // ── Password reset ────────────────────────────────────────────
  Future<AuthResult> sendPasswordReset(String email) async {
    if (!ApiConfig.hasSupabase) {
      return AuthResult.failure('Supabase not configured');
    }
    try {
      await _client.auth.resetPasswordForEmail(email);
      return AuthResult.success(null);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Reset failed. Please try again.');
    }
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? error;
  final bool isOffline;

  const AuthResult._({
    required this.success,
    this.user,
    this.error,
    this.isOffline = false,
  });

  factory AuthResult.success(User? user, {bool isOffline = false}) =>
      AuthResult._(success: true, user: user, isOffline: isOffline);

  factory AuthResult.failure(String error) =>
      AuthResult._(success: false, error: error);
}
