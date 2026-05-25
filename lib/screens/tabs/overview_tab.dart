import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../models/models.dart';

// ═══════════════════════════════════════════════════════════════
// Overview Tab — Bento-Grid Stats Dashboard
// ═══════════════════════════════════════════════════════════════

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section Header ──────────────────────────────────
              Text(
                'Your Journey',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // ── Bento Grid ──────────────────────────────────────
              _BentoGrid(appState: appState),

              const SizedBox(height: 28),

              // ── On This Day ─────────────────────────────────────
              _OnThisDaySection(appState: appState),

              const SizedBox(height: 28),

              // ── AI Insight of the Day ───────────────────────────
              const _AiInsightCard(),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Bento Grid
// ═══════════════════════════════════════════════════════════════

class _BentoGrid extends StatelessWidget {
  const _BentoGrid({required this.appState});

  final AppState appState;

  int _daysJournaled(AppState appState) {
    final dates = appState.entries
        .map((e) =>
            DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .toSet();
    return dates.length;
  }

  int _totalMedia(AppState appState) {
    return appState.entries.fold(0, (sum, e) => sum + e.photoUrls.length);
  }

  int _voiceNotes(AppState appState) {
    return appState.entries.where((e) => e.isVoiceEntry).length;
  }

  @override
  Widget build(BuildContext context) {
    // Re-read from context so the widget rebuilds on every addEntry/updateEntry
    final appState = context.watch<AppState>();

    return Column(
      children: [
        // ── Row 1: Streak (full-width) ───────────────────────────
        _StreakCard(streak: appState.currentStreak),
        const SizedBox(height: 12),

        // ── Row 2: Entries + Days ────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B4D8), Color(0xFF0077A8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                emoji: '📖',
                value: '${appState.entries.length}',
                label: 'Total Entries',
                height: 110,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B894), Color(0xFF00876C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                emoji: '📅',
                value: '${_daysJournaled(appState)}',
                label: 'Days Journaled',
                height: 110,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Row 3: Media + Voice + AI ────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFD79A8), Color(0xFFD85A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                emoji: '🖼️',
                value: '${_totalMedia(appState)}',
                label: 'Media',
                height: 96,
                smallMode: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE17055), Color(0xFFBC5A3E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                emoji: '🎙️',
                value: '${_voiceNotes(appState)}',
                label: 'Voice Notes',
                height: 96,
                smallMode: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF5A4DD6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                emoji: '✨',
                value: '${appState.entries.length}',
                label: 'AI Insights',
                height: 96,
                smallMode: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Row 4: Mood Score (full-width) ───────────────────────
        _MoodScoreCard(entries: appState.entries),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Streak Card
// ═══════════════════════════════════════════════════════════════

class _StreakCard extends StatefulWidget {
  const _StreakCard({required this.streak});

  final int streak;

  @override
  State<_StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<_StreakCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: IntrinsicHeight(
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF8B78E3)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🔥 Current Streak',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.streak == 0
                            ? 'Start journaling today!'
                            : 'Keep going — ${widget.streak} day${widget.streak == 1 ? '' : 's'} strong!',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.streak}',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'days',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Generic Stat Card
// ═══════════════════════════════════════════════════════════════

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.gradient,
    required this.emoji,
    required this.value,
    required this.label,
    required this.height,
    this.smallMode = false,
  });

  final LinearGradient gradient;
  final String emoji;
  final String value;
  final String label;
  final double height;
  final bool smallMode;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.height),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.emoji,
                style: TextStyle(fontSize: widget.smallMode ? 22 : 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value,
                    style: GoogleFonts.inter(
                      fontSize: widget.smallMode ? 26 : 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Mood Score Card
// ═══════════════════════════════════════════════════════════════

class _MoodScoreCard extends StatefulWidget {
  const _MoodScoreCard({required this.entries});

  final List<JournalEntry> entries;

  @override
  State<_MoodScoreCard> createState() => _MoodScoreCardState();
}

class _MoodScoreCardState extends State<_MoodScoreCard> {
  double _scale = 1.0;

  Map<Mood, int> get _moodCounts {
    final counts = <Mood, int>{};
    for (final e in widget.entries) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1;
    }
    return counts;
  }

  String _topMoodEmoji(Map<Mood, int> counts) {
    if (counts.isEmpty) return '😐';
    final topMood =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return topMood.emoji;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _moodCounts;
    final total = widget.entries.length;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5F6FA), Color(0xFFECEFF4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Text('💗', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Mood Avg',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (total == 0)
                      Text(
                        'No entries yet',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 10,
                          child: Row(
                            children: Mood.values
                                .where((m) => counts.containsKey(m))
                                .map((m) {
                              return Flexible(
                                flex: ((counts[m] ?? 0) * 100).round(),
                                child: Tooltip(
                                  message: '${m.emoji} ${m.label}',
                                  child: Container(color: m.color),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 12),
                Text(
                  _topMoodEmoji(counts),
                  style: const TextStyle(fontSize: 22),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// On This Day Section
// ═══════════════════════════════════════════════════════════════

class _OnThisDaySection extends StatelessWidget {
  const _OnThisDaySection({required this.appState});

  final AppState appState;

  List<JournalEntry> _getMemories() {
    final now = DateTime.now();
    return appState.entries.where((e) {
      return e.createdAt.month == now.month &&
          e.createdAt.day == now.day &&
          e.createdAt.year != now.year;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final memories = _getMemories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ON THIS DAY 🕰️',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (memories.isEmpty)
          _buildEmptyMemoryCard()
        else
          ...memories.map((e) => _OnThisDayCard(entry: e)),
      ],
    );
  }

  Widget _buildEmptyMemoryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EEF9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('📅', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No memories yet for today',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep journaling to see your past entries here.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnThisDayCard extends StatelessWidget {
  const _OnThisDayCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final yearsAgo = DateTime.now().year - entry.createdAt.year;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: entry.mood.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: MoodIcon(mood: entry.mood, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$yearsAgo year${yearsAgo == 1 ? '' : 's'} ago',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.createdAt.year.toString(),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AI Insight Card
// ═══════════════════════════════════════════════════════════════

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard();

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().entries;

    // Show a personalised empty-state insight when there's no data yet
    final insightText = entries.isEmpty
        ? 'Write your first journal entry and I\'ll start building insights about your emotional patterns and habits.'
        : 'You tend to feel most creative in the evenings. Consider journaling after sunset.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE8FB), Color(0xFFF3EFFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI INSIGHT OF THE DAY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insightText,
                  style: GoogleFonts.merriweather(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
