import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/memory_state.dart';
import '../state/voice_state.dart';
import '../state/preferences_state.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'editor_surface.dart';
import 'new_home_shell.dart';

// ═══════════════════════════════════════════════════════════════
// ProcessingScreen — Voice entry post-processing
//
// P0 FIX: Added a 35-second wall-clock safety net around the
// entire processVoiceEntry() call. Even if MemoryEnrichmentService
// somehow hangs beyond its own 30s timeout (e.g. Dart Future
// scheduler starvation), this screen will never be stuck longer
// than 35s. The user's transcript is always preserved via the
// fallback entry in processVoiceEntry().
// ═══════════════════════════════════════════════════════════════

/// Safety-net: if processVoiceEntry takes longer than this we
/// navigate directly to the editor with the raw transcript.
const _kProcessingWallTimeout = Duration(seconds: 35);

class ProcessingScreen extends StatefulWidget {
  final String rawText;
  final int durationMinutes;
  final double? latitude;
  final double? longitude;
  final String? audioPath;

  const ProcessingScreen({
    super.key,
    required this.rawText,
    this.durationMinutes = 0,
    this.latitude,
    this.longitude,
    this.audioPath,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _atmosphere;
  late final AnimationController _breatheController;
  late final Animation<double> _dotScale;
  late final Animation<double> _dotOpacity;

  bool _isDone = false;
  String? _error;

  // Safety-net timer — dismissed once _run() finishes naturally.
  Timer? _wallClockTimer;

  @override
  void initState() {
    super.initState();

    // Slow drift atmospheric background
    _atmosphere = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat(reverse: true);

    // Dynamic Phase 2 breathing loop (2.5 seconds)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _dotScale = Tween<double>(begin: 8.0, end: 32.0).animate(
      CurvedAnimation(
        parent: _breatheController,
        curve: Curves.easeInOut,
      ),
    );

    _dotOpacity = Tween<double>(begin: 1.0, end: 0.15).animate(
      CurvedAnimation(
        parent: _breatheController,
        curve: Curves.easeInOut,
      ),
    );

    // ─── Safety-net: bail out after 35s regardless ────────────
    // This fires if processVoiceEntry() hangs beyond its own
    // internal timeout (should never happen, but defensive belt).
    _wallClockTimer = Timer(_kProcessingWallTimeout, () {
      debugPrint(
          '[ProcessingScreen] WALL-CLOCK TIMEOUT: force-creating local entry.');
      if (!mounted) return;
      _navigateWithRawTranscript();
    });

    _run();
  }

  Future<void> _run() async {
    final memoryState = context.read<MemoryState>();
    final voiceState = context.read<VoiceState>();
    final prefsState = context.read<PreferencesState>();

    final entry = await memoryState.processVoiceEntry(
      rawText: widget.rawText,
      latitude: widget.latitude,
      longitude: widget.longitude,
      durationMinutes: widget.durationMinutes,
      voiceState: voiceState,
      tone: prefsState.reflectionTone,
      formatting: prefsState.autoFormatting,
      audioPath: widget.audioPath,
    );

    // If we got here, wall-clock timer is no longer needed.
    _wallClockTimer?.cancel();

    if (!mounted) return;
    if (entry != null) {
      setState(() => _isDone = true);
      final delay = AnimationScale.of(context) == AnimationIntensity.stillness
          ? Duration.zero
          : const Duration(milliseconds: 900);
      await Future.delayed(delay);
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(AppTransitions.fade(EditorSurface(initialEntry: entry)));
    } else {
      // processVoiceEntry returned null (shouldn't happen post-fix,
      // but handle gracefully).
      _navigateWithRawTranscript();
    }
  }

  /// Fallback: build a minimal entry from the raw transcript and
  /// open the editor immediately. User words are NEVER lost.
  void _navigateWithRawTranscript() {
    _wallClockTimer?.cancel();
    if (!mounted) return;

    final now = DateTime.now();
    final fallbackEntry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Voice Reflection',
      content: widget.rawText,
      createdAt: now,
      updatedAt: now,
      mood: Mood.neutral,
      durationMinutes: widget.durationMinutes,
      isVoiceEntry: true,
      sections: [EntrySection(type: 'paragraph', content: widget.rawText)],
      blocks: [
        VoiceBlock(
          transcript: widget.rawText,
          duration: Duration(minutes: widget.durationMinutes),
          audioPath: widget.audioPath,
        )
      ],
    );

    // Also persist it so it survives even if the editor is closed.
    context.read<MemoryState>().addEntry(fallbackEntry);

    Navigator.of(context).pushReplacement(
      AppTransitions.fade(EditorSurface(initialEntry: fallbackEntry)),
    );
  }

  @override
  void dispose() {
    _wallClockTimer?.cancel();
    _atmosphere.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = AppType.of(context);
    final still = AnimationScale.of(context) == AnimationIntensity.stillness;

    return Scaffold(
      backgroundColor: colors.bg,
      body: AnimatedBuilder(
        animation: _atmosphere,
        builder: (context, child) {
          return CustomPaint(
            painter: _SettlingPainter(
              colors: colors,
              t: still ? 0.0 : _atmosphere.value,
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: _error == null
                ? _buildSettlingContent(colors)
                : _buildError(type, colors),
          ),
        ),
      ),
    );
  }

  Widget _buildSettlingContent(ResolvedColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Centered gold dot breathing dynamically
          SizedBox(
            width: 36,
            height: 36,
            child: AnimatedBuilder(
              animation: _breatheController,
              builder: (context, child) {
                return Center(
                  child: Container(
                    width: _dotScale.value,
                    height: _dotScale.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent.withValues(alpha: _dotOpacity.value),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          
          // Coordinated breathing status text
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) {
              final textOpacity = 0.4 + (_dotOpacity.value * 0.55);
              return Opacity(
                opacity: textOpacity,
                child: Text(
                  _isDone ? 'Memory preserved.' : 'Connecting this reflection to your library...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cormorant Garamond',
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: colors.accent,
                    height: 1.5,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildError(ResolvedType type, ResolvedColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Something interrupted.',
            textAlign: TextAlign.center,
            style: type.readingTitle.copyWith(
              fontSize: 23,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: type.bodySecondary.copyWith(height: 1.6),
          ),
          const SizedBox(height: 34),
          InkWell(
            onTap: () => Navigator.of(context)
                .pushReplacement(AppTransitions.fade(const NewHomeShell())),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                'Return home',
                style: type.body.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlingPainter extends CustomPainter {
  final ResolvedColors colors;
  final double t;

  const _SettlingPainter({required this.colors, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = colors.bg);

    final warm = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.05, -0.34 + t * 0.04),
        radius: 1.05,
        colors: [
          colors.accent.withValues(alpha: 0.035 + t * 0.018),
          colors.accent.withValues(alpha: 0.010),
          Colors.transparent,
        ],
        stops: const [0, 0.48, 1],
      ).createShader(rect);
    canvas.drawRect(rect, warm);

    final shade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: const Alignment(0, 0.2),
        colors: [
          Colors.black.withValues(alpha: 0.045 - t * 0.015),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, shade);
  }

  @override
  bool shouldRepaint(_SettlingPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.colors != colors;
}
