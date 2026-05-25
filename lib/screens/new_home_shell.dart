import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../screens/settings_screen.dart';
import 'tabs/overview_tab.dart';
import 'tabs/timeline_tab.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/media_tab.dart';
import 'tabs/map_tab.dart';
import '../widgets/floating_mascot_fab.dart';
import 'aurora_voice_screen.dart';
import 'editor_screen.dart';

// ═══════════════════════════════════════════════════════════════
// NewHomeShell — Premium FlowJournal main shell
//
// Architecture:
//   • Scaffold wraps a Drawer (→ SettingsScreen) + body
//   • Body = Stack[ HeroHeader(280px) + white rounded panel ]
//   • Panel contains SegmentedTabBar (5 tabs) + TabBarView
//   • FloatingMascotFab overlaid at bottom center via Stack
// ═══════════════════════════════════════════════════════════════

class NewHomeShell extends StatefulWidget {
  const NewHomeShell({super.key});

  @override
  State<NewHomeShell> createState() => _NewHomeShellState();
}

class _NewHomeShellState extends State<NewHomeShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Tab definitions ────────────────────────────────────────
  static const _tabIcons = [
    Icons.menu_book_rounded,      // Overview
    Icons.list_alt_rounded,       // Timeline
    Icons.calendar_month_rounded, // Calendar
    Icons.photo_library_rounded,  // Media
    Icons.map_rounded,            // Map
  ];

  static const _tabLabels = [
    'Overview',
    'Timeline',
    'Calendar',
    'Media',
    'Map',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make status bar icons light (visible on gradient background)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      drawer: const Drawer(child: SettingsScreen()),
      body: Stack(
        children: [
          // ── Main scrollable content ─────────────────────────
          _buildBody(context),

          // ── Floating Mascot FAB overlay ─────────────────────
          const Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: FloatingMascotFab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return NestedScrollView(
      physics: const BouncingScrollPhysics(),
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.bgPrimary,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: _buildTopBar(context),
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(tabController: _tabController),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(28),
              child: Container(
                height: 28,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
              ),
            ),
          ),
        ];
      },
      body: Transform.translate(
        offset: const Offset(0, -1), // Fixes the 1-pixel sliver rendering gap (the "stripe")
        child: Container(
          color: AppColors.bgPrimary,
          child: Column(
            children: [
              // ── Segmented Tab Bar ──────────────────────────────
            _SegmentedTabBar(
              controller: _tabController,
              icons: _tabIcons,
              labels: _tabLabels,
            ),
            // ── Tab content ────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: const [
                  OverviewTab(),
                  TimelineTab(),
                  CalendarTab(),
                  MediaTab(),
                  MapTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
  Widget _buildTopBar(BuildContext context) {
    final appState = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Hamburger menu
          _GlassIconButton(
            icon: Icons.menu_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Scaffold.of(context).openDrawer();
            },
          ),

          const Spacer(),

          // Right icons in a frosted pill
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlassPillIcon(
                      icon: Icons.notifications_none_rounded,
                      onTap: () => HapticFeedback.selectionClick(),
                    ),
                    const SizedBox(width: 2),
                    _GlassPillIcon(
                      icon: Icons.search_rounded,
                      onTap: () => HapticFeedback.selectionClick(),
                    ),
                    const SizedBox(width: 2),
                    _GlassPillIcon(
                      icon: Icons.more_vert_rounded,
                      onTap: () => HapticFeedback.selectionClick(),
                    ),
                    const SizedBox(width: 6),
                    // Circular profile avatar
                    GestureDetector(
                      onTap: () => HapticFeedback.selectionClick(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFF74B9FF)],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            appState.userName.isNotEmpty
                                ? appState.userName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HeroHeader — 280px gradient header with glassmorphic top bar
// ═══════════════════════════════════════════════════════════════

class _HeroHeader extends StatefulWidget {
  final TabController tabController;
  const _HeroHeader({required this.tabController});

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader> {
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
  }

  // ── Time-of-day helpers ─────────────────────────────────────

  String get _greeting {
    final h = _now.hour;
    if (h >= 5 && h < 12) return 'Good Morning ☀️';
    if (h >= 12 && h < 17) return 'Good Afternoon 🌤';
    if (h >= 17 && h < 20) return 'Good Evening 🌅';
    return 'Good Night 🌙';
  }

  List<Color> get _gradientColors {
    final h = _now.hour;
    if (h >= 5 && h < 12) {
      // Morning — warm sunrise
      return const [Color(0xFFFDB99B), Color(0xFFF8A978), Color(0xFFE8925A)];
    } else if (h >= 12 && h < 17) {
      // Afternoon — sky blue
      return const [Color(0xFF87CEEB), Color(0xFF4FA8D5), Color(0xFF1E90FF)];
    } else if (h >= 17 && h < 20) {
      // Evening — purple-orange sunset
      return const [Color(0xFF764BA2), Color(0xFFFF8C69), Color(0xFFFFB347)];
    } else {
      // Night — deep navy
      return const [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)];
    }
  }

  String _startDateLabel(AppState state) {
    if (state.entries.isNotEmpty) {
      final oldest = state.entries.last.createdAt;
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[oldest.month - 1]} ${oldest.day}, ${oldest.year}';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[_now.month - 1]} ${_now.day}, ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final mediaTop = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Gradient background via CustomPainter ──────────
          CustomPaint(
            painter: _GradientPainter(colors: _gradientColors),
          ),

          // ── Dark overlay for readability ───────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.40),
                ],
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // Greeting text
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    '${_greeting}, ${appState.userName}',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0x40000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // Subtext
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(
                    'Your journey from ${_startDateLabel(appState)} to today',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      );
  }
}

// ═══════════════════════════════════════════════════════════════
// GradientPainter — CustomPainter for the hero background
// ═══════════════════════════════════════════════════════════════

class _GradientPainter extends CustomPainter {
  final List<Color> colors;
  const _GradientPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_GradientPainter old) => old.colors != colors;
}

// ═══════════════════════════════════════════════════════════════
// SegmentedTabBar — 5-tab bar with cyan underline indicator
// ═══════════════════════════════════════════════════════════════

class _SegmentedTabBar extends StatelessWidget {
  final TabController controller;
  final List<IconData> icons;
  final List<String> labels;

  const _SegmentedTabBar({
    required this.controller,
    required this.icons,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPrimary,
      child: TabBar(
        controller: controller,
        isScrollable: false,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: Color(0xFF00B4D8),
            width: 3,
          ),
          insets: EdgeInsets.symmetric(horizontal: 12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: List.generate(icons.length, (i) {
          return AnimatedBuilder(
            animation: controller.animation ?? const AlwaysStoppedAnimation(0),
            builder: (context, _) {
              // Determine if this tab is the current one
              final currentIndex = controller.index;
              final isSelected = currentIndex == i;

              return Tab(
                height: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[i],
                      size: 20,
                      color: isSelected
                          ? const Color(0xFF00B4D8)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[i],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF00B4D8)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Small glass icon button (hamburger style)
// ═══════════════════════════════════════════════════════════════

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Center(child: Icon(icon, color: Colors.white, size: 22)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Icon inside the frosted pill ─────────────────────────────

class _GlassPillIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassPillIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.3),
        highlightColor: Colors.white.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
