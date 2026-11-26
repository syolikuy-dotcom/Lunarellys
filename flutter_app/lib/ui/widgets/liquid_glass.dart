import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final Color? borderColor;
  final double borderWidth;
  final bool showSpecularHighlight;
  final bool enableBlur;
  final bool animate;
  final List<BoxShadow>? shadows;
  final Duration duration;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blurSigma = 13,
    this.padding,
    this.margin,
    this.tintColor,
    this.borderColor,
    this.borderWidth = 0.85,
    this.showSpecularHighlight = false,
    this.enableBlur = false,
    this.animate = false,
    this.shadows,
    this.duration = const Duration(milliseconds: 240),
  });

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ?? const Color(0xFF141B23);
    final rim = borderColor ?? Colors.white.withAlpha(20);
    final sigma = blurSigma.clamp(0.0, 14.0);

    final innerDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(enableBlur ? 16 : 14),
          tint.withAlpha(enableBlur ? 140 : 162),
          tint.withAlpha(enableBlur ? 178 : 204),
        ],
        stops: const [0.0, 0.4, 1.0],
      ),
      border: Border.all(
        color: rim,
        width: borderWidth,
      ),
    );

    final Widget surfaceBody = animate
        ? AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            padding: padding,
            decoration: innerDecoration,
            child: child,
          )
        : Container(
            padding: padding,
            decoration: innerDecoration,
            child: child,
          );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withAlpha(56),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: enableBlur && sigma > 0.5
          ? RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: surfaceBody,
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: surfaceBody,
            ),
    );
  }
}

class LiquidGlassCapsule extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final Color? borderColor;
  final bool enableBlur;

  const LiquidGlassCapsule({
    super.key,
    required this.child,
    this.blurSigma = 13,
    this.padding,
    this.margin,
    this.tintColor,
    this.borderColor,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: 999,
      blurSigma: blurSigma,
      padding: padding,
      margin: margin,
      tintColor: tintColor,
      borderColor: borderColor ?? Colors.white.withAlpha(22),
      enableBlur: enableBlur,
      child: child,
    );
  }
}

class LiquidGlassAmbientBackground extends StatelessWidget {
  final Color? accentColor;
  final Widget child;

  const LiquidGlassAmbientBackground({
    super.key,
    this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.brandGreen;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  gradient: RadialGradient(
                    center: const Alignment(-0.75, -0.85),
                    radius: 1.2,
                    colors: [
                      accent.withAlpha(48),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.85, -0.2),
                    radius: 1.15,
                    colors: [
                      AppColors.lunarCyan.withAlpha(24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withAlpha(14),
                  const Color(0xE2131A22),
                  const Color(0xF40B0F14),
                ],
                stops: const [0.0, 0.16, 1.0],
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withAlpha(22), width: 0.9),
                left: BorderSide(color: Colors.white.withAlpha(14), width: 0.8),
                right: BorderSide(color: Colors.white.withAlpha(14), width: 0.8),
              ),
            ),
            child: SafeArea(
              top: false,
              child: builder(ctx),
            ),
          ),
        ),
      ),
    ),
  );
}
