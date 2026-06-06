import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

enum AuthSessionState {
  unknown,
  authenticated,
  unauthenticated,
  refreshing,
  error,
  guest,
}

// ═══════════════════════════════════════════════════════════════
// AuthService — Supabase Authentication + Secure Session Store
// ═══════════════════════════════════════════════════════════════

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthSessionState _sessionState = AuthSessionState.unknown;
  AuthSessionState get sessionState => _sessionState;

  bool _supabaseReady = false;
  bool get isSupabaseReady => _supabaseReady;
  String? _initError;
  String? get initError => _initError;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _deepLinkSubscription;
  String? _lastHandledDeepLink;

  bool _justSignedIn = false;
  bool get justSignedIn => _justSignedIn;

  bool _isOAuthInProgress = false;
  bool get isOAuthInProgress => _isOAuthInProgress;

  bool _isImagePickerInProgress = false;
  bool get isImagePickerInProgress => _isImagePickerInProgress;

  void setImagePickerInProgress(bool value) {
    _isImagePickerInProgress = value;
    notifyListeners();
  }

  void clearOAuthProgress() {
    _isOAuthInProgress = false;
    notifyListeners();
  }

  void clearSignInFlag() {
    _justSignedIn = false;
    notifyListeners();
  }

  AuthService._internal() {
    // Listener is registered dynamically in initialize() once Supabase is ready
  }
  Future<void> _handleDeepLink(Uri uri) async {
    final uriStr = uri.toString();
    
    // Guard: don't process the same deep link twice
    if (_lastHandledDeepLink == uriStr) {
      debugPrint('[AuthService] Deep link already handled, skipping: $uriStr');
      return;
    }
    _lastHandledDeepLink = uriStr;

    // ── Handle BOTH Supabase OAuth flows ────────────────────────
    final hasFragment   = uri.fragment.isNotEmpty;
    final hasCode       = uri.queryParameters.containsKey('code');
    final hasToken      = uri.fragment.contains('access_token') ||
                          uri.queryParameters.containsKey('access_token');

    if (hasFragment || hasCode || hasToken) {
      debugPrint('[Supabase] Processing deep link (pkce=$hasCode, implicit=$hasFragment)');
      unawaited(() async {
        try {
          await _client.auth.getSessionFromUrl(uri);
        } on AuthApiException catch (e) {
          if (e.statusCode == '404' || e.code == 'flow_state_not_found' || e.message.contains('flow state')) {
            // Flow state already consumed — session was already created successfully.
            // This is safe to swallow; report to Sentry at info level.
            debugPrint('[AuthService] Flow state already consumed (safe to ignore): ${e.message}');
            try {
              Sentry.captureMessage(
                'Deep link flow state already consumed (non-fatal)',
                level: SentryLevel.info,
              );
            } catch (_) {}
            return;
          }
          rethrow;
        } catch (e) {
          debugPrint('[Supabase] getSessionFromUrl error: $e');
        }
      }());
    } else {
      debugPrint('[Supabase] Deep link ignored — no auth params: $uri');
    }
  }

  Future<void> initialize() async {
    // Proactively restore guest session state from SharedPreferences if set
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('isGuestUser') ?? false;
      if (isGuest) {
        _sessionState = AuthSessionState.guest;
        debugPrint('[AuthService] Proactively restored guest session state.');
      }
    } catch (_) {}

    if (_supabaseReady) return;

    debugPrint('[Supabase] SUPABASE_INIT_STARTED');

    final diag = ApiConfig.checkSupabaseDiagnostics();
    debugPrint('[Supabase] Runtime SUPABASE_URL: "${diag['url_value']}"');
    debugPrint('[Supabase] Runtime SUPABASE_ANON_KEY presence: ${diag['key_exists']}');
    debugPrint('[Supabase] Diagnostics check: starts_with_https=${diag['starts_with_https']}, contains_supabase_co=${diag['contains_supabase_co']}, key_starts_with_eyj=${diag['key_starts_with_eyj']}');

    if (!ApiConfig.hasSupabase) {
      final List<String> reasons = [];
      if (!diag['url_exists']) reasons.add('SUPABASE_URL is empty');
      if (!diag['key_exists']) reasons.add('SUPABASE_ANON_KEY is empty');
      if (diag['url_exists'] && !diag['starts_with_https']) reasons.add('SUPABASE_URL must start with https://');
      if (diag['url_exists'] && !diag['contains_supabase_co']) reasons.add('SUPABASE_URL must contain ".supabase.co"');
      if (diag['key_exists'] && !diag['key_starts_with_eyj']) reasons.add('SUPABASE_ANON_KEY must start with "eyJ" or "sb_publishable_"');
      _initError = reasons.join(', ');
      debugPrint('[Supabase] SUPABASE_INIT_FAILED: $_initError');
      return;
    }

    await _attemptSupabaseInit();
  }

  // ── Extracted so we can retry after clearing corrupt secure storage ──
  Future<void> _attemptSupabaseInit({bool isRetry = false}) async {
    try {
      await Supabase.initialize(
        url: ApiConfig.supabaseUrl,
        anonKey: ApiConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(),
          detectSessionInUri: false,
        ),
      );
      _supabaseReady = true;
      _initError = null;
      debugPrint('[Supabase] SUPABASE_INIT_SUCCESS${isRetry ? " (after keystore recovery)" : ""}');
      _setupAuthListeners();
    } catch (e) {
      if (e.toString().contains('already initialized')) {
        _supabaseReady = true;
        _initError = null;
        debugPrint('[Supabase] SUPABASE_INIT_SUCCESS (Already initialized)');
        _setupAuthListeners();

      } else if (!isRetry && _isKeystoreError(e)) {
        // ── FIX: Android Keystore corruption from Auto-Backup ──────────
        // When the app is reinstalled, Android restores SharedPreferences
        // but wipes the Android Keystore. FlutterSecureStorage has a key
        // reference (from restored SharedPrefs) but the actual encrypted
        // value in the Keystore is gone. Supabase.initialize() throws a
        // PlatformException trying to read the session.
        //
        // Fix: clear all secure storage entries and retry once.
        debugPrint('[Supabase] KEYSTORE CORRUPTION DETECTED: $e');
        debugPrint('[Supabase] Clearing corrupt secure storage and retrying...');
        try {
          await const FlutterSecureStorage().deleteAll();
          debugPrint('[Supabase] Secure storage cleared.');
        } catch (clearError) {
          debugPrint('[Supabase] Warning: could not clear secure storage: $clearError');
        }
        // Single retry with a clean Keystore
        await _attemptSupabaseInit(isRetry: true);

      } else {
        _initError = e.toString();
        debugPrint('[Supabase] SUPABASE_INIT_FAILED: $e');
      }
    }
  }

  // ── Detects Android Keystore / SecureStorage corruption errors ──
  bool _isKeystoreError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('platformexception') ||
           msg.contains('keystoreexception') ||
           msg.contains('javax.crypto') ||
           msg.contains('badpaddingexception') ||
           msg.contains('read failed') ||
           msg.contains('null check') ||
           msg.contains('no such file') ||
           msg.contains('key not found');
  }

  // ── Auth listener setup (extracted from initialize so it can be ──
  //    called after both first-try and retry success)
  void _setupAuthListeners() {
    // Set up deep link handling via app_links
    _appLinks = AppLinks();
    _deepLinkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[Supabase] Deep link received: $uri');
      _handleDeepLink(uri);
    });

    // Handle initial link if app was launched by a deep link (cold start)
    unawaited(() async {
      try {
        final uri = await _appLinks.getInitialLink();
        if (uri != null) {
          debugPrint('[Supabase] Initial deep link: $uri');
          await _handleDeepLink(uri);
        }
      } catch (e) {
        debugPrint('[Supabase] Error getting initial deep link: $e');
      }
    }());

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _isOAuthInProgress = false;
      notifyListeners();
      final session = data.session;
      final event = data.event;
      debugPrint('[Google Login] OAUTH_CALLBACK_RECEIVED - Event: $event');
      if (session != null) {
        debugPrint('[Google Login] SESSION_CREATED - User ID: ${session.user.id}');
        _lastHandledDeepLink = null;
        bool isAnon = false;
        try {
          isAnon = (session.user as dynamic).isAnonymous == true;
        } catch (_) {}
        if (!isAnon) {
          isAnon = session.user.appMetadata['provider'] == 'anonymous';
        }
        _sessionState = isAnon ? AuthSessionState.guest : AuthSessionState.authenticated;
        if (!isAnon) {
          unawaited(() async {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isGuestUser');
            } catch (_) {}
          }());
        }
        if (event == AuthChangeEvent.signedIn) {
          _justSignedIn = true;
          try {
            Posthog().capture(
              eventName: 'google_signin_succeeded',
              properties: {
                'user_id': session.user.id,
              },
            );
          } catch (_) {}
        }
        notifyListeners();
      } else {
        // Read isGuestUser asynchronously to preserve offline guest mode across restarts
        SharedPreferences.getInstance().then((prefs) {
          final isGuest = prefs.getBool('isGuestUser') ?? false;
          if (isGuest && event != AuthChangeEvent.signedOut) {
            _sessionState = AuthSessionState.guest;
            debugPrint('[AuthService] Restored guest session state in listener.');
          } else {
            _sessionState = AuthSessionState.unauthenticated;
          }
          notifyListeners();
        }).catchError((err) {
          debugPrint('[AuthService] Failed to read guest pref in listener: $err');
          _sessionState = AuthSessionState.unauthenticated;
          notifyListeners();
        });
      }
    });
  }
  SupabaseClient get _client => Supabase.instance.client;

  SupabaseClient? get _safeClient {
    if (!_supabaseReady) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient? get safeClient => _safeClient;

  String requireUserId() {
    final uid = currentUser?.id;
    if (uid == null) {
      throw const AuthException('User is not authenticated.');
    }
    return uid;
  }

  Future<T> withAuth<T>(Future<T> Function() call) async {
    final client = _safeClient;
    if (client == null) {
      throw const AuthException('Supabase is not configured.');
    }
    
    final session = client.auth.currentSession;
    if (session != null) {
      final expiresAt = session.expiresAt != null 
          ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
          : null;
      if (expiresAt != null && expiresAt.difference(DateTime.now()).inMinutes < 5) {
        _sessionState = AuthSessionState.refreshing;
        try {
          await client.auth.refreshSession();
          _sessionState = AuthSessionState.authenticated;
        } on AuthException catch (e) {
          _sessionState = AuthSessionState.unauthenticated;
          throw AuthException('Session expired and refresh failed: ${e.message}');
        } catch (e) {
          _sessionState = AuthSessionState.unauthenticated;
          throw AuthException('Session refresh failed: $e');
        }
      }
    }

    try {
      return await call();
    } on AuthException catch (e) {
      if (e.message.contains('JWT') || e.message.contains('expired') || e.message.contains('token')) {
        _sessionState = AuthSessionState.refreshing;
        try {
          await client.auth.refreshSession();
          _sessionState = AuthSessionState.authenticated;
          return await call();
        } catch (_) {
          _sessionState = AuthSessionState.unauthenticated;
          rethrow;
        }
      }
      rethrow;
    }
  }

  // ── Current user ──────────────────────────────────────────────
  User? get currentUser => _safeClient?.auth.currentUser;

  String get currentUserEmail => currentUser?.email ?? '';

  String get currentUserDisplayName {
    final metadataName = currentUser?.userMetadata?['full_name'] as String?;
    if (metadataName != null && metadataName.isNotEmpty) return metadataName;

    final email = currentUserEmail;
    if (email.isEmpty) return 'You';
    final name = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
    return name.isNotEmpty
        ? name[0].toUpperCase() + name.substring(1)
        : 'You';
  }

  String? get currentUserAvatarUrl =>
      currentUser?.userMetadata?['avatar_url'] as String?;

  String get currentUserJoinedDate {
    final rawDate = currentUser?.createdAt;
    if (rawDate == null) return 'Offline Guest';
    try {
      final date = DateTime.parse(rawDate);
      return 'Joined: ${DateFormat('MMMM yyyy').format(date)}';
    } catch (_) {
      return 'Guest';
    }
  }

  bool get isSignedIn => currentUser != null;

  // ── Auth state stream ─────────────────────────────────────────
  Stream<AuthState> get authStateChanges {
    final client = _safeClient;
    if (client == null) {
      debugPrint('[AuthService] authStateChanges stream requested but client is null.');
      return const Stream.empty();
    }
    return client.auth.onAuthStateChange;
  }

  Future<User?> signInWithGoogle() async {
    debugPrint('[Google Login] GOOGLE_SIGNIN_STARTED');
    if (!_supabaseReady) {
      throw AuthException(
        'Supabase not configured or ready. Failure reason: ${_initError ?? "API keys are not loaded."}',
      );
    }
    final client = _safeClient;
    if (client == null) {
      throw const AuthException(
        'Supabase client is not initialized or ready.',
      );
    }
    _isOAuthInProgress = true;
    notifyListeners();
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.antheia://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      debugPrint('[Google Login] OAUTH_BROWSER_OPENED');
      return client.auth.currentUser;
    } on AuthException catch (e) {
      debugPrint('[Google Login] Google auth: ${e.message}');
      _isOAuthInProgress = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      debugPrint('[Google Login] Google auth error: $e');
      _isOAuthInProgress = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<User?> signInWithApple() async {
    debugPrint('Apple auth is not enabled.');
    return null;
  }

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
    // Pure local-offline state. No network requests are fired,
    // ensuring instant boot and SQLite functionality for guest users.
    _sessionState = AuthSessionState.guest;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGuestUser', true);
    } catch (e) {
      debugPrint('[AuthService] Failed to save guest status: $e');
    }
    notifyListeners();
    return AuthResult.success(null, isOffline: true);
  }

  // ── Sign out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    // 1. Wipe local SQLite data only (memories, outbox, drafts, media queue)
    try {
      await DatabaseService().wipeLocalDataOnly();
    } catch (e) {
      debugPrint('[AuthService] SQLite wipe failed: $e');
    }

    // 2. Reset last sync notifier and preferences timestamp
    try {
      DatabaseService().lastSyncNotifier.value = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_timestamp');
      await prefs.remove('isGuestUser'); // Clear guest flag!
    } catch (e) {
      debugPrint('[AuthService] Clearing sync timestamp and guest flag failed: $e');
    }

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

// ═══════════════════════════════════════════════════════════════
// SecureLocalStorage — flutter_secure_storage implementation
// ═══════════════════════════════════════════════════════════════

class SecureLocalStorage extends LocalStorage {
  static const _storage = FlutterSecureStorage();

  const SecureLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return await _storage.containsKey(key: supabasePersistSessionKey);
  }

  @override
  Future<String?> accessToken() async {
    return await _storage.read(key: supabasePersistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String value) async {
    await _storage.write(key: supabasePersistSessionKey, value: value);
  }
}

