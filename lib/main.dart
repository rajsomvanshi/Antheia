import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'screens/splash_screen.dart';
import 'services/api_config.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/revenuecat_service.dart';
import 'services/narration_service.dart';
import 'state/app_orchestrator.dart';
import 'state/memory_persistence_state.dart';
import 'state/memory_state.dart';
import 'state/preferences_state.dart';
import 'state/voice_state.dart';
import 'services/paywall_service.dart';
import 'state/biometric_state.dart';
import 'theme/app_theme.dart';
import 'widgets/secure_app_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration keys from assets/.env at runtime before database/sync services boot
  await ApiConfig.loadEnv();

  // Initialize Firebase and Crashlytics
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize AuthService BEFORE database/sync services boot so deep link listener is ready
  await AuthService().initialize();

  // ── FIX: DB init failure must be visible — don't silently swallow it ──
  // If this throws in production, the app will start but entries won't persist.
  // You MUST fix the underlying DB issue if this starts firing.
  bool dbReady = false;
  try {
    await DatabaseService().init();
    dbReady = DatabaseService().isReady;
  } catch (e) {
    debugPrint('[CRITICAL] DatabaseService init failed: $e');
    // Note: retry is handled inside DatabaseService._openDatabaseConn
    // (quarantine + fresh open). A second init() call here is a no-op
    // because DatabaseService is a singleton with if (_db != null) return.
  }

  try {
    await RevenueCatService().initialize();
  } catch (e) {
    debugPrint('RevenueCat init skipped: $e');
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://43ad81adf7e4dfbc5703d0fa0d437367@o4511489728380928.ingest.us.sentry.io/4511489740242944';
      options.tracesSampleRate = 0.2;
    },
    appRunner: () => runApp(AntheiaApp(dbReady: dbReady)),
  );
}

class AntheiaApp extends StatelessWidget {
  final bool dbReady;
  const AntheiaApp({super.key, required this.dbReady});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(
          create: (_) => PreferencesState()..loadPreferences(),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoryState()..loadEntries(),
        ),
        ChangeNotifierProvider(create: (_) => VoiceState()),
        ChangeNotifierProvider(create: (_) => MemoryPersistenceState()..loadDraft()),
        ChangeNotifierProvider(create: (_) => AppOrchestrator()),
        ChangeNotifierProvider(create: (_) => NarrationService()),
        ChangeNotifierProvider(create: (_) => BiometricState()),
        ChangeNotifierProxyProvider2<PreferencesState, MemoryState, PaywallService>(
          create: (context) => PaywallService(
            prefs: context.read<PreferencesState>(),
          ),
          update: (context, prefs, memory, previous) {
            final service = previous ?? PaywallService(prefs: prefs);
            final photosCount = memory.entries.fold<int>(0, (sum, e) => sum + (e.thumbnailPath != null ? 1 : 0) + e.photoUrls.length);
            service.syncCounts(memory.entries.length, photosCount);
            return service;
          },
        ),
      ],
      child: Consumer<PreferencesState>(
        builder: (context, prefs, _) {
          final isDark = prefs.themeMode == ThemeMode.dark ||
              (prefs.themeMode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);

          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness:
                  isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor:
                  isDark ? const Color(0xFF100F0E) : const Color(0xFFF7F4EE),
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
          );

          return AnimationScale(
            intensity: prefs.animationIntensity,
            child: MaterialApp(
              title: 'Antheia',
              debugShowCheckedModeBanner: false,
              themeMode: prefs.themeMode,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              home: const SplashScreen(),
              onUnknownRoute: (_) => MaterialPageRoute(
                builder: (_) => const SplashScreen(),
              ),
              builder: (context, child) {
                final appChild = child ?? const SizedBox.shrink();
                final secured = SecureAppWrapper(child: appChild);
                if (!dbReady) {
                  return Directionality(
                    textDirection: TextDirection.ltr,
                    child: Column(
                      children: [
                        Material(
                          color: const Color(0xFF2A2520), // Warm Charcoal background
                          child: SafeArea(
                            bottom: false,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFF9B7A4A), // Muted Gold border
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFD0B08A), // Premium gold
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Storage is unavailable. Please restart the app.',
                                      style: TextStyle(
                                        fontFamily: 'Cormorant Garamond',
                                        fontSize: 15,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFFF7F4EE), // Warm Ivory
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: secured),
                      ],
                    ),
                  );
                }
                return secured;
              },
            ),
          );
        },
      ),
    );
  }
}
