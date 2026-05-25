import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'processing_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Aurora Voice Screen — Premium Fluid Wave + Live Speech
// ═══════════════════════════════════════════════════════════════

class AuroraVoiceScreen extends StatefulWidget {
  final String? initialTranscription;
  const AuroraVoiceScreen({super.key, this.initialTranscription});

  @override
  State<AuroraVoiceScreen> createState() => _AuroraVoiceScreenState();
}

class _AuroraVoiceScreenState extends State<AuroraVoiceScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ───
  late final AnimationController _waveController;
  late final AnimationController _pulseController;

  // ─── Speech to Text ───
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  // ─── Dual-buffer accumulation ───────────────────────────────
  String _accumulatedText = '';
  String _recognizedText = '';

  // ─── Guard to prevent re-entrant _startListening calls ───
  bool _isStartingListen = false;

  // ─── Recording timer ───
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isPaused = false;

  // ─── Permission & Location ───
  double? _latitude;
  double? _longitude;
  bool _micPermDenied = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _accumulatedText = widget.initialTranscription ?? '';
    _recognizedText = _accumulatedText;

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _requestPermissionsAndInit();
    _startRecordingTimer();
  }

  Future<void> _requestPermissionsAndInit() async {
    _fetchLocation();
    final micStatus = await Permission.microphone.request();
    if (micStatus.isGranted) {
      await _initSpeech();
    } else if (micStatus.isPermanentlyDenied) {
      if (mounted) setState(() => _micPermDenied = true);
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final locPermission = await Geolocator.requestPermission();
      if (locPermission == LocationPermission.denied ||
          locPermission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      debugPrint('Location fetch error: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') &&
              !_isPaused &&
              !_isStartingListen &&
              mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_isPaused && !_isStartingListen && mounted) {
                _startListening();
              }
            });
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech error: $errorNotification');
          if (mounted) setState(() => _isStartingListen = false);
        },
      );
      if (_speechEnabled) _startListening();
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled || _isStartingListen || _isListening) return;
    _isStartingListen = true;

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          final partial = result.recognizedWords.trim();
          if (partial.isNotEmpty) {
            _recognizedText = _accumulatedText.isEmpty
                ? partial
                : '$_accumulatedText $partial';
          }

          if (result.finalResult) {
            _accumulatedText = _recognizedText;
          }
        });
      },
      listenFor: const Duration(minutes: 60),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
    );

    if (mounted) {
      setState(() {
        _isListening = true;
        _isStartingListen = false;
      });
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
      });
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _stopListening();
        _pulseController.stop();
      } else {
        _startListening();
        _pulseController.repeat(reverse: true);
      }
    });
  }

  void _startRecordingTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused && mounted) setState(() => _elapsedSeconds++);
    });
  }

  String get _timerText {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _stopAndProcess() {
    _stopListening();
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, s) => ProcessingScreen(
          rawText: _recognizedText.trim().isEmpty
              ? 'No transcription recorded.'
              : _recognizedText.trim(),
          durationMinutes: math.max(1, _elapsedSeconds ~/ 60),
          latitude: _latitude,
          longitude: _longitude,
        ),
        transitionsBuilder: (c, a, s, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _timer?.cancel();
    _speech.stop();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_micPermDenied) {
      return _PermissionDeniedState(
        onBack: () => Navigator.maybePop(context),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SiriWavePainter(
                    time: _waveController.value,
                    amplitude: _isPaused ? 0.1 : 1.0,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                if (!_speechEnabled && !_micPermDenied)
                  _MicWarningBanner(
                    onDismiss: () => setState(() {}),
                  ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildGlowingOrb(),
                          const SizedBox(height: 48),
                          _buildTranscriptionText(),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomControls(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isPaused
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.greenAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isPaused ? Colors.orange : Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isPaused ? 'Paused' : 'Listening',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isPaused ? Colors.orange : Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildGlowingOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = _isPaused ? 1.0 : 1.0 + 0.1 * _pulseController.value;
        final glowOpacity = _isPaused ? 0.0 : 0.4 * _pulseController.value;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: glowOpacity),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: glowOpacity * 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/images/mascot.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.mic, color: Colors.white, size: 36),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranscriptionText() {
    final text = _recognizedText.isEmpty
        ? (_isPaused ? 'Paused. Tap ▶ to continue.' : 'Listening…')
        : _recognizedText;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: _recognizedText.isEmpty ? 16 : 15,
        fontWeight: FontWeight.w400,
        color: _recognizedText.isEmpty
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.9),
        height: 1.6,
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _togglePause,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15), width: 1),
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          GestureDetector(
            onTap: _stopAndProcess,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    'Finish',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timerText,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicWarningBanner extends StatefulWidget {
  final VoidCallback onDismiss;
  const _MicWarningBanner({required this.onDismiss});

  @override
  State<_MicWarningBanner> createState() => _MicWarningBannerState();
}

class _MicWarningBannerState extends State<_MicWarningBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Dismissible(
      key: const ValueKey('mic_warning_banner'),
      direction: DismissDirection.up,
      onDismissed: (_) {
        setState(() => _dismissed = true);
        widget.onDismiss();
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade700,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Microphone unavailable. Check emulator: Extended Controls → Microphone',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _dismissed = true);
                widget.onDismiss();
              },
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedState extends StatelessWidget {
  final VoidCallback onBack;
  const _PermissionDeniedState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: Colors.redAccent, size: 44),
              ),
              const SizedBox(height: 32),
              Text(
                'Microphone Access Denied',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This app needs microphone permission to record your voice journal entries. '
                'You have permanently denied this permission.\n\n'
                'Please open App Settings and enable the Microphone permission to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => openAppSettings(),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Open App Settings',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: onBack,
                child: Text(
                  'Go Back',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiriWavePainter extends CustomPainter {
  final double time;
  final double amplitude;

  _SiriWavePainter({required this.time, required this.amplitude});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final width = size.width;

    _drawWave(canvas, width, centerY, 0.4, 1.2,
        const Color(0xFF6C5CE7).withValues(alpha: 0.3));
    _drawWave(canvas, width, centerY, 0.6, 0.8,
        const Color(0xFF00E5FF).withValues(alpha: 0.3));
    _drawWave(canvas, width, centerY, 0.8, 0.5,
        const Color(0xFF9B59B6).withValues(alpha: 0.3));
  }

  void _drawWave(Canvas canvas, double width, double centerY,
      double speedMultiplier, double heightMultiplier, Color color) {
    final path = Path();
    path.moveTo(0, centerY);

    for (double i = 0; i <= width; i++) {
      final waveOffset = math.sin(
          (i / width * math.pi * 2) + (time * math.pi * 2 * speedMultiplier));
      final taper = math.sin(i / width * math.pi);
      final y = centerY + (waveOffset * taper * 100 * amplitude * heightMultiplier);
      path.lineTo(i, y);
    }

    path.lineTo(width, centerY * 2);
    path.lineTo(0, centerY * 2);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, centerY - 150, width, 300));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SiriWavePainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.amplitude != amplitude;
  }
}

