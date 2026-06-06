import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/narration_service.dart';
import '../state/memory_state.dart';
import '../state/preferences_state.dart';
import '../theme/app_theme.dart';
import '../theme/interaction_system.dart';
import 'editor_surface.dart';

import '../services/paywall_service.dart';
import 'paywall_sheet.dart';

class MemoryDetailScreen extends StatefulWidget {
  final JournalEntry entry;

  const MemoryDetailScreen({super.key, required this.entry});

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  late JournalEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<PreferencesState>();
    final type = AppType.of(context, fontOverride: prefs.selectedFont);
    final narration = context.watch<NarrationService>();

    final isCurrent = narration.currentEntryId == _entry.id;
    final isPlaying = isCurrent && narration.state == NarrationState.playing;
    final isPaused = isCurrent && narration.state == NarrationState.paused;

    final dateStr = DateFormat('MMMEEEEd').format(_entry.createdAt).toUpperCase();
    final timeStr = DateFormat('h:mm a').format(_entry.createdAt);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // Cinematic subtle paper grain overlay
          const Positioned.fill(
            child: IgnorePointer(
              child: CinematicGrain(seed: 4, animate: false),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Quiet Navigation Header
                _buildHeader(context, colors, type),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    children: [
                      // Date & Meta
                      Text(
                        '$dateStr · $timeStr',
                        style: type.small.copyWith(
                          color: colors.accent,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Title
                      Text(
                        _entry.title.isEmpty ? 'Untitled Memory' : _entry.title,
                        style: type.readingTitle.copyWith(
                          fontSize: 28,
                          color: colors.text,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Hairline Divider
                      Divider(color: colors.hairline, height: 0.5),
                      const SizedBox(height: 24),

                      // Optional Media box
                      if (_entry.thumbnailPath != null || _entry.photoUrls.isNotEmpty) ...[
                        _buildMediaBox(_entry.thumbnailPath ?? _entry.photoUrls.first, colors),
                        const SizedBox(height: 24),
                        Divider(color: colors.hairline, height: 0.5),
                        const SizedBox(height: 24),
                      ],

                      // Optional Voice playback bar
                      if (_entry.isVoiceEntry || _entry.blocks.any((b) => b is VoiceBlock)) ...[
                        _buildVoicePlaybackBar(narration, isPlaying, isPaused, colors, type),
                        const SizedBox(height: 24),
                        Divider(color: colors.hairline, height: 0.5),
                        const SizedBox(height: 24),
                      ],

                      // Printed paragraph look with indented body content
                      _buildBodyContent(type, colors),

                      // Connected themes / tags section
                      if (_entry.tags.isNotEmpty) ...[
                        const SizedBox(height: 36),
                        Divider(color: colors.hairline, height: 0.5),
                        const SizedBox(height: 24),
                        _buildConnections(colors, type),
                      ],
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ResolvedColors colors, ResolvedType type) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              AppHaptics.subtle();
              Navigator.of(context).pop();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 13,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Back',
                    style: type.small.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Impeccable Edit Path Button
          GestureDetector(
            onTap: () async {
              AppHaptics.light();
              final memoryState = context.read<MemoryState>();
              memoryState.setCurrentEntry(_entry);
              await Navigator.push(
                context,
                AppTransitions.fade(EditorSurface(initialEntry: _entry)),
              );
              // Refresh details upon exit of editor
              final refreshed = memoryState.entries.firstWhere(
                (e) => e.id == _entry.id,
                orElse: () => _entry,
              );
              setState(() {
                _entry = refreshed;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Edit',
                style: type.small.copyWith(
                  color: colors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaBox(String path, ResolvedColors colors) {
    final isLocal = !path.startsWith('http') && !path.startsWith('assets/');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: colors.hairline, width: 0.5),
      ),
      child: ClipRect(
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: isLocal
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: colors.surface,
                    child: Icon(Icons.broken_image_outlined, color: colors.textSecondary),
                  ),
                )
              : Image.network(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: colors.surface,
                    child: Icon(Icons.broken_image_outlined, color: colors.textSecondary),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildVoicePlaybackBar(
    NarrationService narration,
    bool isPlaying,
    bool isPaused,
    ResolvedColors colors,
    ResolvedType type,
  ) {
    final progress = (isPlaying || isPaused) && narration.totalSentences > 0
        ? (narration.currentIndex / narration.totalSentences)
        : 0.0;

    final durationText = _entry.durationMinutes > 0
        ? '${_entry.durationMinutes.toString().padLeft(2, '0')}:00'
        : '01:42';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 11,
              color: colors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              'EDITORIAL NARRATION',
              style: type.small.copyWith(
                color: colors.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final paywall = context.read<PaywallService>();
                final gate = paywall.checkGate(ProFeature.narration);
                if (gate != null) {
                  await PaywallSheet.show(context, gate);
                  return;
                }
                AppHaptics.light();
                if (isPlaying) {
                  narration.pause();
                } else if (isPaused) {
                  narration.resume();
                } else {
                  final prefs = context.read<PreferencesState>();
                  narration.speakEntry(
                    _entry.id,
                    _entry.title,
                    _entry.content,
                    speed: prefs.ttsSpeed,
                    pitch: prefs.ttsPitch,
                  );
                }
              },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.hairline, width: 0.5),
              color: colors.surface,
            ),
            child: Icon(
              isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 18,
              color: isPlaying ? colors.accent : colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Linear tracking slider
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 2,
                width: double.infinity,
                color: colors.hairline,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                width: double.infinity,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Monospace timeline elapsed index / duration
        Text(
          durationText,
          style: GoogleFonts.shareTechMono(
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
      ],
    ),
  ],
);
}

  Widget _buildBodyContent(ResolvedType type, ResolvedColors colors) {
    if (_entry.content.isEmpty) {
      return Text(
        'Empty reflection.',
        style: type.readingBodySecondary.copyWith(fontStyle: FontStyle.italic),
      );
    }

    // Process blocks first or fall back to standard text content
    if (_entry.blocks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _entry.blocks.map((block) {
          if (block is TextBlock) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                block.text,
                style: type.readingBody.copyWith(
                  color: colors.text,
                  height: 1.6,
                ),
              ),
            );
          } else if (block is VoiceBlock) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                block.transcript,
                style: type.readingBodySecondary.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
            );
          } else if (block is ReflectionBlock) {
            // Invisible AI curator styling per Design Review
            return Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
              child: Text(
                block.content,
                style: type.readingBodySecondary.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colors.accent,
                  height: 1.65,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }).toList(),
      );
    }

    // Standard fallback paragraph styling
    final paragraphs = _entry.content.split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            para,
            style: type.readingBody.copyWith(
              color: colors.text,
              height: 1.6,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConnections(ResolvedColors colors, ResolvedType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONNECTED THEMES',
          style: type.label.copyWith(
            color: colors.accent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _entry.tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: colors.hairline, width: 0.5),
                color: colors.surface,
              ),
              child: Text(
                tag,
                style: type.small.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
