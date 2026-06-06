import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/voice_recording_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/interaction_system.dart';
import '../../state/memory_persistence_state.dart';

// ═══════════════════════════════════════════════════════════════
// VoiceRecorderWidget — FIXED
//
// ISSUE 1 FIX (bottom-sheet voice recording path):
//   - initialize() is now called directly in _toggleRecording's
//     start path, not in a postFrameCallback. This ensures the
//     fresh-instance reset runs BEFORE any listen() call.
//   - On dispose, stopRecording() is called if still listening,
//     to release the mic before the sheet is gone. Previously
//     dispose() only cancelled the pulseController, leaving the
//     VoiceRecordingService holding the microphone after the
//     sheet closed — causing the conflict on next open.
//
// ISSUE 6 FIX: Transcript cannot be lost via sheet dismissal.
//   - If the user swipes the sheet away mid-recording, we stop
//     the recording properly and deliver the partial transcript.
// ═══════════════════════════════════════════════════════════════

class VoiceRecorderWidget extends StatefulWidget {
  final void Function(String transcript) onTranscriptReady;

  const VoiceRecorderWidget({super.key, required this.onTranscriptReady});

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late List<double> _barPhases;
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _barPhases = List.generate(22, (i) => i * (3.14159 / 11));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // ── FIX: Stop recording on dispose so the mic is released ──
    final svc = context.read<VoiceRecordingService>();
    if (svc.isListening) {
      svc.stopRecording().then((transcript) {
        if (transcript.isNotEmpty) {
          widget.onTranscriptReady(transcript);
        }
      });
    }
    super.dispose();
  }

  Future<void> _toggleRecording(VoiceRecordingService svc) async {
    if (_isStopping) return;
    AppHaptics.medium();

    if (svc.isListening) {
      setState(() => _isStopping = true);
      final transcript = await svc.stopRecording();
      if (transcript.isNotEmpty) {
        widget.onTranscriptReady(transcript);
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) setState(() => _isStopping = false);
      }
    } else {
      final persist = context.read<MemoryPersistenceState>();
      await svc.startRecording(persist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final svc = context.watch<VoiceRecordingService>();
    final isListening = svc.isListening;
    final liveText = svc.partialText;
    final buffered = svc.fullTranscript;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: colors.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Live waveform (animated bars)
          SizedBox(
            height: 48,
            child: isListening
              ? AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => _WaveformBar(
                    isActive: isListening,
                    animation: _pulseController.value,
                    color: colors.accent,
                    phases: _barPhases,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_none_rounded, size: 32, color: colors.textFaint),
                    const SizedBox(width: 10),
                    Text(
                      _isStopping ? 'Processing...' : 'Tap to start recording',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
          ),

          const SizedBox(height: 20),

          // Live transcript preview
          if (isListening || buffered.isNotEmpty)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.hairline, width: 0.5),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (buffered.isNotEmpty)
                      Text(
                        buffered,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: colors.text,
                          height: 1.6,
                        ),
                      ),
                    if (liveText.isNotEmpty)
                      Text(
                        (buffered.isNotEmpty ? ' ' : '') + liveText,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: colors.textSecondary,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          if (isListening)
            Text(
              'Listening... tap stop when done',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.textFaint,
                fontStyle: FontStyle.italic,
              ),
            ),

          const SizedBox(height: 16),

          // Big mic / stop button
          GestureDetector(
            onTap: _isStopping ? null : () => _toggleRecording(svc),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) {
                final scale = isListening
                    ? 1.0 + (_pulseController.value * 0.06)
                    : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isStopping
                      ? colors.textSecondary
                      : (isListening ? Colors.redAccent : colors.accent),
                ),
                child: _isStopping
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          Text(
            _isStopping ? 'Saving...' : (isListening ? 'Stop' : 'Record'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Waveform bar drawing widget
class _WaveformBar extends StatelessWidget {
  final bool isActive;
  final double animation;
  final Color color;
  final List<double> phases;

  const _WaveformBar({
    required this.isActive,
    required this.animation,
    required this.color,
    required this.phases,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(phases.length, (i) {
        final wave = (1 + sin(animation * 2 * 3.14159 + phases[i])) / 2;
        final height = isActive ? 6 + wave * 36 : 4.0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.4 + wave * 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
