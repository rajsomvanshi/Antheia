import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/interaction_system.dart';
import '../state/preferences_state.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;

  final List<_OnboardingItem> _pages = const [
    _OnboardingItem(
      title: 'A place for what remains.',
      description: 'Antheia is a private sanctuary. A silent drawer for your voice, your thoughts, and the moments you wish to keep forever.',
    ),
    _OnboardingItem(
      title: 'Your history is yours.',
      description: 'No servers inspect your words. No trackers follow your thoughts. Your archive lives safely on this device first, backed up under your control.',
    ),
    _OnboardingItem(
      title: 'Speak softly.',
      description: 'Hold or tap to capture your thoughts. Antheia listens to the details, structuring them quietly into your personal library.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      AppHaptics.subtle();
      setState(() {
        _currentPage++;
      });
    } else {
      _complete();
    }
  }

  void _complete() {
    AppHaptics.medium();
    final prefsState = Provider.of<PreferencesState>(context, listen: false);
    prefsState.completeOnboarding();
    
    // Launch decision tree: Onboarding completes and routes to Auth Screen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = AppType.of(context);

    final currentItem = _pages[_currentPage];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Atmospheric subtle grain texture
            const Positioned.fill(
              child: IgnorePointer(
                child: CinematicGrain(seed: 9, animate: false),
              ),
            ),

            // Main Text Column with narrow width constraint
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pure Cross-fade (800ms) page animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      switchInCurve: Curves.easeInOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: Column(
                        key: ValueKey<int>(_currentPage),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentItem.title,
                            textAlign: TextAlign.center,
                            style: type.displayLarge.copyWith(
                              fontFamily: 'Cormorant Garamond',
                              fontSize: 32,
                              fontWeight: FontWeight.normal,
                              color: colors.text,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            currentItem.description,
                            textAlign: TextAlign.center,
                            style: type.bodySecondary.copyWith(
                              fontSize: 14,
                              color: colors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80), // breathing room
                  ],
                ),
              ),
            ),

            // Bottom Navigation and Page Indicators
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress dots (3 dots)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: isActive ? colors.accent : colors.border,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      
                      // Text button link in style of sanctuary (no heavy SaaS buttons)
                      GestureDetector(
                        onTap: _next,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _currentPage == _pages.length - 1 ? colors.accent : colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.hairline, width: 0.5),
                          ),
                          child: Center(
                            child: Text(
                              _currentPage == _pages.length - 1 ? 'Begin' : 'Continue',
                              style: type.body.copyWith(
                                fontWeight: FontWeight.w500,
                                color: _currentPage == _pages.length - 1 ? colors.bg : colors.text,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String description;
  const _OnboardingItem({required this.title, required this.description});
}
