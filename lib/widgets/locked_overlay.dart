import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/paywall_service.dart';
import '../screens/paywall_sheet.dart';
import '../theme/app_theme.dart';

class LockedOverlay extends StatelessWidget {
  final ProFeature feature;
  final Widget child;

  const LockedOverlay({
    super.key,
    required this.feature,
    required this.child,
  });

  String get _subtext => switch (feature) {
    ProFeature.unlimitedEntries => 'Free journals hold 30 memories. Go Pro for unlimited.',
    ProFeature.cloudSync        => 'Your memories backed up safely. Never lose a thought.',
    ProFeature.mapView          => 'Every memory pinned to the place it happened.',
    ProFeature.narration        => 'A quiet voice reads your past back to you.',
    ProFeature.unlimitedMedia   => 'Free plan includes 5 cover photos.',
    ProFeature.export           => 'Save your journal as Markdown or JSON anytime.',
    ProFeature.themes           => 'Choose fonts, themes, and reading modes.',
    _                           => 'Unlock all features with Pro.',
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        // The real screen, blurred behind
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: IgnorePointer(child: child),
        ),
        // Lock card on top
        Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.hairline, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 32, color: colors.accent),
                const SizedBox(height: 12),
                Text(
                  'Pro feature',
                  style: TextStyle(
                    fontFamily: 'Cormorant Garamond',
                    fontSize: 22,
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtext,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => PaywallSheet.show(context, feature),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Unlock Pro',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
