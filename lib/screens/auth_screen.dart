import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../theme/interaction_system.dart';
import '../state/preferences_state.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'new_home_shell.dart';
import 'onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  bool _isLoading = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
    ));

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    debugPrint('[Google Login] BUTTON_TAPPED');
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      // On mobile devices, this opens a web browser asynchronously.
      // The auth result is processed when the deep link returns and triggers the subscription listener above.
      await auth.signInWithGoogle();
    } on AuthException catch (e) {
      AuthService().clearOAuthProgress();
      debugPrint('[Google Login] AuthException: ${e.message}');
      final msg = e.message.toLowerCase();
      // Skip cancellation errors silently without showing scary error popups
      final isCancel = msg.contains('cancel') || msg.contains('dismiss') || msg.contains('user closed');
      if (!isCancel && mounted) {
        _showAuthError(message: e.message);
      }
    } catch (e) {
      AuthService().clearOAuthProgress();
      debugPrint('[Google Login] Error: $e');
      final msg = e.toString().toLowerCase();
      final isNetwork = msg.contains('socketexception') || msg.contains('network') || msg.contains('failed to connect');
      final errMessage = isNetwork 
          ? 'No internet connection detected. Please check your network or Continue Offline.' 
          : 'Google sign-in error: $e';
      if (mounted) _showAuthError(message: errMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      await auth.continueAnonymously(); // Sets session guest mode explicitly
      if (mounted) _navigateToApp();
    } catch (_) {
      if (mounted) _navigateToApp();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAuthError({String? message}) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.hairline, width: 0.5),
        ),
        title: Text(
          'Connection Issue',
          style: TextStyle(fontFamily: 'Inter', color: colors.text),
        ),
        content: Text(
          message ?? 'Could not connect to sign in. Would you like to use Antheia offline as a guest?',
          style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _continueAsGuest();
            },
            child: Text('Work Offline', style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToApp() {
    final prefsState = context.read<PreferencesState>();
    final destination = prefsState.hasCompletedOnboarding
        ? const NewHomeShell()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = AppType.of(context);

    return Consumer<AuthService>(
      builder: (context, auth, child) {
        if (auth.justSignedIn && !_hasNavigated && mounted) {
          _hasNavigated = true;
          auth.clearSignInFlag();
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            setState(() => _isLoading = true);
            try {
              final session = AuthService().safeClient?.auth.currentSession;
              if (session != null) {
                await DatabaseService().migrateGuestMemories(session.user.id);
              }
            } catch (e) {
              debugPrint('Migration error: $e');
            }
            if (mounted) _navigateToApp();
          });
        }

        return Scaffold(
          backgroundColor: colors.bg,
          body: Stack(
            children: [
              // Subtle noise/grain texture
              const Positioned.fill(
                child: IgnorePointer(
                  child: CinematicGrain(seed: 12, animate: false),
                ),
              ),

              // Core centered negative space with bottom third actions
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const Spacer(flex: 3),
                          
                          // Brand Logo in Cormorant Garamond
                          Text(
                            'Antheia',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 36,
                              fontWeight: FontWeight.normal,
                              color: colors.accent,
                              letterSpacing: 6.0,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'A place for what remains.',
                            textAlign: TextAlign.center,
                            style: type.small.copyWith(
                              color: colors.textSecondary,
                              letterSpacing: 2.4,
                            ),
                          ),
                          
                          const Spacer(flex: 2),

                          // Lower third actions
                          if (_isLoading)
                            const SizedBox(
                              height: 112,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0xFF9B7A4A),
                                  ),
                                ),
                              ),
                            )
                          else
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Continue with Google - unbleached paper styled button
                                GestureDetector(
                                  onTap: _signInWithGoogle,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: colors.hairline, width: 0.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Continue with Google',
                                        style: type.body.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: colors.text,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Continue Offline underlined text link
                                GestureDetector(
                                  onTap: _continueAsGuest,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Continue Offline',
                                      style: type.caption.copyWith(
                                        color: colors.textSecondary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
