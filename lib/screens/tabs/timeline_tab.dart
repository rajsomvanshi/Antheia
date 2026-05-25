import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../models/models.dart';
import '../editor_screen.dart';

// ═══════════════════════════════════════════════════════════════
// TimelineTab — Scrollable list of journal entries
//
// Each card shows:
//   • Photo thumbnail (first photo) OR mood-colour placeholder
//   • Date  (e.g. "24 May 2026")
//   • Title (only if one was saved)
//
// Empty state: friendly illustration + prompt to write.
// No hardcoded data — purely driven by AppState.entries.
// ═══════════════════════════════════════════════════════════════

class TimelineTab extends StatelessWidget {
  const TimelineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().entries;

    if (entries.isEmpty) {
      return _EmptyState();
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _JournalCard(
          entry: entries[index],
          onTap: () {
            context.read<AppState>().setCurrentEntry(entries[index]);
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (c, a, s) => const EditorScreen(),
                transitionsBuilder: (c, a, s, child) => FadeTransition(
                  opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
                  child: child,
                ),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _JournalCard
// ═══════════════════════════════════════════════════════════════

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card),
                bottomLeft: Radius.circular(AppRadius.card),
              ),
              child: _buildThumbnail(),
            ),

            // ── Text content ───────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    Text(
                      _formatDate(entry.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Title (only if non-empty)
                    if (entry.title.isNotEmpty) ...[
                      Text(
                        entry.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Mood chip
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: entry.mood.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                entry.mood.emoji,
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                entry.mood.label,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: entry.mood.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (entry.isVoiceEntry) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.mic_rounded,
                            size: 13,
                            color: AppColors.textSecondary.withOpacity(0.6),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    const double w = 90;
    const double h = 110;

    if (entry.photoUrls.isNotEmpty) {
      final url = entry.photoUrls.first;
      if (url.startsWith('http')) {
        return Image.network(
          url,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderBox(w, h),
        );
      }
    }
    return _placeholderBox(w, h);
  }

  Widget _placeholderBox(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: entry.mood.color.withOpacity(0.12),
      child: Center(
        child: Text(
          entry.mood.emoji,
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _EmptyState — shown when the user has no journal entries yet
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Text('📓', style: TextStyle(fontSize: 46)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your journal is empty',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the + Journal button below to write\nyour first entry — text or voice.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
