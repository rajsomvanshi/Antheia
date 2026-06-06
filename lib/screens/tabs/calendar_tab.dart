import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../theme/interaction_system.dart';
import '../../state/memory_state.dart';
import '../../models/models.dart';
import '../memory_detail_screen.dart';
import '../editor_surface.dart';

// ═══════════════════════════════════════════════════════════════
// Calendar Tab — Life Archive
//
// Scrubbed of habit streaks and GitHub contribution blocks.
// Time is represented as a quiet print canvas of emotional states
// indicated by a single, delicate gold dot below active days.
// ═══════════════════════════════════════════════════════════════

import '../../services/paywall_service.dart';
import '../paywall_sheet.dart';

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _focusMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<MemoryState>().entries;
    final colors = AppColors.of(context);

    // Count entries per day for this month
    final Map<int, List<JournalEntry>> dayEntriesMap = {};
    for (final e in entries) {
      final localDate = e.createdAt.toLocal();
      if (localDate.year == _focusMonth.year && localDate.month == _focusMonth.month) {
        dayEntriesMap.putIfAbsent(localDate.day, () => []).add(e);
      }
    }

    final daysInMonth = DateUtils.getDaysInMonth(_focusMonth.year, _focusMonth.month);
    final firstWeekday = DateTime(_focusMonth.year, _focusMonth.month, 1).weekday % 7;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _selectedDay == null
          ? null
          : FloatingActionButton(
              backgroundColor: colors.accent,
              mini: true,
              onPressed: () async {
                final paywall = context.read<PaywallService>();
                final gate = paywall.checkGate(ProFeature.unlimitedEntries);
                if (gate != null) {
                  final unlocked = await PaywallSheet.show(context, gate);
                  if (!unlocked) return;
                }
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditorSurface(
                        initialEntry: JournalEntry(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: '',
                          content: '',
                          blocks: [TextBlock()],
                          createdAt: _selectedDay!,
                          updatedAt: _selectedDay!,
                          mood: Mood.neutral,
                        ),
                      ),
                    ),
                  );
                }
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CinematicGrain(seed: 21, animate: false),
            ),
          ),
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 120),
            children: [
              // Month navigation header (Atmospheric editorial feel)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      AppHaptics.subtle();
                      setState(() {
                        _focusMonth = DateTime(_focusMonth.year, _focusMonth.month - 1);
                        _selectedDay = null; // Reset selection on month change
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.chevron_left_rounded, color: colors.textSecondary.withValues(alpha: 0.6), size: 20),
                    ),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_focusMonth).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                      letterSpacing: 1.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      AppHaptics.subtle();
                      setState(() {
                        _focusMonth = DateTime(_focusMonth.year, _focusMonth.month + 1);
                        _selectedDay = null; // Reset selection on month change
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.chevron_right_rounded, color: colors.textSecondary.withValues(alpha: 0.6), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
  
              // Weekday headers
              Row(
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary.withValues(alpha: 0.5),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
  
              // Completely borderless, clean print calendar grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: firstWeekday + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < firstWeekday) {
                    return const SizedBox();
                  }
                  
                  final day = index - firstWeekday + 1;
                  final dayEntries = dayEntriesMap[day] ?? [];
                  final hasMemories = dayEntries.isNotEmpty;
                  
                  final nowLocal = DateTime.now();
                  final isToday = day == nowLocal.day &&
                      _focusMonth.month == nowLocal.month &&
                      _focusMonth.year == nowLocal.year;
  
                  final isSelected = _selectedDay != null &&
                      _selectedDay!.day == day &&
                      _selectedDay!.month == _focusMonth.month &&
                      _selectedDay!.year == _focusMonth.year;
  
                  return GestureDetector(
                    onTap: () async {
                      AppHaptics.subtle();
                      setState(() {
                        _selectedDay = DateTime(_focusMonth.year, _focusMonth.month, day);
                      });
                      if (hasMemories) {
                        final paywall = context.read<PaywallService>();
                        final gate = paywall.checkGate(ProFeature.calendarFull);
                        if (gate != null) {
                          await PaywallSheet.show(context, gate);
                        } else {
                          _showDayEntries(context, day, dayEntries, colors);
                        }
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Day Number Text
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: isToday
                                ? Border.all(color: colors.accent, width: 1.0)
                                : (isSelected ? Border.all(color: colors.textSecondary.withValues(alpha: 0.4), width: 1.0) : null),
                            color: isSelected ? colors.accent.withValues(alpha: 0.15) : null,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: isToday ? FontWeight.bold : (hasMemories ? FontWeight.w500 : FontWeight.w300),
                                color: isToday
                                    ? colors.accent
                                    : (hasMemories ? colors.text : colors.textSecondary.withValues(alpha: 0.6)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        
                        // Delicate gold dot below the date number
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasMemories ? colors.accent : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDayEntries(
    BuildContext context,
    int day,
    List<JournalEntry> dayEntries,
    ResolvedColors colors,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: colors.hairline, width: 0.5),
      ),
      builder: (_) => _DaySheet(
        entries: dayEntries,
        date: DateTime(_focusMonth.year, _focusMonth.month, day),
        colors: colors,
      ),
    );
  }
}

class _DaySheet extends StatelessWidget {
  final List<JournalEntry> entries;
  final DateTime date;
  final ResolvedColors colors;

  const _DaySheet({
    required this.entries,
    required this.date,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Structural grab handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Header
            Text(
              DateFormat('EEEE, MMMM d').format(date).toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colors.accent,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${entries.length} reflection${entries.length > 1 ? 's' : ''} captured',
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 20),
            
            // Borderless entries rows
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index];
                  final timeStr = DateFormat('h:mm a').format(e.createdAt);
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        AppTransitions.slideUp(MemoryDetailScreen(entry: e)),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colors.hairline, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title.isEmpty ? 'Untitled Memory' : e.title,
                                  style: TextStyle(
                                    fontFamily: 'Cormorant Garamond',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: colors.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: colors.textSecondary.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: colors.textSecondary.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
