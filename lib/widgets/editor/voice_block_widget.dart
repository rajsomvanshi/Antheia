import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/memory_block.dart';
import '../../theme/app_theme.dart';

class VoiceBlockWidget extends StatefulWidget {
  final VoiceBlock block;
  final ValueChanged<String>? onTranscriptChanged;

  const VoiceBlockWidget({
    super.key,
    required this.block,
    this.onTranscriptChanged,
  });

  @override
  State<VoiceBlockWidget> createState() => _VoiceBlockWidgetState();
}

class _VoiceBlockWidgetState extends State<VoiceBlockWidget>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _hasAudio = false;
  late final AnimationController _waveController;

  // Editing state
  bool _isEditing = false;
  late final TextEditingController _editController;
  late final FocusNode _editFocusNode;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _hasAudio = _audioFileExists();

    _editController = TextEditingController(text: widget.block.transcript);
    _editFocusNode = FocusNode();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing &&
          state.processingState != ProcessingState.completed;
      setState(() => _isPlaying = playing);
      if (playing) {
        _waveController.repeat(reverse: true);
      } else {
        _waveController.stop();
        _waveController.reset();
      }
    });
  }

  bool _audioFileExists() {
    final path = widget.block.audioPath;
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('http://') || path.startsWith('https://')) return true;
    return File(path).existsSync();
  }

  @override
  void didUpdateWidget(VoiceBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.audioPath != widget.block.audioPath) {
      setState(() {
        _hasAudio = _audioFileExists();
      });
    }
    if (oldWidget.block.transcript != widget.block.transcript && !_isEditing) {
      _editController.text = widget.block.transcript;
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _waveController.dispose();
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (!_hasAudio) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      try {
        final path = widget.block.audioPath!;
        if (path.startsWith('http://') || path.startsWith('https://')) {
          await _player.setUrl(path);
        } else {
          await _player.setFilePath(path);
        }
        await _player.play();
      } catch (e) {
        debugPrint('[VoiceBlockWidget] Playback error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = AppType.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play/pause button
              GestureDetector(
                onTap: _hasAudio ? _togglePlayback : null,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _hasAudio ? colors.accent : colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: _hasAudio ? colors.bg : colors.textFaint,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Waveform
              Expanded(
                child: _isPlaying
                    ? _AnimatedWave(
                        controller: _waveController,
                        color: colors.accent,
                      )
                    : _StaticWave(color: colors.borderLight),
              ),
              const SizedBox(width: 12),

              // Duration
              Text(
                _formatDuration(widget.block.duration),
                style: type.label.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          if (widget.block.transcript.isNotEmpty || widget.onTranscriptChanged != null) ...[
            const SizedBox(height: 16),
            _isEditing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _editController,
                        focusNode: _editFocusNode,
                        maxLines: null,
                        style: type.body.copyWith(
                          color: colors.text,
                          height: 1.6,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Edit transcript...',
                          hintStyle: TextStyle(color: colors.textFaint),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: colors.textSecondary,
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _editController.text = widget.block.transcript;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_rounded, size: 18),
                            color: colors.accent,
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                              });
                              widget.onTranscriptChanged?.call(_editController.text.trim());
                            },
                          ),
                        ],
                      )
                    ],
                  )
                : GestureDetector(
                    onTap: widget.onTranscriptChanged != null
                        ? () {
                            setState(() {
                              _isEditing = true;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _editFocusNode.requestFocus();
                            });
                          }
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.block.transcript.isNotEmpty
                                ? widget.block.transcript
                                : 'Tap to add transcript...',
                            style: type.body.copyWith(
                              color: widget.block.transcript.isNotEmpty
                                  ? colors.text
                                  : colors.textFaint,
                              height: 1.6,
                            ),
                          ),
                        ),
                        if (widget.onTranscriptChanged != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: colors.textFaint,
                          ),
                        ],
                      ],
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '0:00';
    final mins = d.inMinutes;
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

// Static waveform — deterministic varying heights so it looks real
class _StaticWave extends StatelessWidget {
  final Color color;
  const _StaticWave({required this.color});
  static const _heights = [
    4.0, 8.0, 14.0, 10.0, 18.0, 7.0, 20.0, 12.0, 16.0,
    6.0, 14.0, 10.0, 8.0, 18.0, 13.0, 8.0, 5.0, 11.0,
    15.0, 9.0, 20.0, 7.0, 12.0,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _heights.map((h) => Container(
          width: 2.5,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        )).toList(),
      ),
    );
  }
}

// Animated waveform during playback
class _AnimatedWave extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  const _AnimatedWave({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(23, (i) {
              final phase = i * (pi / 11.5);
              final h = 4.0 +
                  (sin(controller.value * 2 * pi + phase) + 1) / 2 * 18;
              return Container(
                width: 2.5,
                height: h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
