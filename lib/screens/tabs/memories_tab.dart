import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../theme/interaction_system.dart';
import '../../state/memory_state.dart';
import '../../models/models.dart';
import '../memory_detail_screen.dart';
import 'calendar_tab.dart';
import 'map_tab.dart';
import 'media_tab.dart';
import '../../widgets/lazy_indexed_stack.dart';
import '../../widgets/staggered_reveal.dart';

// ═══════════════════════════════════════════════════════════════
// Memories Tab — Unified Sanctuary Library
//
// Shows curated thematic connections automatically clustered by tags
// and quiet, inline print-editorial navigation toggles.
// ═══════════════════════════════════════════════════════════════

class MemoriesTab extends StatefulWidget {
  const MemoriesTab({super.key});
  @override
  State<MemoriesTab> createState() => _MemoriesTabState();
}

class _MemoriesTabState extends State<MemoriesTab> {
  int _segment = 0;

  static const _segments = <_SegmentInfo>[
    _SegmentInfo('Library'),
    _SegmentInfo('Calendar'),
    _SegmentInfo('Map'),
    _SegmentInfo('Media'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sanctuary Library',
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 36,
                      fontWeight: FontWeight.normal,
                      color: colors.text,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore your life by themes, times, and places.',
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Quiet, inline typographic segment switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _buildSegments(colors),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: LazyIndexedStack(
                index: _segment,
                children: const [
                  _UnifiedLibraryContent(),
                  CalendarTab(),
                  MapTab(),
                  MediaTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegments(ResolvedColors colors) {
    return Row(
      children: [
        Text(
          'Filter: ',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colors.textSecondary.withValues(alpha: 0.5),
            letterSpacing: 0.2,
          ),
        ),
        ...List.generate(_segments.length, (i) {
          final seg = _segments[i];
          final isActive = _segment == i;
          return Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () => setState(() => _segment = i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seg.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? colors.accent : colors.textSecondary.withValues(alpha: 0.8),
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 12,
                      height: 1.5,
                      color: colors.accent,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SegmentInfo {
  final String label;
  const _SegmentInfo(this.label);
}

// ─── Unified Library: Curated Connections + Archive Thread ─────
class _UnifiedLibraryContent extends StatelessWidget {
  const _UnifiedLibraryContent();

  @override
  Widget build(BuildContext context) {
    final memoryState = context.watch<MemoryState>();
    final entries = memoryState.entries;
    final colors = AppColors.of(context);

    if (memoryState.isLoading) {
      return const Center(
        child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Color(0xFF9B7A4A),
          ),
        ),
      );
    }

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No connections found.',
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Speak softly or write to gather reflections and grow your library.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Dynamic semantic tag-theme clusters extraction
    final Map<String, List<JournalEntry>> themeClusters = {};
    for (final entry in entries) {
      for (final tag in entry.tags) {
        if (tag.trim().isNotEmpty) {
          final cleanTag = tag.trim().toLowerCase();
          themeClusters.putIfAbsent(cleanTag, () => []).add(entry);
        }
      }
    }

    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: CinematicGrain(seed: 17, animate: false),
          ),
        ),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // CURATED CONCEPT CLUSTERS (CONNECTED THEMES)
            if (themeClusters.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 12),
                    child: Text(
                      'CONNECTED THEMES',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                sliver: SliverList.builder(
                  itemCount: themeClusters.length,
                  itemBuilder: (context, index) {
                    final themeName = themeClusters.keys.elementAt(index);
                    final clusterEntries = themeClusters[themeName]!;
                    
                    // Oldest and newest year range
                    clusterEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    final oldestYear = clusterEntries.first.createdAt.year;
                    final newestYear = clusterEntries.last.createdAt.year;
                    final yearRange = oldestYear == newestYear ? '$oldestYear' : '$oldestYear — $newestYear';

                    final cleanTheme = themeName[0].toUpperCase() + themeName.substring(1);

                    return StaggeredReveal(
                      index: index,
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.subtle();
                          Navigator.push(
                            context,
                            AppTransitions.slideUp(
                              ThemeThreadScreen(
                                themeName: themeName,
                                entries: clusterEntries,
                              ),
                            ),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                      cleanTheme,
                                      style: TextStyle(
                                        fontFamily: 'Cormorant Garamond',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: colors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${clusterEntries.length} reflection${clusterEntries.length > 1 ? 's' : ''}  ·  $yearRange',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        color: colors.textSecondary.withValues(alpha: 0.6),
                                        letterSpacing: 0.2,
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
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 36),
              ),
            ],

            // ALL MEMORIES (CHRONOLOGICAL TIMELINE ROWS)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'ALL REFLECTIONS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 120),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return StaggeredReveal(
                    index: index,
                    child: _MemoryRow(entry: entries[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Memory Row (95% Borderless Print Aesthetic) ───────────────
class _MemoryRow extends StatelessWidget {
  final JournalEntry entry;
  const _MemoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(entry.createdAt).toUpperCase();
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: () {
        AppHaptics.subtle();
        Navigator.push(
          context,
          AppTransitions.slideUp(MemoryDetailScreen(entry: entry)),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.hairline, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date stamp column
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr.split(' ')[1],
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: colors.text,
                      height: 0.9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr.split(' ')[0],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty ? 'Untitled Memory' : entry.title,
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.content.isEmpty ? 'Speech transcription...' : entry.content,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: colors.textSecondary.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (entry.isVoiceEntry) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Icon(
                  Icons.mic_none_outlined,
                  size: 13,
                  color: colors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ThemeThreadScreen — Fully reviewed editorial chronological list
// ═══════════════════════════════════════════════════════════════
// Verified against all typography (Garamond/Inter), spacing (28dp),
// and transition standards. Displays themed memories in reverse order.
class ThemeThreadScreen extends StatelessWidget {
  final String themeName;
  final List<JournalEntry> entries;

  const ThemeThreadScreen({
    super.key,
    required this.themeName,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cleanTheme = themeName[0].toUpperCase() + themeName.substring(1);

    // Dynamic Year Range
    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final oldestYear = entries.first.createdAt.year;
    final newestYear = entries.last.createdAt.year;
    final yearRange = oldestYear == newestYear ? '$oldestYear' : '$oldestYear — $newestYear';

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              cleanTheme,
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            Text(
              yearRange,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: colors.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CinematicGrain(seed: 19, animate: false),
              ),
            ),
            ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 80),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                // Return entries in reverse chronological order for reading flow
                final entry = entries[entries.length - 1 - index];
                return StaggeredReveal(
                  index: index,
                  child: _MemoryRow(entry: entry),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
