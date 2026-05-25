import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'editor_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Processing Screen — Real AI processing with fallback chain
// FIX: Added `durationMinutes` constructor parameter (was missing,
//      causing a crash when AuroraVoiceScreen passed it in).
// ═══════════════════════════════════════════════════════════════

class ProcessingScreen extends StatefulWidget {
  final String? rawText;
  // FIX: parameter was missing — AuroraVoiceScreen always passes this
  final int durationMinutes;
  final double? latitude;
  final double? longitude;

  const ProcessingScreen({
    super.key,
    this.rawText,
    this.durationMinutes = 1,
    this.latitude,
    this.longitude,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  // ─── Progress ───
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  // ─── Sparkle Rotation ───
  late final AnimationController _sparkleController;

  // ─── Particle System ───
  late final List<_FloatingParticle> _particles;
  late final List<AnimationController> _particleControllers;

  // ─── Processing Steps ───
  static const List<String> _stepLabels = [
    'Restructuring your story…',
    'Detecting emotions…',
    'Fetching weather…',
    'Finding your location…',
    'Designing your layout…',
    'Finalizing…',
  ];
  int _currentStep = 0;
  bool _isDone = false;
  String? _errorMessage;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initSparkle();
    _initParticles();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRealProcessing();
    });
  }

  void _initSparkle() {
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _initParticles() {
    final count = 8 + _random.nextInt(3);
    _particleControllers = [];
    _particles = List.generate(count, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 4000 + _random.nextInt(4000)),
      )..repeat(reverse: true);
      _particleControllers.add(controller);

      final isSecondary = _random.nextBool();
      return _FloatingParticle(
        startX: _random.nextDouble(),
        startY: _random.nextDouble(),
        endX: _random.nextDouble(),
        endY: _random.nextDouble(),
        size: 6.0 + _random.nextDouble() * 6.0,
        color: (isSecondary ? AppColors.accentWarm : AppColors.accentPrimary)
            .withValues(alpha: 0.2 + _random.nextDouble() * 0.2),
        controller: controller,
      );
    });
  }

  Future<void> _startRealProcessing() async {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.addListener(_onAppStateChanged);

    final rawText = widget.rawText ??
        'Today was a beautiful day. I went for a walk in the park and '
            'felt grateful for everything around me.';

    final entry = await appState.processVoiceEntry(
      rawText: rawText,
      durationMinutes: widget.durationMinutes,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );

    if (!mounted) return;
    appState.removeListener(_onAppStateChanged);

    if (entry != null) {
      setState(() => _isDone = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const EditorScreen(),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = appState.processingError ?? 'Processing failed';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, false);
    }
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    final progress = appState.processingProgress;
    final step = appState.processingStep;

    _progressController.animateTo(
      progress,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    // Map progress to step index
    final stepIndex = (progress * (_stepLabels.length - 1)).round()
        .clamp(0, _stepLabels.length - 1);
    if (mounted) setState(() => _currentStep = stepIndex);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _sparkleController.dispose();
    for (final c in _particleControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          // ─── Floating particles ───
          ..._particles.map((p) => AnimatedBuilder(
                animation: p.controller,
                builder: (context, _) {
                  final t = p.controller.value;
                  final x = p.startX + (p.endX - p.startX) * t;
                  final y = p.startY + (p.endY - p.startY) * t;
                  return Positioned(
                    left: x * MediaQuery.of(context).size.width,
                    top: y * MediaQuery.of(context).size.height,
                    child: Container(
                      width: p.size,
                      height: p.size,
                      decoration: BoxDecoration(
                        color: p.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              )),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // ─── Mascot / sparkle orb ───
                  AnimatedBuilder(
                    animation: _sparkleController,
                    builder: (context, _) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentPrimary.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentPrimary
                                  .withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Image.asset(
                              'assets/images/mascot.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.auto_awesome_rounded,
                                size: 48,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // ─── Title ───
                  Text(
                    _isDone
                        ? 'Entry Created! ✨'
                        : _errorMessage != null
                            ? 'Something went wrong'
                            : 'Processing your journal…',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // ─── Step label ───
                  Text(
                    _errorMessage ?? _stepLabels[_currentStep],
                    style: TextStyle(
                      fontSize: 14,
                      color: _errorMessage != null
                          ? Colors.red
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // ─── Progress bar ───
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, _) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _isDone ? 1.0 : _progressAnimation.value,
                              minHeight: 8,
                              backgroundColor: AppColors.bgSecondary,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isDone
                                    ? AppColors.accentSuccess
                                    : AppColors.accentPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_isDone ? 1.0 : _progressAnimation.value * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Particle data ───────────────────────────────────────────

class _FloatingParticle {
  final double startX, startY, endX, endY, size;
  final Color color;
  final AnimationController controller;

  const _FloatingParticle({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.color,
    required this.controller,
  });
}
