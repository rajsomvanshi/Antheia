import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/memory_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/interaction_system.dart';
import '../memory_detail_screen.dart';
import '../editor_surface.dart';
import '../voice_reflection_surface.dart';

import '../../services/paywall_service.dart';
import '../paywall_sheet.dart';
import '../../widgets/staggered_reveal.dart';

class TimelineTab extends StatefulWidget {
  const TimelineTab({super.key});

  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab> {
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
    final memoryState = context.watch<MemoryState>();
    final entries = memoryState.entries;
    final colors = AppColors.of(context);

    if (memoryState.isLoading) {
      return SafeArea(
        child: Center(
          child: SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.accent,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: entries.isEmpty
          ? _EmptyTimeline(colors: colors)
          : CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 48, 28, 36),
                    child: Transform.translate(
                      offset: Offset(0, _scrollOffset * 0.6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Archive',
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
                            'Your life, held over time.',
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
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 130),
                  sliver: SliverList.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      
                      // Check if we need to show a year divider
                      final showYearDivider = index == 0 ||
                          entries[index].createdAt.year != entries[index - 1].createdAt.year;

                      return StaggeredReveal(
                        index: index,
                        child: _TimelineEditorialRow(
                          entry: entry,
                          colors: colors,
                          showYearDivider: showYearDivider,
                          // Asymmetrical alignment: indent every second entry slightly
                          indent: index % 2 == 1,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  final ResolvedColors colors;

  const _EmptyTimeline({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Atmospheric dynamic film grain backdrop
        const Positioned.fill(
          child: IgnorePointer(
            child: CinematicGrain(seed: 4, animate: false),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Poetic title in Cormorant
                Text(
                  'The pages are quiet.',
                  style: TextStyle(
                    fontFamily: 'Cormorant Garamond',
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: colors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Hairline dividing motif
                Container(
                  width: 48,
                  height: 0.5,
                  color: colors.accent.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 28),
                
                // Warm, highly-reflective writing prompt
                Text(
                  '“Describe the window you are looking through right now. What lies beyond the glass, and what remains inside?”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cormorant Garamond',
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: colors.textSecondary.withValues(alpha: 0.9),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Editorial action prompts
                Column(
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
                        'Begin writing your first entry',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                          decoration: TextDecoration.underline,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'or',
                      style: TextStyle(
                        fontFamily: 'Cormorant Garamond',
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: colors.textSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                            AppTransitions.fade(const VoiceReflectionSurface(asTab: false)),
                          );
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Speak softly to record',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                          decoration: TextDecoration.underline,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineEditorialRow extends StatelessWidget {
  final JournalEntry entry;
  final ResolvedColors colors;
  final bool showYearDivider;
  final bool indent;

  const _TimelineEditorialRow({
    required this.entry,
    required this.colors,
    required this.showYearDivider,
    required this.indent,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(entry.createdAt).toUpperCase();
    final timeStr = DateFormat('h:mm a').format(entry.createdAt);
    
    // Impeccable: single editorial metadata string without database-like elements
    final metadataStr = entry.isVoiceEntry
        ? '$timeStr · ${entry.durationMinutes > 0 ? '${entry.durationMinutes}m ' : ''}voice narration'
        : timeStr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year Header Stamp (Atmospheric Print Aesthetic)
        if (showYearDivider) ...[
          Padding(
            padding: const EdgeInsets.only(top: 36.0, bottom: 16.0),
            child: Text(
              '${entry.createdAt.year}',
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 48,
                fontWeight: FontWeight.w200,
                color: colors.textSecondary.withValues(alpha: 0.12),
                letterSpacing: 4.0,
              ),
            ),
          ),
        ],

        // Asymmetrical padding and 95% borderless layout
        GestureDetector(
          onTap: () {
            AppHaptics.subtle();
            Navigator.push(
              context,
              AppTransitions.slideUp(MemoryDetailScreen(entry: entry)),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.only(left: indent ? 16.0 : 0.0),
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.hairline, width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Stamp Column
                SizedBox(
                  width: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr.split(' ')[1],
                        style: TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 28,
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
                
                // Memory Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title in Cormorant Garamond
                      Text(
                        entry.title.isEmpty ? 'Untitled Memory' : entry.title,
                        style: TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 21,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Preview text in Userselected body font (14sp)
                      Text(
                        entry.content.isEmpty
                            ? 'Speech transcription...'
                            : entry.content,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: colors.textSecondary.withValues(alpha: 0.8),
                          height: 1.55,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Metadata indicators (Time, Audio)
                      Text(
                        metadataStr,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: colors.textSecondary.withValues(alpha: 0.6),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
