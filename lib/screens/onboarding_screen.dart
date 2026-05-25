import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'new_home_shell.dart';

// ════════════════════════════════════════════════════════════════
// Onboarding — 7 pages, zero emojis, premium dark design
// ════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  static const int _totalPages = 7;

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _next() {
    if (_currentPage < _totalPages - 1) _goTo(_currentPage + 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      body: Stack(
        children: [
          const Positioned.fill(child: _SubtleGrid()),
          PageView(
            controller: _controller,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (p) => setState(() => _currentPage = p),
            children: [
              _WelcomePage(onContinue: _next, onLogin: () => _goTo(5)),
              _FeaturePage(
                index: 0,
                onContinue: _next,
                title: 'Just Talk',
                subtitle: 'No typing. No formatting. Just speak.',
                description:
                    'Ramble, pause, backtrack — our AI understands your flow, removes filler words, and turns your raw thoughts into structured, readable prose.',
                icon: Icons.mic_none_rounded,
                accentColor: const Color(0xFF5B6EF5),
              ),
              _FeaturePage(
                index: 1,
                onContinue: _next,
                title: 'Auto-Beautiful',
                subtitle: 'Every entry is a work of art.',
                description:
                    'Headings, bullets, pull quotes, and mood-matched layouts appear automatically. You focus on the memory. We handle the presentation.',
                icon: Icons.auto_awesome_outlined,
                accentColor: const Color(0xFF00D4FF),
              ),
              _FeaturePage(
                index: 2,
                onContinue: _next,
                title: 'It Remembers',
                subtitle: 'Grows smarter with every entry.',
                description:
                    'FlowJournal links past memories, spots emotional patterns, and builds a deep understanding of your life over months and years.',
                icon: Icons.psychology_outlined,
                accentColor: const Color(0xFF7C5CEB),
              ),
              _PermissionsPage(onContinue: _next),
              _AccountPage(onContinue: _next),
              const _PersonalizationPage(),
            ],
          ),
          if (_currentPage < 6)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: _DotRow(total: 6, current: _currentPage),
            ),
        ],
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  final int total;
  final int current;
  const _DotRow({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF5B6EF5)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _WelcomePage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onLogin;
  const _WelcomePage({required this.onContinue, required this.onLogin});

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07080D),
      child: FadeTransition(
        opacity: _fadeIn,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                SizedBox(
                  height: 200,
                  child: AnimatedBuilder(
                    animation: _floatCtrl,
                    builder: (_, __) => _FloatingPolygons(t: _floatCtrl.value),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Turn your chaos\ninto stories',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 32,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Speak naturally. AI structures, beautifies, and remembers.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
                const Spacer(flex: 2),
                _PremiumButton(
                  label: 'Start Journaling',
                  onTap: widget.onContinue,
                  primary: true,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onLogin,
                  child: Text(
                    'I already have an account',
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Free forever. No credit card required.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingPolygons extends StatelessWidget {
  final double t;
  const _FloatingPolygons({required this.t});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(math.sin(t * math.pi * 2) * 10, math.cos(t * math.pi * 2) * 10),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF5B6EF5).withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(math.cos(t * math.pi * 2) * 15, math.sin(t * math.pi * 2) * 15),
          child: Icon(Icons.psychology_outlined, size: 80, color: const Color(0xFF00D4FF).withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class _FeaturePage extends StatelessWidget {
  final int index;
  final VoidCallback onContinue;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _FeaturePage({
    required this.index,
    required this.onContinue,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Icon(icon, size: 48, color: accentColor),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const Spacer(flex: 2),
            _PremiumButton(
              label: 'Continue',
              onTap: onContinue,
              primary: true,
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  final VoidCallback onContinue;
  const _PermissionsPage({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.mic_none_rounded, size: 64, color: const Color(0xFF00D4FF)),
            const SizedBox(height: 32),
            Text(
              'Can we hear your thoughts?',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'FlowJournal needs microphone access to record your voice entries. You can also type, but voice makes the magic faster.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_voice_rounded, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Enable Voice Journaling',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: true,
                    onChanged: (v) {},
                    activeColor: const Color(0xFF00D4FF),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _PremiumButton(
              label: 'Continue',
              onTap: onContinue,
              primary: true,
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _AccountPage extends StatefulWidget {
  final VoidCallback onContinue;
  const _AccountPage({required this.onContinue});

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Please fill in all fields';
        _isLoading = false;
      });
      return;
    }

    // Try sign in, if fails try sign up
    var res = await AuthService().signInWithEmail(email: email, password: password);
    if (!res.success && res.error != null && res.error!.contains('credentials')) {
      res = await AuthService().signUpWithEmail(email: email, password: password);
    }
    
    if (res.success || res.isOffline) {
      widget.onContinue();
    } else {
      setState(() {
        _error = res.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _anonymous() async {
    setState(() => _isLoading = true);
    await AuthService().continueAnonymously();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Create Account',
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'End-to-end encrypted. We can\'t read your entries.',
              style: GoogleFonts.dmSans(color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            _InputField(hint: 'Email', icon: Icons.email_outlined, controller: _emailController),
            const SizedBox(height: 16),
            _InputField(hint: 'Password', icon: Icons.lock_outline, isPassword: true, controller: _passwordController),
            const SizedBox(height: 24),
            _PremiumButton(
              label: _isLoading ? 'Connecting...' : 'Continue with Email',
              onTap: _isLoading ? null : _submit,
              primary: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
              ],
            ),
            const SizedBox(height: 24),
            _PremiumButton(
              label: 'Continue with Google',
              onTap: _isLoading ? null : () {},
              primary: false,
              icon: Icons.g_mobiledata_rounded,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : _anonymous,
              child: Text(
                'Start Anonymously (Local Only)',
                style: GoogleFonts.dmSans(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _PersonalizationPage extends StatefulWidget {
  const _PersonalizationPage();

  @override
  State<_PersonalizationPage> createState() => _PersonalizationPageState();
}

class _PersonalizationPageState extends State<_PersonalizationPage> {
  PersonalityStyle _selected = PersonalityStyle.calm;

  void _finish() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.completeOnboarding();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const NewHomeShell(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              'How should your\njournal feel?',
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This sets the default tone for your UI and AI reflections.',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 48),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: PersonalityStyle.values.map((style) {
                final isSelected = _selected == style;
                return GestureDetector(
                  onTap: () => setState(() => _selected = style),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? style.color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? style.color : Colors.white.withValues(alpha: 0.05),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(style.icon, color: isSelected ? style.color : Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text(
                          style.label,
                          style: GoogleFonts.dmSans(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(flex: 2),
            _PremiumButton(
              label: 'Create My Journal',
              onTap: _finish,
              primary: true,
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextEditingController controller;

  const _InputField({
    required this.hint,
    required this.icon,
    this.isPassword = false,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.3)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;

  const _PremiumButton({
    required this.label,
    this.onTap,
    this.primary = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: primary ? const Color(0xFF5B6EF5) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(28),
          border: primary ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: primary
              ? [BoxShadow(color: const Color(0xFF5B6EF5).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtleGrid extends StatelessWidget {
  const _SubtleGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 30) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 30) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
