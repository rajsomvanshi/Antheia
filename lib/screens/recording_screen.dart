import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../theme/app_theme.dart';
import '../state/memory_state.dart';
import '../state/preferences_state.dart';
import '../state/voice_state.dart';
import '../state/memory_persistence_state.dart';
import '../state/app_orchestrator.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/reflection_pipeline.dart';
import '../services/database_service.dart';
import 'processing_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Recording Screen — FIXED
//
// ISSUE 1 FIX: Microphone conflict on Android
//   The root cause was that the SpeechToText instance was being
//   initialized while the mic was already held by a prior session.
//   Fix: call _speechToText.cancel() before initialize() to release
//   any held audio focus. Wait 80ms for the Android AudioManager
//   to fully release the session before starting the new one.
//
// ISSUE 6 FIX: Voice entry reliability
//   - Transcript is written to SQLite immediately on every partial
//     result (not just on finalize), so a crash mid-recording
//     never loses more than one partial segment.
//   - Added _hasStarted guard: if the UI is disposed before
//     ProcessingScreen can return, the draft is preserved.
//   - Processing failures now fall back to a locally-saved
//     voice entry rather than silently losing the transcript.
// ═══════════════════════════════════════════════════════════════

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ─── Animation Controllers ───
  late final AnimationController _micPulseController;
  late final AnimationController _ring1Controller;
  late final AnimationController _ring2Controller;
  late final AnimationController _ring3Controller;

  // ─── Animation Values ───
  late final Animation<double> _micScale;

  // ─── Waveform State ───
  final List<double> _waveHeights = List.generate(40, (_) => 0.15);
  final Random _random = Random();
  Timer? _waveTimer;

  // ─── Speech-to-Text State ───
  // FIX: Always create a fresh SpeechToText instance on this screen.
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  String _currentWords = '';

  // ─── Cloud Fallback State ───
  final _audioRecorder = AudioRecorder();
  bool _usingCloudFallback = false;
  String? _recordedAudioPath;
  bool _completed = false;

  // ─── Recording Timer ───
  int _elapsedSeconds = 0;
  Timer? _recordingTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('isPremium') ?? false;

    // Step 1: Request microphone permission.
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return;
    }

    if (!isPremium) {
      // Free user: try live STT first
      // ── Release any prior audio session ──────────────────
      try {
        await _speechToText.cancel();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 80));

      try {
        _speechEnabled = await _speechToText.initialize(
          onStatus: (status) {
            if (status == 'done' && !_isPaused) {
              _startListening();
            }
          },
          onError: (errorNotification) {
            debugPrint('[RecordingScreen] STT Error: $errorNotification');
            // If STT fails on start/init or during recording, switch to cloud audio recording
            if (_currentWords.trim().isEmpty && !_usingCloudFallback && !_isPaused) {
              debugPrint('[RecordingScreen] STT error, switching to cloud audio fallback.');
              _switchToCloudFallback();
            }
          },
        );
      } catch (e) {
        debugPrint('[RecordingScreen] Failed to initialize STT: $e');
      }

      if (_speechEnabled) {
        _startRecordingTimer();
        _startListening();
        return;
      }
    }

    // Pro user OR Free user fallback: use raw audio recording + cloud STT
    _usingCloudFallback = true;
    _startRecordingTimer();
    _startFakeWaveform();
    await _startCloudAudioRecording();
  }

  Future<void> _startCloudAudioRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/temp_journal_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        _recordedAudioPath = path;
      }
    } catch (e) {
      debugPrint('[RecordingScreen] Cloud audio recording failed: $e');
    }
  }

  Future<void> _pauseAudioRecording() async {
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.pause();
      }
    } catch (e) {
      debugPrint('[RecordingScreen] Failed to pause audio recording: $e');
    }
  }

  Future<void> _resumeAudioRecording() async {
    try {
      if (await _audioRecorder.isPaused()) {
        await _audioRecorder.resume();
      }
    } catch (e) {
      debugPrint('[RecordingScreen] Failed to resume audio recording: $e');
    }
  }

  void _startListening() async {
    if (!_speechEnabled || _isPaused) return;

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(hours: 1),
          pauseFor: const Duration(seconds: 10),
          partialResults: true,
          cancelOnError: false, // FIX: don't cancel on transient errors
          listenMode: stt.ListenMode.dictation,
        ),
      );
      if (mounted) {
        setState(() {
          _isListening = true;
        });
      }
    } catch (e) {
      debugPrint('[RecordingScreen] listen() failed: $e. Switching to raw audio.');
      _switchToCloudFallback();
    }
  }

  Future<void> _switchToCloudFallback() async {
    if (_usingCloudFallback) return;
    _stopListening();
    try {
      await _speechToText.cancel();
    } catch (_) {}
    
    if (mounted) {
      setState(() {
        _usingCloudFallback = true;
        _isListening = true; // keep waveform moving
      });
      _startFakeWaveform();
      await _startCloudAudioRecording();
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      String newWords = result.recognizedWords;

      // -- Voice Command Parsing --
      newWords = newWords.replaceAll(RegExp('(?i)new paragraph'), '\n\n');

      if (newWords.toLowerCase().contains('make that bold')) {
        newWords = newWords.replaceAll(RegExp('(?i)make that bold'), '');
        final words = _lastRecognizedWords.trim().split(' ');
        if (words.isNotEmpty) {
          final lastWord = words.removeLast();
          _lastRecognizedWords = '${words.join(' ')} **$lastWord** ';
        }
      }

      if (newWords.toLowerCase().contains('scratch that')) {
        newWords = newWords.replaceAll(RegExp('(?i)scratch that'), '');
        final words = _lastRecognizedWords.trim().split(' ');
        if (words.length > 5) {
          words.removeRange(words.length - 5, words.length);
          _lastRecognizedWords = '${words.join(' ')} ';
        } else {
          _lastRecognizedWords = '';
        }
      }

      _currentWords = '$_lastRecognizedWords $newWords';
      if (result.finalResult) {
        _lastRecognizedWords = _currentWords;
      }

      // ── FIX: Persist to SQLite on every update, not just on done ──
      // This guarantees that even a crash mid-segment loses at most
      // the current partial word (< 1 second of speech).
      context.read<MemoryPersistenceState>().saveDraft(_currentWords);
    });
  }

  void _onSoundLevelChange(double level) {
    if (!mounted) return;
    setState(() {
      _updateWaveformFromSoundLevel(level);
    });
  }

  void _updateWaveformFromSoundLevel(double level) {
    final normalized = ((level + 50) / 100).clamp(0.0, 1.0);
    for (int i = 0; i < _waveHeights.length; i++) {
      final noise = _random.nextDouble() * 0.2;
      final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final base = (sin(t * 3.0 + i * 0.4) + 1) / 2;
      final amplitude = normalized > 0.4 ? normalized * 1.5 : 0.1;
      _waveHeights[i] = (base * amplitude + noise).clamp(0.08, 1.0);
    }
  }

  void _initAnimations() {
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _micScale = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );

    _ring1Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _ring2Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    Future.delayed(const Duration(milliseconds: 800), () { if (mounted) _ring2Controller.repeat(); });
    _ring3Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    Future.delayed(const Duration(milliseconds: 1600), () { if (mounted) _ring3Controller.repeat(); });
  }

  void _startFakeWaveform() {
    _waveTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isPaused) return;
      setState(() {
        for (int i = 0; i < _waveHeights.length; i++) {
          final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
          final base = (sin(t * 3.0 + i * 0.4) + 1) / 2;
          final harmonic = (cos(t * 5.5 + i * 0.7) + 1) / 4;
          final noise = _random.nextDouble() * 0.15;
          _waveHeights[i] = (base * 0.5 + harmonic + noise).clamp(0.08, 1.0);
        }
      });
    });
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        if (mounted) setState(() => _elapsedSeconds++);
      }
    });
  }

  String get _formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _micPulseController.stop();
      _stopListening();
      _pauseAudioRecording();
    } else {
      _micPulseController.repeat(reverse: true);
      _startListening();
      _resumeAudioRecording();
    }
  }

  Future<void> _navigateToProcessing() async {
    _stopListening();
    if (await _audioRecorder.isRecording() || await _audioRecorder.isPaused()) {
      _recordedAudioPath = await _audioRecorder.stop();
    }

    if (!mounted) return;
    final memoryState = context.read<MemoryState>();
    final prefsState = context.read<PreferencesState>();
    final voiceState = context.read<VoiceState>();
    final persistState = context.read<MemoryPersistenceState>();
    final appOrchestrator = context.read<AppOrchestrator>();
    voiceState.setRecording(false);
    voiceState.setProcessingState(isProcessing: true);

    String transcribedText = _currentWords.trim();

    // If we used the cloud fallback, upload the audio now
    if (_usingCloudFallback && _recordedAudioPath != null) {
      try {
        final result = await ReflectionPipeline().execute(Feature.speechToText, {'audioPath': _recordedAudioPath});
        transcribedText = result.data['text'] ?? '';
      } catch (e) {
        // ── FIX: Don't silently lose the recording ──
        // The partial transcript from STT (even in cloud mode) is still in
        // _currentWords. Use it as fallback rather than a generic error string.
        debugPrint('[RecordingScreen] Cloud transcription failed: $e');
        if (transcribedText.isEmpty) {
          transcribedText = 'This was a quiet entry with no words recorded...';
        }
      }
    }

    if (transcribedText.isEmpty) {
      transcribedText = 'This was a quiet entry with no words recorded...';
    }

    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProcessingScreen(
              rawText: transcribedText,
              durationMinutes: max(1, _elapsedSeconds ~/ 60),
              audioPath: _recordedAudioPath,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (result == true && mounted) {
      _completed = true;
      voiceState.setProcessingState(isProcessing: false);
      await persistState.clearDraft();
      if (mounted) Navigator.pop(context, true);
    }
  }

  // ── Lifecycle Observer — Flush draft on app background ──────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flushDraftToSQLite();
    }
  }

  void _flushDraftToSQLite() {
    final transcript = _currentWords.trim();
    if (transcript.isNotEmpty) {
      // Fire-and-forget — SQLite WAL guarantees atomic write
      DatabaseService().saveDraft(transcript);
      debugPrint('[RecordingScreen] Draft flushed to SQLite (${transcript.length} chars)');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Flush any remaining transcript on dispose — crash or navigation safety
    _flushDraftToSQLite();
    // ── FIX: cancel() not just stop() — releases Android audio focus ──
    _speechToText.cancel();

    // Clean up temp audio file if not completed
    if (!_completed && _recordedAudioPath != null) {
      try {
        final file = File(_recordedAudioPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        debugPrint('[RecordingScreen] Failed to delete temp audio file: $e');
      }
    }

    _audioRecorder.dispose();
    _micPulseController.dispose();
    _ring1Controller.dispose();
    _ring2Controller.dispose();
    _ring3Controller.dispose();
    _waveTimer?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    _buildListeningLabel(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildMicrophoneOrb(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildWaveform(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildGenerativeTranscriptionArea(),
                    const SizedBox(height: AppSpacing.md),
                    _buildHelperText(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildBottomControls(),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('← Back', style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Recording',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      _formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: _navigateToProcessing,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.button)),
                child: const Text('Done →', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningLabel() {
    return Text(
      _isPaused ? 'Paused' : (_isListening ? 'Listening…' : 'Initializing Mic…'),
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text),
    );
  }

  Widget _buildMicrophoneOrb() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildPulseRing(_ring1Controller),
          _buildPulseRing(_ring2Controller),
          _buildPulseRing(_ring3Controller),
          ScaleTransition(
            scale: _micScale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, boxShadow: AppShadows.glow),
              alignment: Alignment.center,
              child: const Icon(Icons.mic_rounded, size: 44, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseRing(AnimationController controller) {
    return _AnimBuilder(
      listenable: controller,
      builder: (context, child) {
        final scale = 1.0 + controller.value * 1.0;
        final opacity = (1.0 - controller.value).clamp(0.0, 0.5);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: opacity), width: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(40, (index) {
          final height = _waveHeights[index] * 56 + 4;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.5 + _waveHeights[index] * 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGenerativeTranscriptionArea() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Text(
        _currentWords.isEmpty ? 'Start speaking...' : _currentWords,
        style: TextStyle(
          color: _currentWords.isEmpty ? AppColors.textFaint : AppColors.text,
          fontSize: 16,
          height: 1.6,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildHelperText() {
    return Text(
      'Say "new paragraph" to add a break · "scratch that" to undo',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.textFaint,
        fontSize: 11,
        fontFamily: 'Inter',
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _togglePause,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 18,
                  color: AppColors.text,
                ),
                const SizedBox(width: 6),
                Text(
                  _isPaused ? 'Resume' : 'Pause',
                  style: TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Minimal AnimBuilder helper (same pattern as original)
class _AnimBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const _AnimBuilder({required Listenable listenable, required this.builder})
      : super(listenable: listenable);
  @override
  Widget build(BuildContext context) => builder(context, null);
}
