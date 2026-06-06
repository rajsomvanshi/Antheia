import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../state/memory_state.dart';
import '../state/preferences_state.dart';
import '../state/biometric_state.dart';
import '../theme/app_theme.dart';
import '../theme/interaction_system.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/outbox_service.dart';
import '../services/paywall_service.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';
import 'paywall_sheet.dart';

void _openPaywall(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const PaywallScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
        child: child,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// SettingsScreen — Atmospheric Sanctuary Configuration
//
// Tabs strictly organized as:
//   1. Atmosphere (Theme mode, Motion scale, Font selection)
//   2. Memory (Streak/Stats, Google Auth Sync/Profile, local data)
//   3. Presence (Biometric Lock, Reflection voice/Cadence, Privacy)
// ═══════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  final bool asTab;
  const SettingsScreen({super.key, this.asTab = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;

  static const _tabs = ['Appearance', 'Archive', 'Security'];

  bool _isSettingsLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showSettingsAuthError(String message) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.hairline, width: 0.5),
        ),
        title: const Text(
          'Connection Issue',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        content: Text(
          message,
          style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: colors.bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(colors),
                _buildTabBar(colors),
                Divider(height: 1, color: colors.hairline),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    physics: const BouncingScrollPhysics(),
                    child: AnimatedSwitcher(
                      duration: AppTransitions.short,
                      child: _buildContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isSettingsLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF9B7A4A),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar(ResolvedColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          if (!widget.asTab)
            GestureDetector(
              onTap: () {
                AppHaptics.light();
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colors.textSecondary,
                  size: 16,
                ),
              ),
            ),
          Text(
            'Sanctuary Settings',
            style: TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontSize: 24,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              color: colors.text,
            ),
          ),
          const Spacer(),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ResolvedColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_tabs.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '·',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: colors.textSecondary.withValues(alpha: 0.3),
                ),
              ),
            );
          }
          final i = index ~/ 2;
          final isActive = _tab == i;
          return GestureDetector(
            onTap: () {
              setState(() => _tab = i);
              AppHaptics.light();
            },
            child: AnimatedDefaultTextStyle(
              duration: AppTransitions.micro,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? colors.accent : colors.textSecondary,
                letterSpacing: 0.5,
              ),
              child: Text(_tabs[i].toUpperCase()),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent() {
    switch (_tab) {
      case 0:
        return const _AtmosphereTab(key: ValueKey('atmosphere'));
      case 1:
        return _MemoryTab(
          key: const ValueKey('memory'),
          setLoading: (loading) {
            if (mounted) setState(() => _isSettingsLoading = loading);
          },
          showAuthError: (msg) {
            _showSettingsAuthError(msg);
          },
        );
      case 2:
        return const _PresenceTab(key: ValueKey('presence'));
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// ATMOSPHERE TAB
// ═══════════════════════════════════════════════════════════════
class _AtmosphereTab extends StatefulWidget {
  const _AtmosphereTab({super.key});

  @override
  State<_AtmosphereTab> createState() => _AtmosphereTabState();
}

class _ThemeOption {
  final ThemeType type;
  final String label;
  final bool isPremium;
  const _ThemeOption(this.type, this.label, this.isPremium);
}

class _AtmosphereTabState extends State<_AtmosphereTab> {

  void _handleThemeChange(BuildContext context, ThemeType theme, PreferencesState prefs) async {
    if (theme == ThemeType.defaultLight) {
      prefs.setThemeType(theme);
      return;
    }
    final paywall = context.read<PaywallService>();
    if (paywall.checkGate(ProFeature.themes) != null) {
      await PaywallSheet.show(context, ProFeature.themes);
      return;
    }
    prefs.setThemeType(theme);
  }

  Widget _themePills({
    required BuildContext context,
    required ThemeType selected,
    required ValueChanged<ThemeType> onChanged,
    required ResolvedColors colors,
    required bool isPremium,
  }) {
    final options = [
      _ThemeOption(ThemeType.defaultLight, 'Default', false),
      _ThemeOption(ThemeType.earthyLuxury, 'Earthy', true),
      _ThemeOption(ThemeType.chocolateTruffle, 'Chocolate', true),
      _ThemeOption(ThemeType.wisteriaBloom, 'Wisteria', true),
    ];

    final brightness = Theme.of(context).brightness;

    return Row(
      children: options.map((opt) {
        final active = selected == opt.type;
        final isLocked = !isPremium && opt.isPremium;
        final optColors = ResolvedColors.resolve(brightness, opt.type);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                AppHaptics.light();
                onChanged(opt.type);
              },
              child: AnimatedContainer(
                duration: AppTransitions.short,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? colors.surfaceElevated : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active ? colors.accent : colors.hairline,
                    width: active ? 1.2 : 0.5,
                  ),
                  boxShadow: active ? [
                    BoxShadow(
                      color: colors.accent.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _JournalCardMockup(
                      themeColors: optColors,
                      font: 'Inter',
                      active: active,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: active ? FontWeight.bold : FontWeight.w400,
                            color: active ? colors.accent : colors.textSecondary,
                          ),
                        ),
                        if (isLocked) ...[
                          const SizedBox(width: 2),
                          Icon(Icons.lock_outline_rounded, size: 8, color: colors.accent),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<PreferencesState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Atmosphere', colors),
        const SizedBox(height: 8),
        _panel(
          colors: colors,
          child: _settingRow(
            label: 'Light mode',
            subtitle: prefs.isDark ? 'Off — cinematic warm dark' : 'On — warm ivory paper',
            icon: prefs.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            trailing: Switch(
              value: !prefs.isDark,
              onChanged: (_) => prefs.toggleTheme(),
              activeThumbColor: colors.accent,
              activeTrackColor: colors.accent.withOpacity(0.5),
            ),
            colors: colors,
          ),
        ),
        _divider(colors),
        _sectionLabel('Motion', colors),
        const SizedBox(height: 8),
        _panel(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Animation intensity', style: _body(colors)),
              const SizedBox(height: 4),
              Text(
                'None disables all motion. Subtle is gentle. Full includes ambient drift.',
                style: _caption(colors),
              ),
              const SizedBox(height: 16),
              _pills(
                options: const ['Full', 'Subtle', 'None'],
                selected: prefs.animationIntensityLabel,
                onChanged: prefs.setAnimationIntensity,
                colors: colors,
              ),
            ],
          ),
        ),
        _divider(colors),
        _sectionLabel('Sanctuary Theme', colors),
        const SizedBox(height: 8),
        _panel(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Atmospheric Presets', style: _body(colors)),
              const SizedBox(height: 4),
              Text(
                'Customize the background and accent tones of your sanctuary.',
                style: _caption(colors),
              ),
              const SizedBox(height: 16),
              _themePills(
                context: context,
                selected: prefs.activeThemeType,
                onChanged: (theme) => _handleThemeChange(context, theme, prefs),
                colors: colors,
                isPremium: prefs.isPremium,
              ),
            ],
          ),
        ),
        _divider(colors),
        _sectionLabel('Reading Font', colors),
        const SizedBox(height: 8),
        _panel(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Typography Presets', style: _body(colors)),
              const SizedBox(height: 4),
              Text(
                'Choose the emotional typeface of your journal body.',
                style: _caption(colors),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _fontTile(context, 'Inter', prefs.selectedFont, colors, prefs.isPremium,
                      () => prefs.setSelectedFont('Inter')),
                  const SizedBox(width: 12),
                  _fontTile(context, 'Playfair Display', prefs.selectedFont, colors, prefs.isPremium,
                      () => prefs.setSelectedFont('Playfair Display')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _fontTile(context, 'Lora', prefs.selectedFont, colors, prefs.isPremium,
                      () => prefs.setSelectedFont('Lora')),
                  const SizedBox(width: 12),
                  _fontTile(context, 'Caveat', prefs.selectedFont, colors, prefs.isPremium,
                      () => prefs.setSelectedFont('Caveat')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fontTile(
    BuildContext context,
    String font,
    String selected,
    ResolvedColors colors,
    bool isPremium,
    VoidCallback onTap,
  ) {
    final isLocked = !isPremium && font != 'Inter';
    final isActive = selected == font;
    final displayName = font == 'Playfair Display' ? 'Playfair' : font;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          AppHaptics.light();
          if (isLocked) {
            await PaywallSheet.show(context, ProFeature.themes);
          } else {
            onTap();
          }
        },
        child: AnimatedContainer(
          duration: AppTransitions.short,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? colors.surfaceElevated : colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? colors.accent : colors.hairline,
              width: isActive ? 1.2 : 0.5,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: colors.accent.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Column(
            children: [
              _JournalCardMockup(
                themeColors: colors,
                font: font,
                active: isActive,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                      color: colors.textSecondary,
                    ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 10,
                      color: colors.accent,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MEMORY TAB
// ═══════════════════════════════════════════════════════════════
class _MemoryTab extends StatefulWidget {
  final Function(bool) setLoading;
  final Function(String) showAuthError;

  const _MemoryTab({
    super.key,
    required this.setLoading,
    required this.showAuthError,
  });

  @override
  State<_MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends State<_MemoryTab> {
  bool _reloadPending = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final memory = context.watch<MemoryState>();
    final prefs = context.watch<PreferencesState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _profileCard(context, colors, prefs),
        if (AuthService().isSignedIn) ...[
          const SizedBox(height: 20),
          _syncStatusCard(context, colors),
        ],
        _sectionLabel('Sanctuary Statistics', colors),
        const SizedBox(height: 4),
        Row(
          children: [
            _statPill('${memory.entries.length}', 'Memories', colors),
            const SizedBox(width: 10),
            _statPill('${memory.currentStreak}', 'Day streak', colors),
            const SizedBox(width: 10),
            _statPill('${memory.uniqueDaysJournaled}', 'Days', colors),
          ],
        ),
        _sectionLabel('Archive Data', colors),
        const SizedBox(height: 8),
        _panel(
          colors: colors,
          child: Column(
            children: [
              _settingRow(
                label: 'Export entries',
                icon: Icons.download_outlined,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                  size: 20,
                ),
                colors: colors,
                onTap: () async {
                  final paywall = context.read<PaywallService>();
                  if (paywall.checkGate(ProFeature.export) != null) {
                    await PaywallSheet.show(context, ProFeature.export);
                    return;
                  }
                  _showExportSheet(context, colors);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, color: colors.hairline.withOpacity(0.5)),
              ),
              _settingRow(
                label: 'Delete all memories',
                labelColor: colors.error,
                icon: Icons.delete_outline_rounded,
                iconColor: colors.error,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.error.withOpacity(0.5),
                  size: 20,
                ),
                colors: colors,
                onTap: () =>
                    _showDeleteDialog(context, colors, context.read<MemoryState>()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, color: colors.hairline.withOpacity(0.5)),
              ),
              _settingRow(
                label: 'Reset App & Onboarding',
                labelColor: colors.error,
                icon: Icons.refresh_rounded,
                iconColor: colors.error,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.error.withOpacity(0.5),
                  size: 20,
                ),
                colors: colors,
                onTap: () => _showResetDialog(context, colors),
              ),
              if (AuthService().isSignedIn) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, color: colors.hairline.withOpacity(0.5)),
                ),
                _settingRow(
                  label: 'Delete cloud account & data',
                  labelColor: colors.error,
                  icon: Icons.person_remove_outlined,
                  iconColor: colors.error,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.error.withOpacity(0.5),
                    size: 20,
                  ),
                  colors: colors,
                  onTap: () => _showCloudDeleteDialog(context, colors),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _syncStatusCard(BuildContext context, ResolvedColors colors) {
    final outbox = OutboxService();
    final memory = context.watch<MemoryState>();
    final prefs = context.watch<PreferencesState>();
    
    return ValueListenableBuilder<int>(
      valueListenable: outbox.syncCompletionCounter,
      builder: (context, syncRound, _) {
        // When the outbox finishes a processing round, reload entries quietly
        // so the synced count display updates without flickering.
        if (syncRound > 0 && !_reloadPending) {
          _reloadPending = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _reloadPending = false;
            if (context.mounted) {
              context.read<MemoryState>().loadEntries(quiet: true);
            }
          });
        }
        
        return ValueListenableBuilder<int>(
          valueListenable: outbox.pendingCountNotifier,
          builder: (context, pendingCount, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: outbox.isProcessing,
              builder: (context, isProcessing, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: DatabaseService().isSyncing,
                  builder: (context, isSyncing, _) {
                    return ValueListenableBuilder<DateTime?>(
                      valueListenable: DatabaseService().lastSyncNotifier,
                      builder: (context, lastSync, _) {
                        final active = isSyncing || isProcessing;
                        final isFailed = pendingCount >= 5;
                        final totalSynced = memory.entries.where((e) => e.synced).length;
                        
                        final totalEntries = memory.entries.length;
                        final isPremium = prefs.isPremium;
                        final limitBlocked = !isPremium && totalEntries >= 15;
                        
                        String cloudStatus = 'HEALTHY';
                        Color statusColor = colors.accent;
                        
                        if (limitBlocked) {
                          cloudStatus = 'PRO REQUIRED';
                          statusColor = colors.error;
                        } else if (active) {
                          cloudStatus = 'SYNCING';
                          statusColor = colors.accent;
                        } else if (isFailed) {
                          cloudStatus = 'BLOCKED';
                          statusColor = colors.error;
                        } else if (pendingCount > 0) {
                          cloudStatus = 'PENDING SYNC';
                          statusColor = colors.accent.withValues(alpha: 0.8);
                        }
                        
                        String lastSyncStr = 'Never';
                        if (lastSync != null) {
                          final diff = DateTime.now().difference(lastSync);
                          if (diff.inSeconds < 60) {
                            lastSyncStr = 'Just now';
                          } else if (diff.inMinutes < 60) {
                            lastSyncStr = '${diff.inMinutes}m ago';
                          } else if (diff.inHours < 24) {
                            lastSyncStr = '${diff.inHours}h ago';
                          } else {
                            lastSyncStr = DateFormat('MMM d, HH:mm').format(lastSync);
                          }
                        }
                        
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.hairline, width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'CLOUD STATUS',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        cloudStatus,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(height: 1, color: colors.hairline),
                              const SizedBox(height: 12),
                              _metricRow('Last Sync', lastSyncStr, colors),
                              const SizedBox(height: 8),
                              _metricRow('Pending Uploads', '$pendingCount', colors),
                              const SizedBox(height: 8),
                              _metricRow('Total Synced', '$totalSynced', colors),
                              if (limitBlocked) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Backup is paused. Upgrade to Antheia Pro to back up more than 15 entries.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: colors.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                   GestureDetector(
                                    onTap: active
                                        ? null
                                        : () async {
                                            final entryCount = context.read<MemoryState>().entries.length;
                                            final isPremium = prefs.isPremium;
                                            if (!isPremium && entryCount >= 15) {
                                              await PaywallSheet.show(context, ProFeature.cloudSync);
                                              return;
                                            }
                                            AppHaptics.light();
                                            try {
                                              await DatabaseService().syncNow();
                                              if (context.mounted) {
                                                await context.read<MemoryState>().loadEntries(quiet: true);
                                              }
                                            } catch (e) {
                                              debugPrint('Manual sync failed: $e');
                                            }
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: colors.hairline, width: 0.5),
                                        color: colors.bg,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (active) ...[
                                            SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: colors.accent,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            active 
                                                ? 'Syncing...' 
                                                : limitBlocked 
                                                    ? 'Upgrade to Sync' 
                                                    : 'Sync Now',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: colors.accent,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _metricRow(String label, String value, ResolvedColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.text,
          ),
        ),
      ],
    );
  }

  Widget _profileCard(
    BuildContext context,
    ResolvedColors colors,
    PreferencesState prefs,
  ) {
    return StreamBuilder<AuthState>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        final auth = AuthService();
        final isSignedIn = auth.isSignedIn;
        final email = auth.currentUserEmail;
        final name = auth.currentUserDisplayName;
        final avatarUrl = auth.currentUserAvatarUrl;

        if (isSignedIn) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.hairline, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceElevated,
                    border: Border.all(color: colors.hairline, width: 0.5),
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.currentUserJoinedDate,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.textTertiary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    AppHaptics.light();
                    final prefs = Provider.of<PreferencesState>(context, listen: false);
                    if (prefs.biometricLock) {
                      prefs.toggleBiometricLock();
                    }
                    if (context.mounted) {
                      context.read<MemoryState>().clearMemory();
                    }
                    await auth.signOut();
                    if (context.mounted) {
                      _navigateToAuthScreen(context);
                    }
                  },
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.error,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.hairline, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sync & Preservation',
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in with Google to secure your emotional sanctuary across devices.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final paywall = context.read<PaywallService>();
                  if (paywall.checkGate(ProFeature.cloudSync) != null) {
                    await PaywallSheet.show(context, ProFeature.cloudSync);
                    return;
                  }
                  AppHaptics.light();
                  widget.setLoading(true);
                  try {
                    await auth.signInWithGoogle();
                  } on AuthException catch (e) {
                    auth.clearOAuthProgress();
                    widget.setLoading(false);
                    final msg = e.message.toLowerCase();
                    final isCancel = msg.contains('cancel') || msg.contains('dismiss') || msg.contains('user closed');
                    if (!isCancel) {
                      widget.showAuthError(e.message);
                    }
                  } catch (e) {
                    auth.clearOAuthProgress();
                    widget.setLoading(false);
                    final msg = e.toString().toLowerCase();
                    final isNetwork = msg.contains('socketexception') || msg.contains('network') || msg.contains('failed to connect');
                    final errMessage = isNetwork 
                        ? 'No internet connection detected. Please check your network.' 
                        : 'Google sign-in error: $e';
                    widget.showAuthError(errMessage);
                  } finally {
                    Future.delayed(const Duration(seconds: 15), () {
                      widget.setLoading(false);
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.bg,
                    border: Border.all(color: colors.hairline, width: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.g_mobiledata_rounded, size: 24, color: colors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExportSheet(BuildContext context, ResolvedColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.hairline, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colors.hairline,
                ),
              ),
            ),
            Text(
              'Export Archive',
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 22,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your memories, in your hands.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _exportOption(context, colors, Icons.code_rounded, 'JSON',
                'Raw structured data'),
            const SizedBox(height: 12),
            _exportOption(context, colors, Icons.text_snippet_rounded,
                'Markdown', 'Formatted text'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _exportOption(
    BuildContext context,
    ResolvedColors colors,
    IconData icon,
    String format,
    String desc,
  ) {
    return GestureDetector(
      onTap: () => _performExport(context, format),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.bg,
          border: Border.all(color: colors.hairline, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performExport(BuildContext context, String format) async {
    Navigator.pop(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Exporting to $format...')),
    );

    try {
      final entries = context.read<MemoryState>().entries;
      String output = '';
      String fileExtension = '';

      if (format == 'JSON') {
        fileExtension = 'json';
        final data = entries.map((e) => e.toMap()).toList();
        output = const JsonEncoder.withIndent('  ').convert(data);
      } else {
        fileExtension = 'md';
        final buffer = StringBuffer();
        buffer.writeln('# Antheia Memory Sanctuary Export');
        buffer.writeln('Exported on: ${DateTime.now().toLocal()}\n');
        for (final entry in entries) {
          buffer.writeln('## ${entry.title}');
          buffer.writeln('*Date: ${entry.createdAt.toLocal()}*  ');
          if (entry.location != null) {
            buffer.writeln('*Location: ${entry.location}*  ');
          }
          if (entry.temperature != null) {
            buffer.writeln('*Temperature: ${entry.temperature}°C ${entry.weatherIcon ?? ""}*  ');
          }
          if (entry.tags.isNotEmpty) {
            buffer.writeln('*Tags: ${entry.tags.join(", ")}*  ');
          }
          buffer.writeln('\n${entry.content}\n');
          buffer.writeln('--- \n');
        }
        output = buffer.toString();
      }

      // Copy to Clipboard
      await Clipboard.setData(ClipboardData(text: output));

      // Save to Local Documents
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/antheia_memories_export.$fileExtension');
      await file.writeAsString(output);

      // Share natively via OS Share Sheet
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Antheia Memory Export',
      );

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Exported! Copied to clipboard & shared: ${file.path.split("/").last}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    ResolvedColors colors,
    MemoryState memory,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: Border.all(color: colors.hairline, width: 0.5),
        title: Text(
          'Delete all memories?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Text(
          'This permanently deletes all your memories. This cannot be undone.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await memory.deleteAllData();
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAuthScreen(BuildContext context) {
    final biometric = Provider.of<BiometricState>(context, listen: false);
    biometric.unlock();
    biometric.setPrivacyCurtain(false);
    biometric.setBiometricsRemoved(false);

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
      (route) => false,
    );
  }

  void _navigateToOnboardingScreen(BuildContext context) {
    final biometric = Provider.of<BiometricState>(context, listen: false);
    biometric.unlock();
    biometric.setPrivacyCurtain(false);
    biometric.setBiometricsRemoved(false);

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
      (route) => false,
    );
  }

  void _showResetDialog(BuildContext context, ResolvedColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.hairline, width: 0.5),
        ),
        title: Text(
          'Reset App & Onboarding?',
          style: TextStyle(fontFamily: 'Inter', color: colors.text),
        ),
        content: Text(
          'This will clear your local preferences, reset your onboarding status, and log you out. Your local memories will remain intact.',
          style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final prefs = Provider.of<PreferencesState>(context, listen: false);
              await prefs.resetPreferences();
              if (context.mounted) {
                context.read<MemoryState>().clearMemory();
              }
              await AuthService().signOut();
              if (context.mounted) {
                _navigateToOnboardingScreen(context);
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCloudDeleteDialog(BuildContext context, ResolvedColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.surface,
        shape: Border.all(color: colors.hairline, width: 0.5),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete Cloud Account & Data?',
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone. It will permanently purge all cloud backups and remote user accounts from Supabase, wipe your local memory database, and log you out.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Purging cloud data & account...')),
                      );

                      try {
                        context.read<MemoryState>().clearMemory();
                        
                        final prefs = Provider.of<PreferencesState>(context, listen: false);
                        await prefs.resetPreferences();
                        
                        await DatabaseService().deleteCloudAccount();
                        
                        if (context.mounted) {
                          _navigateToOnboardingScreen(context);
                        }
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Deletion failed: $e')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        border: Border.all(color: colors.error, width: 0.5),
                      ),
                      child: Text(
                        'Confirm Purge',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.error,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRESENCE TAB
// ═══════════════════════════════════════════════════════════════
class _PresenceTab extends StatelessWidget {
  const _PresenceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<PreferencesState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Security & Presence', colors),
        const SizedBox(height: 8),
        _panel(
          colors: colors,
          child: _settingRow(
            label: 'Biometric lock',
            subtitle: 'Face ID or fingerprint on open',
            icon: Icons.fingerprint_rounded,
            trailing: Switch(
              value: prefs.biometricLock,
              onChanged: (_) => prefs.toggleBiometricLock(),
              activeThumbColor: colors.accent,
              activeTrackColor: colors.accent.withOpacity(0.5),
            ),
            colors: colors,
          ),
        ),
        _divider(colors),
        _sectionLabel('Reflection Settings', colors),
        const SizedBox(height: 8),
        _panel(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reflection tone', style: _body(colors)),
              const SizedBox(height: 4),
              Text(
                'Controls how voice entries are shaped and restructured.',
                style: _caption(colors),
              ),
              const SizedBox(height: 12),
              _pills(
                options: const ['Thoughtful', 'Lyrical', 'Direct'],
                selected: prefs.reflectionTone,
                onChanged: prefs.setReflectionTone,
                colors: colors,
              ),
              const SizedBox(height: 20),
              Text('Formatting depth', style: _body(colors)),
              const SizedBox(height: 4),
              Text(
                'How much structure is added to voice reflections.',
                style: _caption(colors),
              ),
              const SizedBox(height: 12),
              _pills(
                options: const ['Light', 'Medium', 'Rich'],
                selected: prefs.autoFormatting,
                onChanged: prefs.setAutoFormatting,
                colors: colors,
              ),
            ],
          ),
        ),
        _divider(colors),
        _sectionLabel('About', colors),
        const SizedBox(height: 8),
        _panel(
          colors: colors,
          child: Column(
            children: [
              _settingRow(
                label: 'Privacy policy',
                icon: Icons.privacy_tip_outlined,
                trailing: Icon(Icons.chevron_right_rounded,
                    color: colors.textTertiary, size: 20),
                colors: colors,
                onTap: () => _showInfo(
                  context,
                  colors,
                  'Privacy Policy',
                  'Your journal entries are stored locally on your device in a private database.\n\n'
                  'When you record a voice entry, your spoken words are transcribed on-device '
                  'and the text transcript is sent to an AI service (such as Groq or Google Gemini) '
                  'to generate a structured reflection. Your audio is not stored after transcription.\n\n'
                  'We do not sell your data or use it for advertising. '
                  'For our full privacy policy, visit antheia.app/privacy.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, color: colors.hairline.withOpacity(0.5)),
              ),
              _settingRow(
                label: 'Help & feedback',
                icon: Icons.help_outline_rounded,
                trailing: Icon(Icons.chevron_right_rounded,
                    color: colors.textTertiary, size: 20),
                colors: colors,
                onTap: () => _showInfo(
                  context,
                  colors,
                  'Help & Feedback',
                  'For support and preservation queries, reach us at support@antheia.app.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showInfo(
    BuildContext context,
    ResolvedColors colors,
    String title,
    String content,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: Border.all(color: colors.hairline, width: 0.5),
        title: Text(title, style: TextStyle(color: colors.text, fontFamily: 'Cormorant Garamond', fontStyle: FontStyle.italic, fontSize: 20)),
        content: Text(content, style: TextStyle(color: colors.textSecondary, fontFamily: 'Inter', fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: colors.accent, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER COMMON WIDGETS AND STYLES
// ═══════════════════════════════════════════════════════════════

Widget _sectionLabel(String text, ResolvedColors colors) {
  return Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: colors.accent,
      ),
    ),
  );
}

Widget _divider(ResolvedColors colors) =>
    Divider(height: 1, color: colors.hairline);

Widget _statPill(String value, String label, ResolvedColors colors) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.hairline, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity((colors.bg.computeLuminance() < 0.5) ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _settingRow({
  required String label,
  String? subtitle,
  Color? labelColor,
  IconData? icon,
  Color? iconColor,
  required Widget trailing,
  required ResolvedColors colors,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: () {
      if (onTap != null) {
        AppHaptics.light();
        onTap();
      }
    },
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor ?? colors.accent),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: labelColor ?? colors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    ),
  );
}

Widget _pills({
  required List<String> options,
  required String selected,
  required ValueChanged<String> onChanged,
  required ResolvedColors colors,
}) {
  return Row(
    children: options.map((option) {
      final isActive = selected == option;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            AppHaptics.light();
            onChanged(option);
          },
          child: AnimatedContainer(
            duration: AppTransitions.short,
            margin: EdgeInsets.only(right: option != options.last ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? colors.accent : colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? colors.accent : colors.hairline,
                width: 0.5,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: colors.accent.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ] : null,
            ),
            child: Text(
              option,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? colors.bg : colors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

Widget _panel({required ResolvedColors colors, required Widget child}) {
  final isDark = colors.bg.computeLuminance() < 0.5;
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8,
          sigmaY: 8,
          tileMode: TileMode.decal,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surface.withValues(alpha: 0.7)
                  : colors.surface.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.hairline,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

TextStyle _body(ResolvedColors colors) => TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colors.text,
    );

TextStyle _caption(ResolvedColors colors) => TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      color: colors.textTertiary,
    );

class _JournalCardMockup extends StatelessWidget {
  final ResolvedColors themeColors;
  final String font;
  final bool active;

  const _JournalCardMockup({
    required this.themeColors,
    required this.font,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle titleStyle;
    if (font == 'Caveat') {
      titleStyle = TextStyle(
        fontFamily: 'Caveat',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: themeColors.accent,
        height: 1.0,
      );
    } else if (font == 'Cormorant Garamond' || font == 'Playfair Display' || font == 'Lora') {
      titleStyle = TextStyle(
        fontFamily: font,
        fontSize: 7.5,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: themeColors.accent,
        height: 1.0,
      );
    } else {
      titleStyle = TextStyle(
        fontFamily: font,
        fontSize: 6.5,
        fontWeight: FontWeight.bold,
        color: themeColors.accent,
        height: 1.0,
      );
    }

    return Container(
      width: 58,
      height: 38,
      decoration: BoxDecoration(
        color: themeColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? themeColors.accent.withOpacity(0.5) : themeColors.hairline,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            font == 'Caveat' ? 'My thoughts' : 'Quiet Memory',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            height: 2.0,
            decoration: BoxDecoration(
              color: themeColors.textSecondary.withOpacity(0.35),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 32,
            height: 2.0,
            decoration: BoxDecoration(
              color: themeColors.textTertiary.withOpacity(0.25),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
