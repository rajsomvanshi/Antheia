import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'timeline_screen.dart';
import 'editor_screen.dart';
import 'insights_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'recording_screen.dart';

// ═══════════════════════════════════════════════════════════════
// HomeShell — Main navigation shell with expandable FAB
// FIX: Screens are not const — prevents stale state across tabs.
//      FAB overlay uses IgnorePointer correctly so nav still works.
// ═══════════════════════════════════════════════════════════════

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fabController;
  late final Animation<double> _fabRotation;
  late final Animation<double> _fabOverlayOpacity;
  bool _isFabExpanded = false;

  // FIX: Not const — each tab gets its own stateful widget instance
  // that can properly rebuild when navigated back to.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const TimelineScreen(),
      const EditorScreen(),
      const InsightsScreen(),
      const MapScreen(),
      const SettingsScreen(),
    ];

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabRotation =
        Tween<double>(begin: 0, end: math.pi / 4).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack),
    );
    _fabOverlayOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_isFabExpanded) {
      setState(() {
        _isFabExpanded = false;
        _fabController.reverse();
      });
    }
  }

  void _onFabOptionTap(String option) {
    _closeFab();
    switch (option) {
      case 'voice':
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const RecordingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
        break;
      case 'text':
        final appState = Provider.of<AppState>(context, listen: false);
        appState.setCurrentEntry(null);
        appState.setNavIndex(1);
        break;
      case 'photo':
        final appState = Provider.of<AppState>(context, listen: false);
        appState.setCurrentEntry(null);
        appState.setNavIndex(1);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final currentIndex = appState.currentNavIndex;

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          bottomNavigationBar:
              _buildBottomNavBar(context, appState, currentIndex),
          floatingActionButton: _buildFab(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        ),

        // FIX: Overlay — only consume taps when FAB is expanded
        if (_isFabExpanded)
          AnimatedBuilder(
            animation: _fabOverlayOpacity,
            builder: (context, child) {
              return GestureDetector(
                onTap: _closeFab,
                child: Container(
                  color: Colors.black
                      .withValues(alpha: 0.45 * _fabOverlayOpacity.value),
                ),
              );
            },
          ),

        // FAB menu items (shown above overlay)
        if (_isFabExpanded) _buildFabMenu(),
      ],
    );
  }

  Widget _buildBottomNavBar(
      BuildContext context, AppState appState, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () {
                  _closeFab();
                  appState.setNavIndex(0);
                },
              ),
              _NavItem(
                icon: Icons.edit_note_rounded,
                label: 'Editor',
                isSelected: currentIndex == 1,
                onTap: () {
                  _closeFab();
                  appState.setNavIndex(1);
                },
              ),
              const SizedBox(width: 56), // Space for FAB
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Insights',
                isSelected: currentIndex == 2,
                onTap: () {
                  _closeFab();
                  appState.setNavIndex(2);
                },
              ),
              _NavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                isSelected: currentIndex == 3,
                onTap: () {
                  _closeFab();
                  appState.setNavIndex(3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return AnimatedBuilder(
      animation: _fabRotation,
      builder: (context, child) {
        return SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: _toggleFab,
            elevation: _isFabExpanded ? 8 : 4,
            backgroundColor: AppColors.accentPrimary,
            shape: const CircleBorder(),
            child: Transform.rotate(
              angle: _fabRotation.value,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFabMenu() {
    return Positioned(
      bottom: 96,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _fabOverlayOpacity,
        builder: (context, _) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - _fabOverlayOpacity.value)),
            child: Opacity(
              opacity: _fabOverlayOpacity.value,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: AppShadows.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FabMenuItem(
                        emoji: '🎙',
                        label: 'Voice Entry',
                        subtitle: 'Talk about your day',
                        onTap: () => _onFabOptionTap('voice'),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        endIndent: 16,
                        color: AppColors.borderSubtle.withValues(alpha: 0.5),
                      ),
                      _FabMenuItem(
                        emoji: '✏️',
                        label: 'Text Entry',
                        subtitle: 'Write your thoughts',
                        onTap: () => _onFabOptionTap('text'),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        endIndent: 16,
                        color: AppColors.borderSubtle.withValues(alpha: 0.5),
                      ),
                      _FabMenuItem(
                        emoji: '📷',
                        label: 'Photo Entry',
                        subtitle: 'Capture a moment',
                        onTap: () => _onFabOptionTap('photo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Bottom Nav Item ─────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentPrimary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FAB Menu Item ───────────────────────────────────────────

class _FabMenuItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _FabMenuItem({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
