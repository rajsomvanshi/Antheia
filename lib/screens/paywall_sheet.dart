import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/paywall_service.dart';
import '../services/revenuecat_service.dart';
import '../theme/app_theme.dart';

class PaywallSheet extends StatefulWidget {
  final ProFeature blockedBy;
  const PaywallSheet({super.key, required this.blockedBy});

  static Future<bool> show(BuildContext context, ProFeature feature) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallSheet(blockedBy: feature),
    );
    return result ?? false;
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  String _priceText = '₹199 / month  ·  ₹1,499 / year'; // Fallback / default
  bool _loadingPrice = true;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    try {
      final offerings = await RevenueCatService().fetchOfferings();
      final current = offerings?.current;
      final monthly = current?.monthly?.storeProduct.priceString;
      final annual  = current?.annual?.storeProduct.priceString;

      if (mounted) {
        final parts = <String>[
          if (monthly != null) '$monthly / mo',
          if (annual  != null) '$annual / yr',
        ];
        setState(() {
          if (parts.isNotEmpty) {
            _priceText = parts.join('  ·  ');
          }
          _loadingPrice = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  String get _headline => switch (widget.blockedBy) {
    ProFeature.unlimitedEntries => 'You\'ve filled your journal',
    ProFeature.cloudSync        => 'Sync across all your devices',
    ProFeature.mapView          => 'See where your memories were made',
    ProFeature.narration        => 'Hear your memories read back to you',
    ProFeature.unlimitedMedia   => 'Add more photos to your memories',
    ProFeature.export           => 'Export your journal',
    ProFeature.themes           => 'Make it yours',
    _                           => 'Unlock everything',
  };

  String get _subtext => switch (widget.blockedBy) {
    ProFeature.unlimitedEntries => 'Free journals hold 30 memories. Go Pro for unlimited.',
    ProFeature.cloudSync        => 'Your memories backed up safely. Never lose a thought.',
    ProFeature.mapView          => 'Every memory pinned to the place it happened.',
    ProFeature.narration        => 'A quiet voice reads your past back to you.',
    ProFeature.unlimitedMedia   => 'Free plan includes 5 cover photos.',
    ProFeature.export           => 'Save your journal as Markdown or JSON anytime.',
    ProFeature.themes           => 'Choose fonts, themes, and reading modes.',
    _                           => 'Unlock all features with Pro.',
  };

  static const _features = [
    (Icons.all_inclusive_rounded,     'Unlimited entries'),
    (Icons.cloud_sync_outlined,       'Sync across devices'),
    (Icons.map_outlined,              'Memory map'),
    (Icons.volume_up_outlined,        'Narration'),
    (Icons.photo_library_outlined,    'Unlimited photos'),
    (Icons.picture_as_pdf_outlined,   'Export to Markdown/JSON'),
    (Icons.palette_outlined,          'Themes & fonts'),
  ];

  Future<void> _handlePurchase(BuildContext context) async {
    try {
      final offerings = await RevenueCatService().fetchOfferings();
      final current = offerings?.current;
      final package = current?.annual ?? current?.monthly;
      if (package == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No store offerings available at this time.')),
          );
        }
        return;
      }
      final info = await RevenueCatService().purchasePackage(package);
      final success = RevenueCatService().isPremiumActive(info);
      if (success) {
        if (context.mounted) {
          await context.read<PaywallService>().activatePro();
          if (context.mounted) Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      debugPrint('[PaywallSheet] Purchase error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase could not be completed: $e')),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    try {
      final info = await RevenueCatService().restorePurchases();
      final success = RevenueCatService().isPremiumActive(info);
      if (success) {
        if (context.mounted) {
          await context.read<PaywallService>().activatePro();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Welcome back. Pro tier active.')),
            );
            Navigator.of(context).pop(true);
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active subscription found.')),
          );
        }
      }
    } catch (e) {
      debugPrint('[PaywallSheet] Restore error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e')),
        );
      }
    }
  }

  Widget _buildPricePill(ResolvedColors colors) {
    if (_loadingPrice) {
      return SizedBox(
        height: 28,
        child: Center(
          child: SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.accent,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _priceText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: colors.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AnimationScale.of(context) == AnimationIntensity.stillness ? 0 : 20,
          sigmaY: AnimationScale.of(context) == AnimationIntensity.stillness ? 0 : 20,
          tileMode: TileMode.decal,
        ),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? colors.bg.withValues(alpha: 0.80)
                : colors.bg.withValues(alpha: 0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: colors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Headline
            Text(
              _headline,
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: colors.text,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtext,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // Feature list
            ...List.generate(_features.length, (index) {
              final f = _features[index];
              return _StaggeredFeatureRow(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(f.$1, size: 18, color: colors.accent),
                      const SizedBox(width: 12),
                      Text(f.$2, style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: colors.text,
                      )),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 28),

            // Price pill
            _buildPricePill(colors),

            const SizedBox(height: 16),

            // CTA button
            GestureDetector(
              onTap: () => _handlePurchase(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Start free 7-day trial',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Restore + cancel
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _handleRestore(context),
                  child: Text('Restore purchase',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textFaint,
                    ),
                  ),
                ),
                Text('·', style: TextStyle(color: colors.textFaint)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Not now',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
}

class _StaggeredFeatureRow extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredFeatureRow({required this.index, required this.child});

  @override
  State<_StaggeredFeatureRow> createState() => _StaggeredFeatureRowState();
}

class _StaggeredFeatureRowState extends State<_StaggeredFeatureRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(-8.0, 0.0), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _start();
  }

  void _start() async {
    final scale = AnimationScale.of(context).durationScale;
    if (scale == 0.0) {
      if (mounted) {
        _controller.value = 1.0;
      }
      return;
    }
    await Future.delayed(Duration(milliseconds: (widget.index * 60 * scale).round()));
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = AnimationScale.of(context).durationScale;
    if (scale == 0.0) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _slide.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
