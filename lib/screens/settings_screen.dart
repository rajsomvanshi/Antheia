import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';

// ═══════════════════════════════════════════════════════════════
// FlowJournal — Settings Screen
// ═══════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _currentTab = 0;
  String _selectedFont = 'Inter';
  String _selectedThemePreset = 'Default';
  String _animationIntensity = 'Normal';
  String _voiceSensitivity = 'Normal';
  String _exportFormat = 'JSON';

  static const List<String> _tabLabels = [
    '👤 Account',
    '🎨 Appearance',
    '✨ AI',
    '🔒 Privacy',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Settings',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),

            // ─── Tab Bar ───
            _buildTabBar(isDark),

            const SizedBox(height: 16),

            // ─── Tab Content ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                physics: const BouncingScrollPhysics(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildTabContent(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Tab Bar
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTabBar(bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _tabLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isActive = _currentTab == index;
          return GestureDetector(
            onTap: () => setState(() => _currentTab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accentPrimary
                    : (isDark ? AppColors.bgDarkSecondary : AppColors.bgSecondary),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _tabLabels[index],
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Tab Router
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTabContent(bool isDark) {
    switch (_currentTab) {
      case 0:
        return _accountTab(key: const ValueKey('account'), isDark: isDark);
      case 1:
        return _buildAppearanceTab(isDark);
      case 2:
        return _buildAITab(isDark);
      case 3:
        return _buildPrivacyTab(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Account Tab
  // ═══════════════════════════════════════════════════════════════

  Widget _accountTab({required bool isDark, Key? key}) {
    final appState = context.watch<AppState>();
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderSubtleDark : AppColors.borderSubtle;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // ─── Profile Row ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with real initial
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.accentPrimary, AppColors.accentWarm],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      appState.userName.isNotEmpty
                          ? appState.userName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Tappable name field ──
                      GestureDetector(
                        onTap: () => _showEditNameDialog(appState),
                        child: Row(
                          children: [
                            Text(
                              appState.userName.isEmpty ? 'Add your name' : appState.userName,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: appState.userName.isEmpty
                                    ? AppColors.textSecondary
                                    : textColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.edit_outlined,
                                size: 14, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appState.isPremium ? 'Pro plan ✨' : 'Free plan · Upgrade to Pro ✨',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statPill('${appState.entries.length}', 'Entries'),
                const SizedBox(width: 8),
                _statPill('${appState.currentStreak}🔥', 'Streak'),
                const SizedBox(width: 8),
                _statPill('${appState.uniqueDaysJournaled}', 'Days'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Divider(height: 1, color: borderColor),

          // ─── Cloud Backup ───
          SettingRow(
            label: 'Journal Backup',
            subtitle: 'Sync to cloud',
            isDark: isDark,
            trailing: Switch(
              value: appState.cloudBackup,
              onChanged: (_) => appState.toggleCloudBackup(),
              activeThumbColor: AppColors.accentPrimary,
            ),
          ),

          // ─── Strict Local Mode ───
          _buildListTile(
            context,
            icon: Icons.cloud_off_rounded,
            title: 'Strict Local Mode',
            subtitle: 'Disable all cloud syncing',
            trailing: Switch(
              value: appState.strictLocalMode,
              onChanged: (_) => appState.toggleStrictLocalMode(),
              activeColor: AppColors.accentPrimary,
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ─── Upgrade to Pro ───
          _buildListTile(
            context,
            icon: Icons.star_border_rounded,
            title: 'Upgrade to Pro',
            subtitle: 'Unlock unlimited AI summaries',
            textColor: AppColors.accentWarm,
            iconColor: AppColors.accentWarm,
            onTap: () {},
          ),

          // ─── Export Entries ───
          SettingRow(
            label: 'Export Entries',
            isDark: isDark,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              size: 22,
            ),
            onTap: () => _showExportSheet(context),
          ),

          // ─── Delete Account ───
          SettingRow(
            label: 'Delete Account',
            labelColor: AppColors.accentWarm,
            isDark: isDark,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.accentWarm.withValues(alpha: 0.6),
              size: 22,
            ),
            onTap: () => _showDeleteAccountDialog(context, appState),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Entries', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Choose your export format', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            _exportOption(Icons.code_rounded, 'JSON', 'Raw structured data'),
            const SizedBox(height: 12),
            _exportOption(Icons.text_snippet_rounded, 'Markdown', 'Formatted text'),
            const SizedBox(height: 12),
            _exportOption(Icons.picture_as_pdf_rounded, 'PDF', 'Printable document'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _exportOption(IconData icon, String format, String desc) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exporting as $format...'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accentPrimary,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.accentPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(format, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(desc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(
          'This will permanently delete all your journal entries and account data. This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Account deletion requested'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.red.shade400,
                ),
              );
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(AppState appState) {
    final controller = TextEditingController(text: appState.userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) appState.setUserName(name);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Appearance Tab
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAppearanceTab(bool isDark) {
    final appState = context.watch<AppState>();
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderSubtleDark : AppColors.borderSubtle;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Container(
      key: const ValueKey('appearance'),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Dark Mode ───
          SettingRow(
            label: 'Dark Mode',
            isDark: isDark,
            trailing: Switch(
              value: appState.isDark,
              onChanged: (_) => appState.toggleTheme(),
              activeThumbColor: AppColors.accentPrimary,
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ─── Animation Intensity ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.animation_rounded, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Animation Intensity', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildChoiceChip('Reduced', false, context),
                            const SizedBox(width: 8),
                            _buildChoiceChip('Normal', true, context),
                            const SizedBox(width: 8),
                            _buildChoiceChip('Fluid', false, context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ─── Default Font ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Font',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFontGrid(isDark),
              ],
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ─── Default Theme ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Theme',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildThemePreviews(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontGrid(bool isDark) {
    final fonts = [
      _FontOption('Playfair Display', GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w600)),
      _FontOption('Inter', GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600)),
      _FontOption('Caveat', GoogleFonts.caveat(fontSize: 26, fontWeight: FontWeight.w600)),
    ];
    final bgSelected = isDark ? AppColors.bgDarkSecondary : AppColors.bgSecondary;
    final bgNormal = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevated;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;


    return Row(
      children: fonts.map((font) {
        final isSelected = _selectedFont == font.name;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedFont = font.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: font.name != 'Caveat' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? bgSelected : bgNormal,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.accentPrimary : Colors.transparent,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Aa',
                    style: font.style.copyWith(color: textColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    font.name.split(' ').first,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildThemePreviews(bool isDark) {
    final appState = context.watch<AppState>();
    
    final themes = [
      _ThemePreset('Default', [const Color(0xFF6C5CE7), const Color(0xFFFAF9F6), const Color(0xFFE17055)], ThemeType.defaultLight),
      _ThemePreset('Earthy', [const Color(0xFF4A5D4E), const Color(0xFFF4F1EB), const Color(0xFFD4C9A8)], ThemeType.earthyLuxury),
      _ThemePreset('Chocolate', [const Color(0xFF3E2A21), const Color(0xFFF9F6F0), const Color(0xFFD4A373)], ThemeType.chocolateTruffle),
      _ThemePreset('Wisteria', [const Color(0xFF7B6B9E), const Color(0xFFF8F7FA), const Color(0xFFE5B8D9)], ThemeType.wisteriaBloom),
    ];

    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: themes.map((theme) {
          final isSelected = appState.activeThemeType == theme.type;
          return GestureDetector(
            onTap: () => appState.setThemeType(theme.type),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 80,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colors[1],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.accentPrimary : (isDark ? AppColors.borderSubtleDark : AppColors.borderSubtle),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: theme.colors[0],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 34,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: theme.colors[2],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 10,
                          child: Container(
                            width: 40,
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.colors[0].withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.accentPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    theme.name,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? textColor : subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AI Preferences Tab
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAITab(bool isDark) {
    final appState = context.watch<AppState>();
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderSubtleDark : AppColors.borderSubtle;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Container(
      key: const ValueKey('ai'),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── AI Personality ───
          SettingRow(
            label: 'AI Personality',
            subtitle: appState.aiPersonality,
            isDark: isDark,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              size: 22,
            ),
            onTap: () => _showPersonalitySheet(context, appState, isDark),
          ),

          Divider(height: 1, color: borderColor),

          // ─── Auto-Formatting Intensity ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-Formatting Intensity',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                OptionPills(
                  options: const ['Light', 'Medium', 'Heavy'],
                  selected: appState.autoFormatting,
                  isDark: isDark,
                  onChanged: (val) => appState.setAutoFormatting(val),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ─── Voice Command Sensitivity ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Command Sensitivity',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                OptionPills(
                  options: const ['Low', 'Normal', 'High'],
                  selected: _voiceSensitivity,
                  isDark: isDark,
                  onChanged: (val) => setState(() => _voiceSensitivity = val),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ─── Companion Voice ───
          SettingRow(
            label: 'Companion Voice',
            subtitle: appState.ttsVoice,
            isDark: isDark,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              size: 22,
            ),
            onTap: () => _showTtsVoiceSheet(context, appState, isDark),
          ),
          
          Divider(height: 1, color: borderColor),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Voice Pitch',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    Text(
                      appState.ttsPitch.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: appState.ttsPitch,
                  min: 0.5,
                  max: 1.5,
                  activeColor: AppColors.accentPrimary,
                  inactiveColor: borderColor,
                  onChanged: (val) => appState.setTtsPitch(val),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Voice Speed',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    Text(
                      appState.ttsSpeed.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: appState.ttsSpeed,
                  min: 0.5,
                  max: 1.5,
                  activeColor: AppColors.accentPrimary,
                  inactiveColor: borderColor,
                  onChanged: (val) => appState.setTtsSpeed(val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTtsVoiceSheet(BuildContext context, AppState appState, bool isDark) {
    final voices = [
      _PersonalityOption(emoji: '👩🏼', name: 'English Female', description: 'Calm, soft female voice in English'),
      _PersonalityOption(emoji: '👨🏼', name: 'English Male', description: 'Warm, deep male voice in English'),
      _PersonalityOption(emoji: '👩🏽', name: 'Hindi Female', description: 'Soothing female voice in Hindi'),
      _PersonalityOption(emoji: '👨🏽', name: 'Hindi Male', description: 'Relaxing male voice in Hindi'),
    ];

    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgPrimary;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    final borderColor = isDark ? AppColors.borderSubtleDark : AppColors.borderSubtle;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Companion Voice',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the voice that reads your entries back to you',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 20),
              ...voices.map((v) {
                final isSelected = appState.ttsVoice == v.name;
                return GestureDetector(
                  onTap: () {
                    appState.setTtsVoice(v.name);
                    Navigator.of(ctx).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentPrimary.withValues(alpha: 0.08)
                          : surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.accentPrimary : borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(v.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                v.description,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 15),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showPersonalitySheet(BuildContext context, AppState appState, bool isDark) {
    final personalities = [
      _PersonalityOption(
        emoji: '🤗',
        name: 'Supportive Friend',
        description: 'Warm, encouraging, and always there for you.',
      ),
      _PersonalityOption(
        emoji: '🧘',
        name: 'Calm Therapist',
        description: 'Reflective prompts with gentle guidance.',
      ),
      _PersonalityOption(
        emoji: '😄',
        name: 'Funny Companion',
        description: 'Light-hearted humor to brighten your entries.',
      ),
      _PersonalityOption(
        emoji: '💪',
        name: 'Motivational Coach',
        description: 'Bold energy and actionable encouragement.',
      ),
    ];

    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgPrimary;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    final borderColor = isDark ? AppColors.borderSubtleDark : AppColors.borderSubtle;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'AI Personality',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose how your AI assistant communicates',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 20),
              ...personalities.map((p) {
                final isSelected = appState.aiPersonality == p.name;
                return GestureDetector(
                  onTap: () {
                    appState.setAiPersonality(p.name);
                    Navigator.of(ctx).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentPrimary.withValues(alpha: 0.08)
                          : surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.accentPrimary : borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(p.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.description,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 15),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Privacy & Security Tab
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPrivacyTab(bool isDark) {
    final appState = context.watch<AppState>();
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderSubtleDark : AppColors.borderSubtle;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;


    return Container(
      key: const ValueKey('privacy'),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Biometric Lock ───
          SettingRow(
            label: 'Biometric Lock',
            subtitle: 'Face ID / Fingerprint',
            isDark: isDark,
            trailing: Switch(
              value: appState.biometricLock,
              onChanged: (_) => appState.toggleBiometricLock(),
              activeThumbColor: AppColors.accentPrimary,
            ),
          ),

          // ─── E2E Encryption ───
          SettingRow(
            label: 'End-to-End Encryption',
            isDark: isDark,
            trailing: Switch(
              value: appState.e2eEncryption,
              onChanged: (_) => appState.toggleE2eEncryption(),
              activeThumbColor: AppColors.accentPrimary,
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ─── Export All Entries ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export All Entries',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                OptionPills(
                  options: const ['JSON', 'PDF', 'TXT'],
                  selected: _exportFormat,
                  isDark: isDark,
                  onChanged: (val) => setState(() => _exportFormat = val),
                ),
              ],
            ),
          ),

          // ─── Delete Account ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
            child: GestureDetector(
              onTap: () {},
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.accentWarm, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Delete Account',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentWarm,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.accentWarm.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ─── About Section ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'About',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Version 1.0.0',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: subtitleColor,
              ),
            ),
          ),
          SettingRow(
            label: 'Terms of Service',
            isDark: isDark,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              size: 22,
            ),
            onTap: () {},
          ),
          SettingRow(
            label: 'Privacy Policy',
            isDark: isDark,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              size: 22,
            ),
            onTap: () {},
          ),
          SettingRow(
            label: 'Help & Feedback',
            isDark: isDark,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              size: 22,
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, {required IconData icon, required String title, String? subtitle, Widget? trailing, Color? textColor, Color? iconColor, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = textColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(title, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 12)) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accentPrimary : (isDark ? AppColors.bgDarkSecondary : AppColors.bgSecondary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: GoogleFonts.inter(color: isSelected ? Colors.white : AppColors.textSecondary)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Reusable SettingRow Widget
// ═══════════════════════════════════════════════════════════════

class SettingRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final Widget trailing;
  final bool isDark;
  final VoidCallback? onTap;

  const SettingRow({
    super.key,
    required this.label,
    this.subtitle,
    this.labelColor,
    required this.trailing,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = labelColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Reusable OptionPills Widget
// ═══════════════════════════════════════════════════════════════

class OptionPills extends StatelessWidget {
  final List<String> options;
  final String selected;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const OptionPills({
    super.key,
    required this.options,
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((option) {
        final isActive = selected == option;
        return Padding(
          padding: EdgeInsets.only(right: option != options.last ? 8 : 0),
          child: GestureDetector(
            onTap: () => onChanged(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accentPrimary
                    : (isDark ? AppColors.bgDarkSecondary : AppColors.bgSecondary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                option,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? Colors.white
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Private Data Models
// ═══════════════════════════════════════════════════════════════

class _FontOption {
  final String name;
  final TextStyle style;
  const _FontOption(this.name, this.style);
}

class _ThemePreset {
  final String name;
  final List<Color> colors;
  final ThemeType type;
  const _ThemePreset(this.name, this.colors, this.type);
}

class _PersonalityOption {
  final String emoji;
  final String name;
  final String description;
  const _PersonalityOption({
    required this.emoji,
    required this.name,
    required this.description,
  });
}
