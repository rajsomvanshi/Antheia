import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_theme.dart';

// ═══════════════════════════════════════════════════════════════
// GlassSurface — Liquid Glass Building Block
//
// A frosted-glass container with backdrop blur, translucent fill,
// and a subtle luminous border. Adapts to light/dark mode and
// respects AnimationIntensity (falls back to solid surface when
// motion is disabled).
//
// Usage:
//   GlassSurface(
//     child: Text('Hello'),
//     blur: 12,
//     opacity: 0.12,
//   )
// ═══════════════════════════════════════════════════════════════

class GlassSurface extends StatelessWidget {
  final Widget child;

  /// Blur sigma. Higher = more frosted. Default: 12.
  final double blur;

  /// Override fill opacity. If null, auto-adapts for dark/light.
  final double? opacity;

  /// Override border opacity. If null, auto-adapts for dark/light.
  final double? borderOpacity;

  /// Corner radius. Default: 20.
  final BorderRadius? borderRadius;

  /// Padding inside the glass surface.
  final EdgeInsetsGeometry? padding;

  /// Margin around the glass surface.
  final EdgeInsetsGeometry? margin;

  /// Whether to show the subtle luminous border.
  final bool showBorder;

  /// Whether to add a subtle shadow beneath for depth.
  final bool showShadow;

  /// Optional override color for the fill tint.
  final Color? tintColor;

  const GlassSurface({
    super.key,
    required this.child,
    this.blur = 12,
    this.opacity,
    this.borderOpacity,
    this.borderRadius,
    this.padding,
    this.margin,
    this.showBorder = true,
    this.showShadow = false,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final intensity = AnimationScale.of(context);

    // When motion is fully disabled, fall back to a solid surface
    if (intensity == AnimationIntensity.stillness) {
      return _buildSolidFallback(colors);
    }

    final resolvedRadius = borderRadius ?? BorderRadius.circular(20);

    // Adaptive fill: darker themes need less fill, lighter themes need more
    final fillOpacity = opacity ?? (isDark ? 0.08 : 0.40);
    final edgeOpacity = borderOpacity ?? (isDark ? 0.12 : 0.20);
    final fill = tintColor?.withValues(alpha: fillOpacity) ??
        (isDark
            ? Colors.white.withValues(alpha: fillOpacity)
            : Colors.white.withValues(alpha: fillOpacity));
    final borderColor = isDark
        ? Colors.white.withValues(alpha: edgeOpacity)
        : Colors.white.withValues(alpha: edgeOpacity * 1.5);

    // Depth shadow
    final shadow = showShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ]
        : <BoxShadow>[];

    return RepaintBoundary(
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: resolvedRadius,
          boxShadow: shadow,
        ),
        child: ClipRRect(
          borderRadius: resolvedRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: resolvedRadius,
                border: showBorder
                    ? Border.all(color: borderColor, width: 0.5)
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolidFallback(ResolvedColors colors) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: showBorder
            ? Border.all(color: colors.hairline, width: 0.5)
            : null,
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GlassNavBar — Specialized glass surface for bottom navigation
//
// Extends the full width, clips at the top only, applies a
// gradient fade from transparent to blurred for a smooth
// content-to-glass transition.
// ═══════════════════════════════════════════════════════════════

class GlassNavBar extends StatelessWidget {
  final Widget child;
  final double height;
  final double bottomPadding;

  const GlassNavBar({
    super.key,
    required this.child,
    required this.height,
    this.bottomPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final intensity = AnimationScale.of(context);
    final colors = AppColors.of(context);

    // Solid fallback when motion is disabled
    if (intensity == AnimationIntensity.stillness) {
      return Container(
        height: height + bottomPadding,
        decoration: BoxDecoration(
          color: colors.bg,
          border: Border(
            top: BorderSide(color: colors.hairline, width: 0.5),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: child,
        ),
      );
    }

    final fillColor = isDark
        ? colors.bg.withValues(alpha: 0.65)
        : colors.bg.withValues(alpha: 0.60);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
          tileMode: TileMode.decal,
        ),
        child: Container(
          height: height + bottomPadding,
          decoration: BoxDecoration(
            color: fillColor,
            border: Border(
              top: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
