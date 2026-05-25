import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_router.dart';
import 'processing_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Recording Screen — Real Speech-to-Text with Generative UI
// ═══════════════════════════════════════════════════════════════

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
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
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  String _currentWords = '';
  
  // ─── Cloud Fallback State ───
  final _audioRecorder = AudioRecorder();
  bool _usingCloudFallback = false;
  String? _recordedAudioPath;

  // ─── Recording Timer ───
  int _elapsedSeconds = 0;
  Timer? _recordingTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    // Request microphone permission gracefully
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      // If denied, we can't record. You could show a dialog here.
      return;
    }

    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' && !_isPaused) {
            // Auto-restart listening if it stops but we aren't paused
            _startListening();
          }
        },
        onError: (errorNotification) {
          debugPrint('STT Error: $errorNotification');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize STT: $e');
    }

    if (_speechEnabled) {
      _startRecordingTimer();
      _startListening();
    } else {
      // Fallback to recording raw audio for the cloud
      _usingCloudFallback = true;
      _startRecordingTimer();
      _startFakeWaveform();
      _startCloudAudioRecording();
    }
  }

  Future<void> _startCloudAudioRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/temp_journal_audio.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        _recordedAudioPath = path;
      }
    } catch (e) {
      debugPrint('Cloud audio recording failed: $e');
    }
  }

  void _startListening() async {
    if (!_speechEnabled || _isPaused) return;

    await _speechToText.listen(
      onResult: _onSpeechResult,
      onSoundLevelChange: _onSoundLevelChange,
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(hours: 1), // Listen as long as possible
        pauseFor: const Duration(seconds: 10), // Pause tolerance before stopping
        partialResults: true, // We want real-time updating text
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      String newWords = result.recognizedWords;
      
      // -- Voice Command Parsing --
      // Replace "new paragraph" with double newlines
      // ignore: valid_regexps
      newWords = newWords.replaceAll(RegExp('(?i)new paragraph'), '\n\n');
      
      // Replace "make that bold" (simple implementation: wrap last 3 words or previous sentence)
      // Since this is real-time, doing it robustly requires NLP. 
      // We will do a basic replace of the phrase with markdown on the preceding word.
      if (newWords.toLowerCase().contains('make that bold')) {
        // ignore: valid_regexps
        newWords = newWords.replaceAll(RegExp('(?i)make that bold'), '');
        // Bold the last word in the buffer
        final words = _lastRecognizedWords.trim().split(' ');
        if (words.isNotEmpty) {
          final lastWord = words.removeLast();
          _lastRecognizedWords = '${words.join(' ')} **$lastWord** ';
        }
      }
      
      // "Scratch that" removes the last phrase
      if (newWords.toLowerCase().contains('scratch that')) {
        // ignore: valid_regexps
        newWords = newWords.replaceAll(RegExp('(?i)scratch that'), '');
        // Remove the last 5 words from the buffer
        final words = _lastRecognizedWords.trim().split(' ');
        if (words.length > 5) {
          words.removeRange(words.length - 5, words.length);
          _lastRecognizedWords = '${words.join(' ')} ';
        } else {
          _lastRecognizedWords = ''; // Clear it if very short
        }
      }

      // Keep track of the full sentence as it builds up
      _currentWords = '$_lastRecognizedWords $newWords';
      if (result.finalResult) {
        _lastRecognizedWords = _currentWords;
      }
    });
  }

  void _onSoundLevelChange(double level) {
    if (!mounted) return;
    setState(() {
      _updateWaveformFromSoundLevel(level);
    });
  }

  void _updateWaveformFromSoundLevel(double level) {
    // level usually ranges from -50 (quiet) to 50 (loud). Normalize to 0.0 - 1.0
    final normalized = ((level + 50) / 100).clamp(0.0, 1.0);
    
    for (int i = 0; i < _waveHeights.length; i++) {
      final noise = _random.nextDouble() * 0.2;
      // Combine the actual sound level with some aesthetic wave math
      final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final base = (sin(t * 3.0 + i * 0.4) + 1) / 2;
      
      // If speaking (normalized > 0.4), make waves larger
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
        setState(() => _elapsedSeconds++);
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
    } else {
      _micPulseController.repeat(reverse: true);
      _startListening();
    }
  }

  Future<void> _navigateToProcessing() async {
    _stopListening();
    if (_usingCloudFallback && await _audioRecorder.isRecording()) {
      _recordedAudioPath = await _audioRecorder.stop();
    }

    if (!mounted) return;
    final appState = context.read<AppState>();
    appState.setRecording(false);
    appState.setProcessing(true);

    String transcribedText = _currentWords.trim();
    
    // If we used the cloud fallback, we need to upload the audio now
    if (_usingCloudFallback && _recordedAudioPath != null) {
      try {
        final result = await ApiRouter().execute(Feature.speechToText, {'audioPath': _recordedAudioPath});
        transcribedText = result.data['text'] ?? '';
      } catch (e) {
        transcribedText = 'Cloud transcription failed. Please try typing your entry instead.';
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
            ProcessingScreen(rawText: transcribedText),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (result == true && mounted) {
      appState.setProcessing(false);
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _speechToText.cancel();
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
      backgroundColor: AppColors.bgPrimary,
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
              child: Text('← Back', style: TextStyle(color: AppColors.accentPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Recording',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: _navigateToProcessing,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.accentPrimary, borderRadius: BorderRadius.circular(AppRadius.button)),
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
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
              decoration: BoxDecoration(color: AppColors.accentPrimary, shape: BoxShape.circle, boxShadow: AppShadows.glow),
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
              border: Border.all(color: AppColors.accentPrimary.withValues(alpha: opacity), width: 2),
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
                color: AppColors.accentPrimary.withValues(alpha: 0.5 + _waveHeights[index] * 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// The upgraded Gemini-like generative text UI
  Widget _buildGenerativeTranscriptionArea() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentWords.isEmpty
            ? Center(
                key: const ValueKey('empty'),
                child: Text(
                  'Just start talking...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : Text.rich(
                key: const ValueKey('text'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: _currentWords,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    ),
                    // Generative magical glowing cursor effect
                    WidgetSpan(
                      child: _GenerativeCursor(visible: _isListening && !_isPaused),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHelperText() {
    return Text(
      'Try: "New paragraph" · "Make that bold" · "Actually, scratch that"',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _togglePause,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                ),
                child: Text(
                  _isPaused ? '▶ Resume' : '⏸ Pause',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            GestureDetector(
              onTap: _navigateToProcessing,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(color: AppColors.accentPrimary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: const Text('Done →', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _formattedTime,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

class _AnimBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  const _AnimBuilder({required super.listenable, required this.builder});
  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ═══════════════════════════════════════════════════════════════
// Generative Cursor Widget (Gemini style)
// ═══════════════════════════════════════════════════════════════

class _GenerativeCursor extends StatefulWidget {
  final bool visible;
  const _GenerativeCursor({required this.visible});

  @override
  State<_GenerativeCursor> createState() => _GenerativeCursorState();
}

class _GenerativeCursorState extends State<_GenerativeCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.only(left: 4, bottom: 2),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPrimary.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ],
        ),
      ),
    );
  }
}
