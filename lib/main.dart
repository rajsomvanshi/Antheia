import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'state/app_state.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';
import 'services/revenuecat_service.dart';

// ═══════════════════════════════════════════════════════════════
// FlowJournal — AI-Powered Voice Journal
// ═══════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite (Supabase init is handled inside DatabaseService,
  // wrapped in try/catch so missing keys don't crash the app).
  await DatabaseService().init();

  try {
    await RevenueCatService().initialize();
  } catch (e) {
    debugPrint('RevenueCat init skipped: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const FlowJournalApp());
}

class FlowJournalApp extends StatelessWidget {
  const FlowJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final state = AppState();
        state.loadPreferences();
        state.loadEntries();
        RevenueCatService().getCustomerInfo().then((info) {
          if (info != null && RevenueCatService().isPremiumActive(info)) {
            state.setPremium(true);
          }
        });
        return state;
      },
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'FlowJournal',
            debugShowCheckedModeBanner: false,
            themeMode: appState.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
