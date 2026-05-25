import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════
// Insights Screen — Real Data Wiring
// ═══════════════════════════════════════════════════════════════

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().entries;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Your Patterns',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                'AI‑powered insights from ${entries.length} entries',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: _DateRangeSelector(),
        ),
      ),
      body: entries.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                MoodCalendarCard(entries: entries),
                const SizedBox(height: 16),
                EmotionGraphCard(entries: entries),
                const SizedBox(height: 16),
                WordCloudCard(entries: entries),
                const SizedBox(height: 16),
                PeopleListCard(entries: entries),
                const SizedBox(height: 16),
                WeeklySummaryCard(entries: entries),
                const SizedBox(height: 16),
                StreakHeatmapCard(entries: entries),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'No insights yet',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep journaling to unlock your patterns.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Date Range Selector ────────────────────────────────────────
class _DateRangeSelector extends StatefulWidget {
  const _DateRangeSelector();
  @override
  State<_DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<_DateRangeSelector> {
  final List<String> _options = ['Week', 'Month', 'Year'];
  int _selected = 0;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_options.length, (i) {
          final selected = i == _selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(_options[i]),
              selected: selected,
              onSelected: (_) => setState(() => _selected = i),
              selectedColor: AppColors.accentPrimary,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Mood Helpers ───────────────────────────────────────────────
Color _getColorForMood(Mood mood) {
  switch (mood) {
    case Mood.happy:
    case Mood.energetic:
      return AppColors.accentSuccess; // Green
    case Mood.calm:
    case Mood.grateful:
      return const Color(0xFF74B9FF); // Blue
    case Mood.nostalgic:
    case Mood.creative:
      return const Color(0xFFFDCB6E); // Yellow
    case Mood.anxious:
    case Mood.sad:
    case Mood.romantic:
      return AppColors.accentWarm; // Red/Pink
    case Mood.neutral:
      return AppColors.borderSubtle; // Gray
  }
}

double _getScoreForMood(Mood mood) {
  switch (mood) {
    case Mood.happy:
    case Mood.energetic:
      return 5.0;
    case Mood.calm:
    case Mood.creative:
    case Mood.romantic:
    case Mood.grateful:
      return 4.0;
    case Mood.neutral:
    case Mood.nostalgic:
      return 3.0;
    case Mood.anxious:
      return 2.0;
    case Mood.sad:
      return 1.0;
  }
}

// ─── Mood Calendar Card ────────────────────────────────────────
class MoodCalendarCard extends StatelessWidget {
  final List<JournalEntry> entries;
  const MoodCalendarCard({required this.entries, super.key});

  @override
  Widget build(BuildContext context) {
    // Map last 30 days to colors
    final now = DateTime.now();
    final List<Color> dayColors = List.generate(30, (index) {
      final targetDate = now.subtract(Duration(days: 29 - index));
      // Find an entry for this day
      try {
        final entry = entries.firstWhere((e) => 
            e.createdAt.year == targetDate.year && 
            e.createdAt.month == targetDate.month && 
            e.createdAt.day == targetDate.day);
        return _getColorForMood(entry.mood);
      } catch (_) {
        return AppColors.borderSubtle.withValues(alpha: 0.2); // No entry
      }
    });

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '😊 Mood Calendar — Last 30 Days',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 30,
              itemBuilder: (context, idx) {
                return Container(
                  decoration: BoxDecoration(
                    color: dayColors[idx].withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Emotion Graph Card ────────────────────────────────────────
class EmotionGraphCard extends StatelessWidget {
  final List<JournalEntry> entries;
  const EmotionGraphCard({required this.entries, super.key});

  @override
  Widget build(BuildContext context) {
    // Calculate last 7 days mood score
    final now = DateTime.now();
    final List<double> values = [];
    final List<String> days = [];
    
    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dayStr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][targetDate.weekday - 1];
      days.add(dayStr);
      
      final dayEntries = entries.where((e) => 
            e.createdAt.year == targetDate.year && 
            e.createdAt.month == targetDate.month && 
            e.createdAt.day == targetDate.day).toList();
            
      if (dayEntries.isEmpty) {
        values.add(0.0);
      } else {
        double total = 0;
        for (var e in dayEntries) { total += _getScoreForMood(e.mood); }
        values.add(total / dayEntries.length);
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 Mood Score — Last 7 Days',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final height = (values[i] / 5) * 80; // normalize to 80px max
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: max(height, 4.0), // minimum height to show something
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: values[i] > 0 ? AppColors.accentSecondary : AppColors.borderSubtle.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        days[i],
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Word Cloud Card ────────────────────────────────────────
class WordCloudCard extends StatelessWidget {
  final List<JournalEntry> entries;
  const WordCloudCard({required this.entries, super.key});

  @override
  Widget build(BuildContext context) {
    // Collect all tags and keywords
    final Map<String, int> frequencies = {};
    for (var entry in entries) {
      for (var tag in entry.tags) {
        frequencies[tag.toLowerCase()] = (frequencies[tag.toLowerCase()] ?? 0) + 3; // Tags weight heavily
      }
      final words = entry.content.split(RegExp(r'\\s+'));
      for (var word in words) {
        final clean = word.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
        if (clean.length > 4) { // Ignore short words
          frequencies[clean] = (frequencies[clean] ?? 0) + 1;
        }
      }
    }

    final sortedWords = frequencies.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topWords = sortedWords.take(12).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💬 Your Words',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: topWords.map((w) {
                // Normalize size between 11 and 20
                final maxFreq = topWords.first.value;
                final size = 11.0 + (w.value / maxFreq) * 9.0;
                final weight = w.value > (maxFreq / 2) ? FontWeight.w600 : FontWeight.w400;
                
                return Chip(
                  backgroundColor: AppColors.bgSecondary,
                  label: Text(
                    w.key,
                    style: TextStyle(fontSize: size, fontWeight: weight, color: AppColors.textPrimary),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── People List Card ────────────────────────────────────────
class PeopleListCard extends StatelessWidget {
  final List<JournalEntry> entries;
  const PeopleListCard({required this.entries, super.key});

  @override
  Widget build(BuildContext context) {
    final people = context.read<AppState>().people;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👥 People You Talk To',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            ...people.take(3).map((person) => ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.accentWarm, child: Text(person.initial)),
              title: Text(person.name, style: TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('${person.emotionalIcon} Sentiment: ${person.emotionalScore}', style: TextStyle(color: AppColors.textSecondary)),
              trailing: Chip(
                label: Text('💬 ${person.entryCount} entries', style: const TextStyle(color: Colors.white, fontSize: 10)),
                backgroundColor: AppColors.accentPrimary,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Weekly Summary Card ────────────────────────────────────────
class WeeklySummaryCard extends StatelessWidget {
  final List<JournalEntry> entries;
  const WeeklySummaryCard({required this.entries, super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weeklyEntries = entries.where((e) => e.createdAt.isAfter(weekAgo)).toList();
    
    int totalMins = 0;
    Map<Mood, int> moodCounts = {};
    for (var e in weeklyEntries) {
      totalMins += e.durationMinutes;
      moodCounts[e.mood] = (moodCounts[e.mood] ?? 0) + 1;
    }
    
    String mostCommonMood = 'none';
    if (moodCounts.isNotEmpty) {
      final sortedMoods = moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      mostCommonMood = sortedMoods.first.key.name;
    }

    final avgMins = weeklyEntries.isEmpty ? 0 : (totalMins / weeklyEntries.length).toStringAsFixed(1);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🗓 Weekly Summary',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'You wrote ${weeklyEntries.length} entries this week, averaging $avgMins minutes each. Your most common mood was $mostCommonMood.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Streak Heatmap Card ────────────────────────────────────────
class StreakHeatmapCard extends StatelessWidget {
  final List<JournalEntry> entries;
  const StreakHeatmapCard({required this.entries, super.key});

  @override
  Widget build(BuildContext context) {
    // 4 rows x 7 cols = 28 days
    final now = DateTime.now();
    final List<int> heatmap = List.generate(28, (index) {
      final targetDate = now.subtract(Duration(days: 27 - index));
      final dayCount = entries.where((e) => 
            e.createdAt.year == targetDate.year && 
            e.createdAt.month == targetDate.month && 
            e.createdAt.day == targetDate.day).length;
      return dayCount.clamp(0, 3);
    });

    Color colorForLevel(int level) {
      switch (level) {
        case 1: return AppColors.accentWarm.withValues(alpha: 0.3);
        case 2: return AppColors.accentWarm.withValues(alpha: 0.6);
        case 3: return AppColors.accentWarm;
        default: return AppColors.borderSubtle.withValues(alpha: 0.2);
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔥 Streak Heatmap',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 28,
              itemBuilder: (context, idx) {
                return Container(
                  decoration: BoxDecoration(
                    color: colorForLevel(heatmap[idx]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
