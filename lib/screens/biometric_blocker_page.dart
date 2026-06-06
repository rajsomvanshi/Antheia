import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/biometric_state.dart';
import '../state/preferences_state.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/interaction_system.dart';

// ═══════════════════════════════════════════════════════════════
// BiometricBlockerPage — Hardened premium security wall
// ═══════════════════════════════════════════════════════════════

class BiometricBlockerPage extends StatefulWidget {
  const BiometricBlockerPage({super.key});

  @override
  State<BiometricBlockerPage> createState() => _BiometricBlockerPageState();
}

class _BiometricBlockerPageState extends State<BiometricBlockerPage> {
  @override
  void initState() {
    super.initState();
    // Auto-initiate authentication on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BiometricState>().authenticate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final biometricState = context.watch<BiometricState>();
    final prefsState = context.read<PreferencesState>();
    final isSignedIn = AuthService().isSignedIn;

    IconData getLockIcon() {
      switch (biometricState.status) {
        case BiometricLockStatus.lockoutTemp:
        case BiometricLockStatus.lockoutPerm:
          return Icons.lock_clock_rounded;
        case BiometricLockStatus.notEnrolled:
        case BiometricLockStatus.unsupported:
        case BiometricLockStatus.unavailable:
          return Icons.warning_amber_rounded;
        case BiometricLockStatus.biometricsRemoved:
          return Icons.security_update_warning_rounded;
        case BiometricLockStatus.authenticating:
          return Icons.hourglass_empty_rounded;
        case BiometricLockStatus.locked:
        default:
          return Icons.lock_outline_rounded;
      }
    }

    Color getIconColor() {
      if (biometricState.status == BiometricLockStatus.biometricsRemoved) {
        return const Color(0xFFD9534F); // Amber warning color
      }
      switch (biometricState.status) {
        case BiometricLockStatus.lockoutTemp:
        case BiometricLockStatus.lockoutPerm:
        case BiometricLockStatus.unavailable:
        case BiometricLockStatus.notEnrolled:
          return colors.error;
        case BiometricLockStatus.authenticating:
          return colors.accent.withValues(alpha: 0.5);
        case BiometricLockStatus.locked:
        default:
          return colors.accent;
      }
    }

    return PopScope(
      canPop: false, // Non-dismissible by system swipes/gestures
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Center Lock Coordinates (Visual Indicator)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.hairline, width: 0.5),
                  ),
                  child: Center(
                    child: Icon(
                      getLockIcon(),
                      size: 28,
                      color: getIconColor(),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Center Message: "A moment of verification before entry."
                if (biometricState.status == BiometricLockStatus.biometricsRemoved)
                  Text(
                    'Biometric sensors are missing. Access using device passcode is available.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFD9534F), // Amber warning
                      height: 1.5,
                    ),
                  )
                else
                  Text(
                    'A moment of verification before entry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                      color: colors.accent,
                      letterSpacing: 0.3,
                    ),
                  ),

                // Quiet status error message if present
                if (biometricState.errorMessage != null &&
                    biometricState.status != BiometricLockStatus.biometricsRemoved) ...[
                  const SizedBox(height: 16),
                  Text(
                    biometricState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                // Bottom third anchors for Fallbacks & Google Recovery
                if (biometricState.isAuthenticating)
                  // Spinner while authentication is active
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.accent,
                    ),
                  )
                else ...[
                  // Primary Fallback trigger button
                  GestureDetector(
                    onTap: () {
                      AppHaptics.light();
                      biometricState.authenticate();
                    },
                    child: Text(
                      'Use device PIN / Password',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                        decoration: TextDecoration.underline,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Google Account Recovery Option
                  if (biometricState.showRecovery) ...[
                    const SizedBox(height: 24),
                    if (isSignedIn) ...[
                      Text(
                        'Locked out? Verify your account identity to bypass.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          AppHaptics.medium();
                          await biometricState.recoverWithGoogle(prefsState);
                        },
                        child: Text(
                          'Verify with Google',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                            decoration: TextDecoration.underline,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No recovery account is linked. Please authenticate via device credentials above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textTertiary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ],

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
