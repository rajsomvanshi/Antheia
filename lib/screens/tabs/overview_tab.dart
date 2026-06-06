import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/memory_state.dart';
import '../../state/preferences_state.dart';
import '../../state/memory_persistence_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/interaction_system.dart';
import '../editor_surface.dart';
import '../memory_detail_screen.dart';
import '../../services/paywall_service.dart';
import '../../services/resurfacing_engine.dart';
import '../paywall_sheet.dart';
import '../../state/app_orchestrator.dart';
import '../../services/outbox_service.dart';
import '../../widgets/ambient_pulse_glow.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = context.watch<MemoryState>();
    final prefs = context.watch<PreferencesState>();
    final persistState = context.watch<MemoryPersistenceState>();
    
    final colors = AppColors.of(context);
    final type = AppType.of(context, fontOverride: prefs.selectedFont);
    
    if (memory.isLoading) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(
          child: SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF9B7A4A),
            ),
          ),
        ),
      );
    }

    final entries = memory.entries;
    final now = DateTime.now();

    // Active draft recovery hook
    final activeDraft = persistState.activeDraft;

    // Resurfaced memory fragment older than 7 days using the ResurfacingEngine
    final candidateMemories = entries.where((e) => now.difference(e.createdAt).inDays >= 7).toList();
    final resonantMemories = ResurfacingEngine.getResonantMemories(candidateMemories, limit: 1);
    final fragment = resonantMemories.isNotEmpty ? resonantMemories.first : null;

    // Last created entry
    final lastEntry = entries.isNotEmpty ? entries.first : null;

    // Progressive disclosure rules
    final totalCount = entries.length;
    final showOnlyToday = totalCount == 0;
    final showTodayAndRecent = totalCount > 0 && totalCount <= 3;
    final showAll = totalCount >= 4;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Atmospheric subtle paper grain overlay
            const Positioned.fill(
              child: IgnorePointer(
                child: CinematicGrain(seed: 2, animate: false),
              ),
            ),
            
            // Ambient pulse glow behind the content
            const Positioned.fill(
              child: IgnorePointer(
                child: AmbientPulseGlow(),
              ),
            ),
            
            ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 64),
              children: [
                // Header (Day of week & Date)
                Transform.translate(
                  offset: Offset(0, _scrollOffset * 0.6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE').format(now),
                        style: type.displayLarge.copyWith(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 36,
                          fontWeight: FontWeight.normal,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM d').format(now).toUpperCase(),
                        style: type.small.copyWith(
                          color: colors.textSecondary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const QuietSyncIndicator(),
                const SizedBox(height: 36),

                // ────────────────── SECTION 1: TODAY ──────────────────
                _buildSectionHeader('TODAY', colors, type),
                const SizedBox(height: 12),
                _buildTodayTriggers(context, colors, type),
                const SizedBox(height: 24),
                Divider(color: colors.hairline, height: 0.5),
                const SizedBox(height: 24),

                // ───────────── SECTION 2: CONTINUE REFLECTION ─────────────
                if (!showOnlyToday && activeDraft.isNotEmpty) ...[
                  _buildSectionHeader('CONTINUE REFLECTION', colors, type),
                  const SizedBox(height: 12),
                  _buildDraftTrigger(
                    context,
                    persistState.getRecoveredEntry(),
                    persistState.draftDisplayText,
                    colors,
                    type,
                  ),
                  const SizedBox(height: 24),
                  Divider(color: colors.hairline, height: 0.5),
                  const SizedBox(height: 24),
                ],

                // ─────────────── SECTION 3: MEMORY FRAGMENT ───────────────
                if (showAll && fragment != null) ...[
                  _buildSectionHeader('MEMORY FRAGMENT', colors, type),
                  const SizedBox(height: 12),
                  _buildFragmentTrigger(context, fragment, colors, type),
                  const SizedBox(height: 24),
                  Divider(color: colors.hairline, height: 0.5),
                  const SizedBox(height: 24),
                ],

                // ─────────────── SECTION 4: RECENT ENTRIES ───────────────
                if ((showTodayAndRecent || showAll) && lastEntry != null) ...[
                  _buildSectionHeader('RECENT ENTRIES', colors, type),
                  const SizedBox(height: 12),
                  _buildRecentTrigger(context, lastEntry, colors, type),
                  const SizedBox(height: 24),
                  Divider(color: colors.hairline, height: 0.5),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ResolvedColors colors, ResolvedType type) {
    return Text(
      title,
      style: type.label.copyWith(
        color: colors.accent,
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTodayTriggers(BuildContext context, ResolvedColors colors, ResolvedType type) {
    final hasEntries = context.watch<MemoryState>().entries.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final paywall = context.read<PaywallService>();
                final gate = paywall.checkGate(ProFeature.unlimitedEntries);
                if (gate != null) {
                  final unlocked = await PaywallSheet.show(context, gate);
                  if (!unlocked) return;
                }
                AppHaptics.light();
                if (context.mounted) {
                  Navigator.push(
                    context,
                    AppTransitions.fade(const EditorSurface()),
                  );
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Begin writing',
                style: type.body.copyWith(
                  color: colors.text,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('·', style: TextStyle(color: colors.textSecondary)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final paywall = context.read<PaywallService>();
                final gate = paywall.checkGate(ProFeature.unlimitedEntries);
                if (gate != null) {
                  final unlocked = await PaywallSheet.show(context, gate);
                  if (!unlocked) return;
                }
                AppHaptics.light();
                if (context.mounted) {
                  // Navigate to Shell Voice tab directly via AppOrchestrator
                  context.read<AppOrchestrator>().setNavIndex(2);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Speak softly',
                style: type.body.copyWith(
                  color: colors.text,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        if (!hasEntries) ...[
          const SizedBox(height: 16),
          Text(
            'Describe the window you are looking through right now.',
            style: type.bodySecondary.copyWith(
              fontStyle: FontStyle.italic,
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDraftTrigger(
    BuildContext context,
    JournalEntry entry,
    String displayText,
    ResolvedColors colors,
    ResolvedType type,
  ) {
    return GestureDetector(
      onTap: () {
        AppHaptics.subtle();
        Navigator.push(
          context,
          AppTransitions.fade(
            EditorSurface(initialEntry: entry),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayText.length > 90 ? '${displayText.substring(0, 90)}...' : displayText,
            style: type.bodySecondary.copyWith(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unfinished thought... (Draft)',
            style: type.small.copyWith(
              color: colors.textFaint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFragmentTrigger(
    BuildContext context,
    JournalEntry entry,
    ResolvedColors colors,
    ResolvedType type,
  ) {
    final ageInDays = DateTime.now().difference(entry.createdAt).inDays;
    final ageInYears = ageInDays ~/ 365;
    final String timeStr;
    if (ageInYears >= 1) {
      timeStr = ageInYears == 1 ? 'One year ago today...' : '$ageInYears years ago today...';
    } else if (ageInDays >= 30) {
      final months = ageInDays ~/ 30;
      timeStr = months == 1 ? 'One month ago...' : '$months months ago...';
    } else {
      timeStr = '$ageInDays days ago...';
    }
    
    final prefs = context.watch<PreferencesState>();
    final isPremium = prefs.isPremium;
    final views = prefs.aiLinkViews;
    final isGated = !isPremium && views >= 2;
    
    return GestureDetector(
      onTap: () async {
        AppHaptics.subtle();
        if (isGated) {
          await PaywallSheet.show(context, ProFeature.unlimitedEntries);
        } else {
          prefs.incrementAiLinkViews();
          Navigator.push(
            context,
            AppTransitions.slideUp(MemoryDetailScreen(entry: entry)),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title.isEmpty ? 'Untitled Memory' : entry.title,
                  style: type.readingTitle.copyWith(
                    fontSize: 20,
                    color: colors.text,
                  ),
                ),
              ),
              if (isGated) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: colors.accent,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isGated
                ? 'Unlock full memory intelligence with Pro'
                : timeStr,
            style: type.small.copyWith(
              color: isGated ? colors.error : colors.accent.withValues(alpha: 0.8),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrigger(
    BuildContext context,
    JournalEntry entry,
    ResolvedColors colors,
    ResolvedType type,
  ) {
    final relativeDate = _timeAgo(entry.createdAt);
    return GestureDetector(
      onTap: () {
        AppHaptics.subtle();
        Navigator.push(
          context,
          AppTransitions.slideUp(MemoryDetailScreen(entry: entry)),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title.isEmpty ? 'Untitled Memory' : entry.title,
            style: type.body.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last journal entry... ($relativeDate)',
            style: type.small.copyWith(
              color: colors.textFaint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(date);
  }
}

class QuietSyncIndicator extends StatelessWidget {
  const QuietSyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = AppType.of(context);
    final outbox = OutboxService();

    return ValueListenableBuilder<bool>(
      valueListenable: outbox.isSyncLimitReachedNotifier,
      builder: (context, limitReached, _) {
        return ValueListenableBuilder<int>(
          valueListenable: outbox.permanentlyFailedCountNotifier,
          builder: (context, failedCount, _) {
            return ValueListenableBuilder<int>(
              valueListenable: outbox.pendingCountNotifier,
              builder: (context, pendingCount, _) {
                if (limitReached) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.error.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 16, color: colors.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your memories are no longer being backed up. Upgrade to continue.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (failedCount > 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.error.withValues(alpha: 0.25), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: colors.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Backup failed — $failedCount entries need attention',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            AppHaptics.light();
                            outbox.retryFailed();
                          },
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: colors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (pendingCount > 0) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Syncing… ($pendingCount pending)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: colors.textFaint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }
}
