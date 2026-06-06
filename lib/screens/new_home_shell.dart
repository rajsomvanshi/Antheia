import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';
import '../state/memory_persistence_state.dart';
import '../state/memory_state.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/lazy_indexed_stack.dart';
import 'editor_surface.dart';
import 'settings_screen.dart';
import 'tabs/memories_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/timeline_tab.dart';
import 'voice_reflection_surface.dart';

import '../state/app_orchestrator.dart';

class NewHomeShell extends StatefulWidget {
  const NewHomeShell({super.key});

  @override
  State<NewHomeShell> createState() => _NewHomeShellState();
}

class _NewHomeShellState extends State<NewHomeShell> {
  bool _didSync = false;
  bool _syncing = false; // Mutex to prevent concurrent sync operations
  StreamSubscription? _authSub;

  static const _tabData = <_TabInfo>[
    _TabInfo(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _TabInfo(Icons.schedule_outlined, Icons.schedule_rounded, 'Archive'),
    _TabInfo(Icons.mic_none_outlined, Icons.mic_rounded, 'Voice'),
    _TabInfo(Icons.photo_library_outlined, Icons.photo_library_rounded, 'Memories'),
    _TabInfo(Icons.tune_outlined, Icons.tune_rounded, 'Space'),
  ];

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = const [
      OverviewTab(),
      TimelineTab(),
      VoiceReflectionSurface(asTab: true),
      MemoriesTab(),
      SettingsScreen(asTab: true),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRecoveredDraft();
      
      // Register auth listener to run guest migration and delta sync on sign-in
      final auth = context.read<AuthService>();
      _authSub = auth.authStateChanges.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) {
          _onUserLogin(data.session?.user.id);
        }
      });
    });
  }

  Future<void> _onUserLogin(String? userId) async {
    if (userId == null) return;
    _didSync = true;
    // Use the serialized safe sync — migrates guest data, pulls cloud, reloads UI
    await _safeSync(migrateGuestForUserId: userId);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _checkRecoveredDraft() {
    final persistState = context.read<MemoryPersistenceState>();
    if (persistState.hasRecoveredDraft) {
      persistState.consumeRecoveredDraft();
      final colors = AppColors.of(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.hairline, width: 0.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An unfinished reflection remains. Would you like to resume writing?',
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 20,
                  fontWeight: FontWeight.normal,
                  color: colors.text,
                  height: 1.45,
                ),
              ),
              if (persistState.draftDisplayText.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.hairline, width: 0.5),
                  ),
                  child: Text(
                    persistState.draftDisplayText.length > 100
                        ? '${persistState.draftDisplayText.substring(0, 100).trim()}…'
                        : persistState.draftDisplayText.trim(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 20, bottom: 16),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                persistState.clearDraft();
              },
              child: Text(
                'Fold away',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                final recoveredEntry = persistState.getRecoveredEntry();
                Navigator.push(
                  context,
                  AppTransitions.fade(
                    EditorSurface(initialEntry: recoveredEntry),
                  ),
                );
              },
              child: Text(
                'Resume writing',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    if (auth.isSignedIn && !_didSync) {
      _didSync = true;
      _safeSync();
    }
  }

  /// Single, serialized, safe sync path.
  /// - Uses merge-only pullSync (never deletes local entries)
  /// - Pushes pending outbox jobs
  /// - Reloads entries from SQLite into UI
  /// - Protected by _syncing mutex to prevent concurrent runs
  Future<void> _safeSync({String? migrateGuestForUserId}) async {
    if (_syncing) {
      debugPrint('[NewHomeShell] _safeSync skipped: already syncing');
      return;
    }
    _syncing = true;
    try {
      // Step 1: Migrate guest memories if this is a fresh sign-in
      if (migrateGuestForUserId != null) {
        try {
          await DatabaseService().migrateGuestMemories(migrateGuestForUserId);
        } catch (e) {
          debugPrint('[NewHomeShell] Guest migration failed (non-fatal): $e');
        }
      }

      // Step 2: Pull from cloud (merge-only, never deletes) + push outbox
      try {
        await DatabaseService().syncNow();
      } catch (e) {
        debugPrint('[NewHomeShell] syncNow failed (non-fatal): $e');
      }

      // Step 3: Reload entries from SQLite into the in-memory list
      if (mounted) {
        await context.read<MemoryState>().loadEntries(quiet: true);
      }
    } catch (e) {
      debugPrint('[NewHomeShell] _safeSync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentTab = context.watch<AppOrchestrator>().currentNavIndex;
    return Scaffold(
      backgroundColor: colors.bg,
      extendBody: true,
      body: LazyIndexedStack(index: currentTab, children: _tabs),
      bottomNavigationBar: _buildQuietNav(colors, currentTab),
    );
  }

  Widget _buildQuietNav(ResolvedColors colors, int currentTab) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return GlassNavBar(
      height: 64,
      bottomPadding: bottomPadding,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final tabCount = _tabData.length;
            final tabWidth = totalWidth / tabCount;
            final dotWidth = 5.0;
              final activeLeft = tabWidth * (currentTab + 0.5) - (dotWidth / 2);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Row(
                      children: List.generate(tabCount, (index) {
                        final tab = _tabData[index];
                        final active = currentTab == index;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.read<AppOrchestrator>().setNavIndex(index),
                            child: AnimatedOpacity(
                              duration: AppTransitions.short,
                              opacity: active ? 1.0 : 0.3,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    active ? tab.activeIcon : tab.icon,
                                    key: ValueKey('${tab.label}_$active'),
                                    size: 20,
                                    color: active
                                        ? colors.accent
                                        : colors.text,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  
                  // Premium spring sliding active ink-dot!
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: const Cubic(0.175, 0.885, 0.32, 1.1), // elastic spring-like bounce
                    left: activeLeft,
                    bottom: 12,
                    width: dotWidth,
                    height: dotWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
  }
}

class _TabInfo {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabInfo(this.icon, this.activeIcon, this.label);
}
