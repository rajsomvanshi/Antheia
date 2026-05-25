import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../models/models.dart';

// ═══════════════════════════════════════════════════════════════
// CalendarTab — Monthly calendar view
//
// FIXED:
//  • Every date now has a circular bubble (outlined ring).
//  • Journaled dates: bubble is filled and shows the first photo
//    thumbnail (clipped to circle). If no photo, shows the mood
//    emoji inside the bubble instead.
//  • Today: accent-coloured ring.
//  • Selected date: filled accent circle (same as before).
// ═══════════════════════════════════════════════════════════════

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() => setState(() {
        _focusedMonth =
            DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _focusedMonth =
            DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      });

  @override
  Widget build(BuildContext context) {
    final allEntries = context.watch<AppState>().entries;

    // Build a map: date → first JournalEntry on that date
    final Map<DateTime, JournalEntry> entryByDay = {};
    for (final e in allEntries) {
      final key = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      entryByDay.putIfAbsent(key, () => e);
    }

    return Column(
      children: [
        // ── Month navigation ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.textPrimary,
                onPressed: _prevMonth,
              ),
              Text(
                _monthLabel(_focusedMonth),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.textPrimary,
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),

        // ── Weekday headers ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map((d) => SizedBox(
                      width: 44,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        // ── Calendar grid ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildGrid(entryByDay),
        ),

        const Divider(height: 32),

        // ── Selected day entries ──────────────────────────────────
        Expanded(
          child: _selectedDay == null
              ? Center(
                  child: Text(
                    'Tap a day to see entries',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : _buildDayEntries(allEntries, _selectedDay!),
        ),
      ],
    );
  }

  // ─── Calendar Grid ────────────────────────────────────────────
  Widget _buildGrid(Map<DateTime, JournalEntry> entryByDay) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0 = Sunday

    final cells = <Widget>[];

    // Empty cells before the first day
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox(width: 44, height: 52));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date =
          DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final entry = entryByDay[date]; // null = no journal on this date
      final hasEntry = entry != null;
      final isSelected = _selectedDay == date;
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: _DateBubble(
            day: day,
            isSelected: isSelected,
            isToday: isToday,
            entry: entry,
            hasEntry: hasEntry,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 2,
      runSpacing: 6,
      children: cells,
    );
  }

  // ─── Day Entry List ───────────────────────────────────────────
  Widget _buildDayEntries(List<JournalEntry> allEntries, DateTime day) {
    final dayEntries = allEntries.where((e) {
      return e.createdAt.year == day.year &&
          e.createdAt.month == day.month &&
          e.createdAt.day == day.day;
    }).toList();

    if (dayEntries.isEmpty) {
      return Center(
        child: Text(
          'No entries on ${_dayLabel(day)}',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: dayEntries.length,
      itemBuilder: (context, index) {
        final e = dayEntries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              // Thumbnail or mood bubble
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildEntryThumbnail(e, size: 52),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(e.createdAt),
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
      },
    );
  }

  Widget _buildEntryThumbnail(JournalEntry e, {required double size}) {
    if (e.photoUrls.isNotEmpty) {
      final url = e.photoUrls.first;
      if (url.startsWith('http')) {
        return Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _moodBox(e, size),
        );
      }
    }
    return _moodBox(e, size);
  }

  Widget _moodBox(JournalEntry e, double size) {
    return Container(
      width: size,
      height: size,
      color: e.mood.color.withOpacity(0.15),
      child: Center(
        child: Text(e.mood.emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  String _monthLabel(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _dayLabel(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

// ═══════════════════════════════════════════════════════════════
// _DateBubble — individual calendar date cell
// ═══════════════════════════════════════════════════════════════

class _DateBubble extends StatelessWidget {
  const _DateBubble({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.hasEntry,
    this.entry,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool hasEntry;
  final JournalEntry? entry;

  @override
  Widget build(BuildContext context) {
    // Decide colours
    final Color borderColor = isSelected
        ? AppColors.accentPrimary
        : isToday
            ? AppColors.accentPrimary
            : hasEntry
                ? AppColors.accentPrimary.withOpacity(0.45)
                : AppColors.textSecondary.withOpacity(0.25);

    final double borderWidth = isSelected || isToday ? 2.0 : 1.2;

    return SizedBox(
      width: 44,
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // The bubble
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // If selected: solid fill
                  color: isSelected ? AppColors.accentPrimary : Colors.transparent,
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: ClipOval(
                  child: _bubbleContent(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Day number below (or inside the bubble if no image)
          if (hasEntry && entry!.photoUrls.isNotEmpty)
            Text(
              '$day',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubbleContent() {
    if (isSelected) {
      // Selected: just show the day number in white
      return Center(
        child: Text(
          '$day',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    if (hasEntry && entry!.photoUrls.isNotEmpty) {
      // Journaled + has photo: show thumbnail
      final url = entry!.photoUrls.first;
      if (url.startsWith('http')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emojiContent(),
        );
      }
      return _emojiContent();
    }

    if (hasEntry) {
      // Journaled but no photo: show mood emoji on tinted bg
      return Container(
        color: entry!.mood.color.withOpacity(0.12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              entry!.mood.emoji,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '$day',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    // Regular date — just the number
    return Center(
      child: Text(
        '$day',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _emojiContent() {
    return Container(
      color: entry!.mood.color.withOpacity(0.12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(entry!.mood.emoji, style: const TextStyle(fontSize: 14)),
          Text(
            '$day',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
