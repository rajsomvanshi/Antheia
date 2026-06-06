
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../state/memory_state.dart';
import '../state/preferences_state.dart';
import '../state/voice_state.dart';
import '../state/memory_persistence_state.dart';
import '../state/app_orchestrator.dart';
import '../models/models.dart';
import '../services/voice_filter_service.dart';
import '../services/paywall_service.dart';
import 'processing_screen.dart';
import 'editor_surface.dart';
import 'paywall_sheet.dart';
import '../services/reflection_pipeline.dart';

// ═══════════════════════════════════════════════════════════════
// Voice Screen — Intimate, Emotional, Therapeutic
//
// States: IDLE → LISTENING → TRANSCRIBING → REFLECTION READY
// Top half: breathing orb. Bottom half: transcript or history.
// ═══════════════════════════════════════════════════════════════

enum _VoiceState { idle, listening, processing, transcribing }

class VoiceReflectionSurface extends StatefulWidget {
  final String? initialTranscription;
  final bool asTab;
  const VoiceReflectionSurface({super.key, this.initialTranscription, this.asTab = false});

  @override
  State<VoiceReflectionSurface> createState() => _VoiceReflectionSurfaceState();
}

class _VoiceReflectionSurfaceState extends State<VoiceReflectionSurface>
    with TickerProviderStateMixin {
  // ─── Animation ───
  late final AnimationController _breatheController;
  late final AnimationController _outerBreatheController;
  late final AnimationController _rippleController;

  // ─── Speech ───
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  String _accumulatedText = '';
  String _recognizedText = '';
  String _lastRecognizedWords = '';
  bool _isStartingListen = false;

  // ─── Audio recording ───
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioFilePath;

  // ─── Timer ───
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isPaused = false;

  // ─── Location ───
  double? _latitude;
  double? _longitude;
  bool _micPermDenied = false;

  // ─── Tab state ───
  bool _isActive = false;
  _VoiceState _voiceState = _VoiceState.idle;

  @override
  void initState() {
    super.initState();
    _accumulatedText = widget.initialTranscription ?? '';
    _recognizedText = _accumulatedText;

    // Slow breathing: 3s cycle
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Slower outer breathing: 5s cycle
    _outerBreatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    // Ripple
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    if (!widget.asTab) {
      _activate();
    }
  }

  Future<void> _activate() async {
    if (_isActive) return;

    final paywall = context.read<PaywallService>();
    final gate = paywall.checkGate(ProFeature.unlimitedEntries);
    if (gate != null) {
      final unlocked = await PaywallSheet.show(context, gate);
      if (!unlocked) {
        if (!widget.asTab && mounted) {
          Navigator.maybePop(context);
        }
        return;
      }
    }

    // AI Disclosure check
    final sharedPrefs = await SharedPreferences.getInstance();
    final hasShownAiDisclosure = sharedPrefs.getBool('ai_disclosure_shown') ?? false;
    if (!hasShownAiDisclosure) {
      if (mounted) {
        final consented = await _showAiDisclosureDialog(context);
        if (!consented) {
          if (!widget.asTab && mounted) {
            Navigator.maybePop(context);
          }
          return;
        }
        await sharedPrefs.setBool('ai_disclosure_shown', true);
      }
    }

    _isActive = true;
    setState(() => _voiceState = _VoiceState.processing);
    _requestPermissionsAndInit();
    _startRecordingTimer();
  }

  Future<bool> _showAiDisclosureDialog(BuildContext context) async {
    final colors = AppColors.of(context);
    final action = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.hairline, width: 0.5),
        ),
        title: Text(
          'AI Processing Consent',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        content: Text(
          'To generate structured reflections and themes, your voice transcriptions '
          'are processed using secure external AI services (such as Groq or Google Gemini).\n\n'
          'Your audio is never stored permanently on our servers, and your data is '
          'never sold or used for advertising. Do you consent to this AI processing?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No, Cancel',
              style: TextStyle(color: colors.textSecondary, fontFamily: 'Inter', fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Yes, I Consent',
              style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13),
            ),
          ),
        ],
      ),
    );
    return action ?? false;
  }

  Future<void> _requestPermissionsAndInit() async {
    _fetchLocation();
    final micStatus = await Permission.microphone.request();
    if (micStatus.isGranted) {
      await _initSpeech();
    } else if (micStatus.isPermanentlyDenied) {
      if (mounted) setState(() => _micPermDenied = true);
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final locPermission = await Geolocator.checkPermission();
      if (locPermission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied || result == LocationPermission.deniedForever) return;
      }
      if (locPermission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) setState(() { _latitude = position.latitude; _longitude = position.longitude; });
    } catch (e) {
      debugPrint('Location: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('isPremium') ?? false;

      if (!isPremium) {
        // Free user: try live STT first
        try {
          await _speech.cancel();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 80));

        _speechEnabled = await _speech.initialize(
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') && !_isPaused && mounted) {
              _accumulatedText = _recognizedText;
              _lastRecognizedWords = '';
              _isListening = false;
              _isStartingListen = false;
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!_isPaused && !_isStartingListen && mounted) _startListening();
              });
            }
          },
          onError: (err) {
            debugPrint('Speech error: $err');
            if (mounted) setState(() { _isStartingListen = false; _isListening = false; });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_isPaused && mounted) _startListening();
            });
          },
        );

        if (_speechEnabled) {
          await Future.delayed(const Duration(milliseconds: 600));
          _startListening();
          if (mounted) setState(() {});
          return;
        }
      }

      // Pro user OR Free user fallback: audio capture only + cloud STT
      debugPrint('[VoiceReflectionSurface] Running in audio-only capture mode');
      await _startAudioCapture();
      if (mounted) {
        setState(() => _voiceState = _VoiceState.listening);
        if (!isPremium) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Live transcription is unavailable right now. Your voice is still being recorded — tap Done when finished.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Speech init error: $e');
      await _startAudioCapture(); // Last-resort: at least capture audio
    }
    if (mounted) setState(() {});
  }

  Future<void> _startAudioCapture() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _audioFilePath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _audioFilePath!,
        );
      }
    } catch (e) {
      debugPrint('[VoiceReflectionSurface] audio capture failed: $e');
      _audioFilePath = null; // Graceful degradation
    }
  }

  void _startListening() async {
    if (!_speechEnabled || _isStartingListen || _isListening) return;
    _isStartingListen = true;
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final currentWords = result.recognizedWords.trim();
        if (currentWords.isEmpty) return;

        // If the new recognized words are shorter or completely different,
        // it means the speech recognizer has flushed its buffer and started a new phrase.
        if (_lastRecognizedWords.isNotEmpty && 
            (currentWords.length < _lastRecognizedWords.length || 
             !currentWords.startsWith(_lastRecognizedWords))) {
          // A silent flush occurred! Commit the previous phrase to _accumulatedText.
          if (_accumulatedText.isEmpty) {
            _accumulatedText = _lastRecognizedWords;
          } else {
            _accumulatedText = '$_accumulatedText $_lastRecognizedWords';
          }
        }

        _lastRecognizedWords = currentWords;
        setState(() {
          _voiceState = _VoiceState.transcribing;
          _recognizedText = _accumulatedText.isEmpty ? currentWords : '$_accumulatedText $currentWords';
          if (result.finalResult) {
            _accumulatedText = _recognizedText;
            _lastRecognizedWords = ''; // Reset for the next phrase
          }
        });
        
        // Autosave the accumulated transcript to our secure WAL SQLite storage!
        context.read<MemoryPersistenceState>().saveDraft(_recognizedText);
      },
      listenFor: const Duration(minutes: 60),
      pauseFor: const Duration(seconds: 10),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
    );
    if (mounted) {
      setState(() { _isListening = true; _isStartingListen = false; _voiceState = _VoiceState.listening; });
    } else {
      _isStartingListen = false;
    }
  }

  void _stopListening() async {
    _isStartingListen = false;
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _accumulatedText = _recognizedText;
        _lastRecognizedWords = '';
      });
    }
  }

  void _togglePause() async {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (_isPaused) {
      _stopListening();
      try {
        if (await _audioRecorder.isRecording()) {
          await _audioRecorder.pause();
        }
      } catch (e) {
        debugPrint('Failed to pause audio recorder: $e');
      }
      setState(() => _voiceState = _VoiceState.idle);
    } else {
      _startListening();
      try {
        if (await _audioRecorder.isPaused()) {
          await _audioRecorder.resume();
        }
      } catch (e) {
        debugPrint('Failed to resume audio recorder: $e');
      }
    }
  }

  void _startRecordingTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!_isPaused && mounted) {
        setState(() => _elapsedSeconds++);

        final paywall = context.read<PaywallService>();
        if (!paywall.isPro && _elapsedSeconds >= paywall.freeVoiceSeconds) {
          // Pause recording
          _togglePause();

          final unlocked = await PaywallSheet.show(context, ProFeature.voiceUnlimited);
          if (unlocked) {
            // User upgraded, resume recording
            _togglePause();
          } else {
            // User did not upgrade, stop recording and process what they have
            await _stopAndProcess();
          }
        }
      }
    });
  }

  String get _timerText {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _stopAndProcess() async {
    try {
      if (await _audioRecorder.isRecording() || await _audioRecorder.isPaused()) {
        final path = await _audioRecorder.stop();
        if (path != null) {
          _audioFilePath = path;
        }
      }
    } catch (e) {
      debugPrint('[VoiceReflectionSurface] audio stop failed: $e');
    }

    _stopListening();
    _timer?.cancel();
    String cleaned = VoiceFilterService.clean(_recognizedText);

    // ── FIX: When STT was unavailable, try cloud transcription on the audio ──
    if (cleaned.isEmpty && _audioFilePath != null) {
      try {
        final result = await ReflectionPipeline().execute(
          Feature.speechToText,
          {'audioPath': _audioFilePath},
        );
        cleaned = VoiceFilterService.clean(result.data['text'] as String? ?? '');
        debugPrint('[VoiceReflectionSurface] Cloud STT result: ${cleaned.length} chars');
      } catch (e) {
        debugPrint('[VoiceReflectionSurface] Cloud STT failed: $e');
      }
    }

    Navigator.of(context).pushReplacement(AppTransitions.fade(
      ProcessingScreen(
        rawText: cleaned.isEmpty ? 'No transcription recorded.' : cleaned,
        durationMinutes: math.max(1, _elapsedSeconds ~/ 60),
        latitude: _latitude,
        longitude: _longitude,
        audioPath: _audioFilePath,
      ),
    ));
  }

  Future<void> _handleBackOrClose() async {
    final persistState = context.read<MemoryPersistenceState>();
    if (_recognizedText.trim().isEmpty) {
      try {
        if (await _audioRecorder.isRecording() || await _audioRecorder.isPaused()) {
          await _audioRecorder.stop();
        }
        if (_audioFilePath != null) {
          final file = File(_audioFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (_) {}

      if (widget.asTab) {
        _stopListening();
        _timer?.cancel();
        setState(() {
          _isActive = false;
          _recognizedText = '';
          _accumulatedText = '';
          _elapsedSeconds = 0;
        });
      } else {
        Navigator.maybePop(context);
      }
      return;
    }

    final colors = AppColors.of(context);
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.hairline, width: 0.5),
        ),
        title: Text(
          'Unfinished Reflection',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        content: Text(
          'Would you like to finish and save your reflection before leaving?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.redAccent, fontFamily: 'Inter', fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary, fontFamily: 'Inter', fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(
              'Finish & Save',
              style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13),
            ),
          ),
        ],
      ),
    );

    if (action == 'save') {
      await _stopAndProcess();
    } else if (action == 'discard') {
      try {
        if (await _audioRecorder.isRecording() || await _audioRecorder.isPaused()) {
          await _audioRecorder.stop();
        }
        if (_audioFilePath != null) {
          final file = File(_audioFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (_) {}

      await persistState.clearDraft();
      _stopListening();
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _isActive = false;
          _recognizedText = '';
          _accumulatedText = '';
          _elapsedSeconds = 0;
        });
        if (!widget.asTab) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _outerBreatheController.dispose();
    _rippleController.dispose();
    _timer?.cancel();
    _speech.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tab idle state with recent reflections
    if (widget.asTab && !_isActive) {
      return _TabIdleState(onStart: _activate);
    }

    if (_micPermDenied) {
      return _PermissionDeniedState(
        onBack: () => widget.asTab
            ? setState(() { _isActive = false; _micPermDenied = false; })
            : Navigator.maybePop(context),
      );
    }

    final colors = AppColors.of(context);
    final prefs = context.watch<PreferencesState>();
    final type = AppType.of(context, fontOverride: prefs.selectedFont);

    // Make system UI overlay style theme-aware
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: prefs.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: prefs.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.bg,
        systemNavigationBarIconBrightness: prefs.isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return PopScope(
      canPop: _recognizedText.trim().isEmpty || !(_isActive && !widget.asTab),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackOrClose();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(colors, type),
              // Top half: orb
              Expanded(
                flex: 5,
                child: Center(child: _buildBreathingOrb(colors)),
              ),
              // Bottom half: transcript or "start speaking"
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  physics: const BouncingScrollPhysics(),
                  child: _buildTranscript(type),
                ),
              ),
              _buildControls(colors, type),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ResolvedColors colors, ResolvedType type) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleBackOrClose,
            child: Icon(Icons.close_rounded, color: colors.textTertiary, size: 22),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPaused ? colors.accent : colors.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isPaused ? 'Paused' : (_voiceState == _VoiceState.transcribing ? 'Transcribing' : 'Listening'),
                style: type.small.copyWith(color: _isPaused ? colors.accent : colors.success),
              ),
            ],
          ),
          const Spacer(),
          Text(_timerText, style: type.small),
        ],
      ),
    );
  }

  Widget _buildBreathingOrb(ResolvedColors colors) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breatheController, _outerBreatheController, _rippleController]),
      builder: (context, _) {
        final breathe = _isPaused ? 1.0 : 1.0 + 0.03 * _breatheController.value;
        final outerBreathe = _isPaused ? 1.0 : 1.0 + 0.05 * _outerBreatheController.value;
        final rippleVal = _rippleController.value;
        final isActive = _isListening && !_isPaused;

        return SizedBox(
          width: 200, height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ripple
              if (isActive)
                Transform.scale(
                  scale: 1.0 + 0.5 * rippleVal,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.06 * (1 - rippleVal)),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              // Inner pulse
              if (isActive)
                Transform.scale(
                  scale: 1.0 + 0.2 * rippleVal,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.04 * (1 - rippleVal)),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              // Secondary slower outer ring pulsing at 5s vs inner 3s for depth!
              Transform.scale(
                scale: outerBreathe,
                child: Container(
                  width: 164, height: 164,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                ),
              ),
              // Main orb
              Transform.scale(
                scale: breathe,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    border: Border.all(
                      color: isActive ? colors.accent.withValues(alpha: 0.3) : colors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.mic_none_outlined,
                    size: 36,
                    color: isActive ? colors.accent : colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscript(ResolvedType type) {
    if (_recognizedText.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Text(
          _isPaused ? 'Paused. Tap play to continue.' : 'Start speaking…',
          textAlign: TextAlign.center,
          style: type.bodySecondary,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        _recognizedText,
        textAlign: TextAlign.center,
        style: type.body.copyWith(
          fontSize: 17,
          height: 1.7,
        ),
      ),
    );
  }

  Widget _buildControls(ResolvedColors colors, ResolvedType type) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _togglePause,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface,
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: colors.text, size: 24,
              ),
            ),
          ),
          GestureDetector(
            onTap: _stopAndProcess,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Finish', style: type.body.copyWith(color: colors.bg, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text(_timerText, style: type.caption.copyWith(color: colors.bg.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Idle State with Recent Reflections ───────────────────
class _TabIdleState extends StatelessWidget {
  final VoidCallback onStart;
  const _TabIdleState({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<MemoryState>().entries;
    final voiceEntries = entries.where((e) => e.isVoiceEntry).take(4).toList();
    final colors = AppColors.of(context);
    final prefs = context.watch<PreferencesState>();
    final type = AppType.of(context, fontOverride: prefs.selectedFont);

    // Make system UI overlay style theme-aware
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: prefs.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: prefs.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.bg,
        systemNavigationBarIconBrightness: prefs.isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top half: orb
            Expanded(
              flex: 5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Voice', style: type.displayLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Record a memory\nwith your voice.',
                      textAlign: TextAlign.center,
                      style: type.bodySecondary,
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: () async {
                        final paywall = context.read<PaywallService>();
                        final gate = paywall.checkGate(ProFeature.unlimitedEntries);
                        if (gate != null) {
                          await PaywallSheet.show(context, gate);
                          return;
                        }
                        HapticFeedback.mediumImpact();
                        onStart();
                      },
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surface,
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(Icons.mic_none_outlined, size: 40, color: colors.accent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Tap to begin', style: type.caption),
                  ],
                ),
              ),
            ),
            // Bottom half: recent reflections
            if (voiceEntries.isNotEmpty)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECENT REFLECTIONS', style: type.label),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: voiceEntries.map((e) => _RecentReflection(entry: e)).toList(),
                        ),
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
}

class _RecentReflection extends StatelessWidget {
  final JournalEntry entry;
  const _RecentReflection({required this.entry});

  @override
  Widget build(BuildContext context) {
    final memoryState = Provider.of<MemoryState>(context, listen: false);
    final prefsState = Provider.of<PreferencesState>(context, listen: false);
    final time = DateFormat('EEEE').format(entry.createdAt);
    final dur = entry.durationMinutes > 0 ? '${entry.durationMinutes} min' : '';
    final colors = AppColors.of(context);
    final type = AppType.of(context, fontOverride: prefsState.selectedFont);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        memoryState.setCurrentEntry(entry);
        Navigator.push(
          context,
          AppTransitions.fade(EditorSurface(initialEntry: entry)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_none_outlined, size: 16, color: colors.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(entry.title, style: type.body, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('$time${dur.isNotEmpty ? ' · $dur' : ''}', style: type.small),
          ],
        ),
      ),
    );
  }
}

// ─── Permission Denied ────────────────────────────────────────
class _PermissionDeniedState extends StatelessWidget {
  final VoidCallback onBack;
  const _PermissionDeniedState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<PreferencesState>();
    final type = AppType.of(context, fontOverride: prefs.selectedFont);

    // Make system UI overlay style theme-aware
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: prefs.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: prefs.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.bg,
        systemNavigationBarIconBrightness: prefs.isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_off_outlined, size: 48, color: colors.textTertiary),
              const SizedBox(height: 24),
              Text('Microphone access needed', textAlign: TextAlign.center, style: type.displayMedium),
              const SizedBox(height: 12),
              Text(
                'Antheia needs your microphone\nto hold your voice.',
                textAlign: TextAlign.center,
                style: type.bodySecondary,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => openAppSettings(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(12)),
                  child: Text('Open Settings', style: type.body.copyWith(color: colors.bg, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(onTap: onBack, child: Text('Go back', style: type.caption)),
            ],
          ),
        ),
      ),
    );
  }
}
