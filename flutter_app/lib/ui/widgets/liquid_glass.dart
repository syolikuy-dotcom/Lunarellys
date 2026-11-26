import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/settings_provider.dart';

class LiquidGlassSurface extends ConsumerWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final Color? chromaticAccent;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showBorder;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 24,
    this.tintColor,
    this.chromaticAccent,
    this.padding,
    this.margin,
    this.showBorder = true,
    this.gradient,
    this.shadows,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDark(context);
    final style = ref.watch(settingsProvider.select((s) => s.appearanceStyle));
    final isGlass = style == AppAppearanceStyle.glass;

    final effectiveTint = tintColor ??
        (isDark
            ? (isGlass ? const Color(0xCC161A22) : AppColors.darkSurface)
            : (isGlass ? const Color(0xDBFFFFFF) : AppColors.lightSurface));

    final borderCol = isDark
        ? Colors.white.withAlpha(isGlass ? 32 : 18)
        : (isGlass ? Colors.white.withAlpha(235) : AppColors.lightBorder);

    final boxShadow = shadows ??
        [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 76 : (isGlass ? 22 : 10)),
            blurRadius: isGlass ? 26 : 14,
            offset: const Offset(0, 8),
          ),
        ];

    final accent = chromaticAccent;
    final secondaryChromatic = accent != null
        ? HSLColor.fromColor(accent)
            .withHue((HSLColor.fromColor(accent).hue + 145) % 360)
            .withSaturation(0.55)
            .toColor()
        : null;

    Widget content = child;
    if (isGlass && accent != null && secondaryChromatic != null) {
      content = Stack(
        children: [
          Positioned(
            left: -18,
            top: -16,
            bottom: -16,
            width: 112,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.2, 0.1),
                    radius: 0.95,
                    colors: [
                      accent.withAlpha(isDark ? 78 : 72),
                      accent.withAlpha(isDark ? 24 : 20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -18,
            top: -16,
            bottom: -16,
            width: 108,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.2, -0.1),
                    radius: 0.95,
                    colors: [
                      secondaryChromatic.withAlpha(isDark ? 64 : 56),
                      secondaryChromatic.withAlpha(isDark ? 18 : 16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Specular top highlight rim inside glass
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            height: 1.2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withAlpha(isDark ? 65 : 220),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ],
      );
    } else if (padding != null) {
      content = Padding(padding: padding!, child: child);
    }

    Widget inner = Container(
      decoration: BoxDecoration(
        color: gradient == null ? effectiveTint : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: showBorder ? Border.all(color: borderCol, width: 1.0) : null,
      ),
      child: content,
    );

    if (isGlass && blurSigma > 0) {
      inner = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: inner,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: inner,
      ),
    );
  }
}

class LiquidGlassCapsule extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final Color? tintColor;
  final Color? chromaticAccent;
  final double radius;

  const LiquidGlassCapsule({
    super.key,
    required this.child,
    this.padding,
    this.blurSigma = 24,
    this.tintColor,
    this.chromaticAccent,
    this.radius = 999,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(radius),
      blurSigma: blurSigma,
      tintColor: tintColor,
      chromaticAccent: chromaticAccent,
      padding: padding,
      child: child,
    );
  }
}

/// Spring-like iOS 27 tactile scale feedback wrapper
class LiquidGlassTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const LiquidGlassTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptic = true,
  });

  @override
  State<LiquidGlassTap> createState() => _LiquidGlassTapState();
}

class _LiquidGlassTapState extends State<LiquidGlassTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
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
    final isDark = AppColors.isDark(context);
    final baseBg = AppColors.bgOf(context);
    final accent = accentColor;

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: baseBg),
        ),
        if (accent != null)
          Positioned(
            top: -120,
            left: -80,
            right: -80,
            height: 360,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 520),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 1.05,
                    colors: [
                      accent.withAlpha(isDark ? 68 : 26),
                      accent.withAlpha(isDark ? 18 : 8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

/// Warm layered Percikan streak flame icon matching screenshots
class PercikanFlameIcon extends StatelessWidget {
  final double size;
  const PercikanFlameIcon({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.15,
            height: size * 1.15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFF8C24).withAlpha(65),
                  const Color(0xFFFFB347).withAlpha(22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          CustomPaint(
            size: Size.square(size),
            painter: _PercikanFlamePainter(),
          ),
        ],
      ),
    );
  }
}

class _PercikanFlamePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final outer = Path()
      ..moveTo(w * 0.52, h * 0.08)
      ..cubicTo(w * 0.62, h * 0.25, w * 0.84, h * 0.38, w * 0.82, h * 0.63)
      ..cubicTo(w * 0.80, h * 0.83, w * 0.66, h * 0.92, w * 0.50, h * 0.92)
      ..cubicTo(w * 0.30, h * 0.92, w * 0.18, h * 0.78, w * 0.20, h * 0.58)
      ..cubicTo(w * 0.22, h * 0.43, w * 0.34, h * 0.33, w * 0.38, h * 0.22)
      ..cubicTo(w * 0.41, h * 0.32, w * 0.45, h * 0.34, w * 0.47, h * 0.26)
      ..cubicTo(w * 0.49, h * 0.18, w * 0.50, h * 0.13, w * 0.52, h * 0.08)
      ..close();

    final outerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF7A1A), Color(0xFFFF982E)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(outer, outerPaint);

    final mid = Path()
      ..moveTo(w * 0.53, h * 0.35)
      ..cubicTo(w * 0.64, h * 0.48, w * 0.72, h * 0.58, w * 0.70, h * 0.71)
      ..cubicTo(w * 0.68, h * 0.84, w * 0.59, h * 0.89, w * 0.50, h * 0.89)
      ..cubicTo(w * 0.37, h * 0.89, w * 0.30, h * 0.79, w * 0.32, h * 0.66)
      ..cubicTo(w * 0.34, h * 0.54, w * 0.45, h * 0.47, w * 0.53, h * 0.35)
      ..close();

    canvas.drawPath(mid, Paint()..color = const Color(0xFFFFB636));

    final core = Path()
      ..moveTo(w * 0.51, h * 0.58)
      ..cubicTo(w * 0.58, h * 0.66, w * 0.62, h * 0.73, w * 0.60, h * 0.80)
      ..cubicTo(w * 0.58, h * 0.86, w * 0.54, h * 0.88, w * 0.49, h * 0.88)
      ..cubicTo(w * 0.43, h * 0.88, w * 0.40, h * 0.82, w * 0.41, h * 0.75)
      ..cubicTo(w * 0.42, h * 0.68, w * 0.47, h * 0.64, w * 0.51, h * 0.58)
      ..close();

    canvas.drawPath(core, Paint()..color = const Color(0xFFFFEA8A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compact Percikan streak banner shared across Beranda and Kamu
class PercikanBannerCard extends StatelessWidget {
  final int streakDays;
  final VoidCallback onTap;

  const PercikanBannerCard({
    super.key,
    required this.streakDays,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final card = isDark ? AppColors.darkSurface : Colors.white;
    final border = AppColors.borderOf(context);

    return LiquidGlassTap(
      onTap: onTap,
      child: Container(
        height: 82,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border.withAlpha(isDark ? 120 : 180), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 36 : 8),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -12,
              top: -12,
              bottom: -12,
              width: 112,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.1, 0),
                    radius: 0.9,
                    colors: [
                      const Color(0xFFFF9F43).withAlpha(isDark ? 45 : 40),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const PercikanFlameIcon(size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$streakDays',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'hari berturut-turut',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Percikan',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: sub,
                          ),
                        ),
                      ],
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
}

Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double maxHeightFactor = 0.90,
}) {
  final isDark = AppColors.isDark(context);
  final surface = AppColors.cardOf(context);
  final handleColor = isDark ? Colors.white.withAlpha(64) : const Color(0xFFD0D4DC);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(isDark ? 150 : 95),
    builder: (ctx) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * maxHeightFactor,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 120 : 35),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      );
    },
  );
}
