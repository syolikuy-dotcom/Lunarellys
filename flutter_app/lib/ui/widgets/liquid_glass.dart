import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/settings_provider.dart';

/// Singleton loader for the GPU Liquid Glass fragment shader
/// (`shaders/liquid_glass_ios27.frag`). Never blocks or throws on unsupported GPUs.
class LiquidGlassShaderEngine {
  static FragmentProgram? _program;
  static Future<void>? _loading;

  static FragmentProgram? get program => _program;

  static Future<void> ensureLoaded() {
    if (_program != null) return Future<void>.value();
    return _loading ??= _loadInternal();
  }

  static Future<void> _loadInternal() async {
    try {
      _program = await FragmentProgram.fromAsset('shaders/liquid_glass_ios27.frag');
    } catch (_) {
      _program = null;
    }
  }
}

class _LiquidGlassPressScope extends InheritedWidget {
  final double pressIntensity;

  const _LiquidGlassPressScope({
    required this.pressIntensity,
    required super.child,
  });

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_LiquidGlassPressScope>()
            ?.pressIntensity ??
        0.0;
  }

  @override
  bool updateShouldNotify(covariant _LiquidGlassPressScope oldWidget) =>
      oldWidget.pressIntensity != pressIntensity;
}

/// Authentic Apple Liquid Glass surface:
/// - GPU GLSL optical bevel & chromatic dispersion (`liquid_glass_ios27.frag`)
/// - Granular transparency control (`liquidGlassOpacity`: Clear <-> Tinted)
/// - Improved content diffusion (`TileMode.clamp` scaled Gaussian backdrop)
/// - Darkened perimeter contrast edges + brighter dual-balanced specular highlights
class LiquidGlassSurface extends ConsumerWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final Color? chromaticAccent;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showBorder;
  final bool useBackdropBlur;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.blurSigma = 30,
    this.tintColor,
    this.chromaticAccent,
    this.padding,
    this.margin,
    this.showBorder = true,
    this.useBackdropBlur = true,
    this.gradient,
    this.shadows,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDark(context);
    final isGlass = ref.watch(
      settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
    );
    final glassOpacity = ref.watch(
      settingsProvider.select((s) => s.liquidGlassOpacity),
    );
    final pressIntensity = _LiquidGlassPressScope.of(context);

    // iOS 27 Transparency Slider mapping (0.0 Ultra Clear -> 0.48 Balanced -> 1.0 Tinted)
    final clearAlpha = isDark ? 44 : 58;
    final tintedAlpha = isDark ? 228 : 232;
    final dynamicAlpha = lerpDouble(clearAlpha, tintedAlpha, glassOpacity)!.round();

    final baseTint = tintColor != null
        ? tintColor!.withAlpha(
            lerpDouble(
              (tintColor!.a * 255).round().clamp(45, 195),
              235,
              glassOpacity * 0.55,
            )!
                .round(),
          )
        : (isDark
            ? (isGlass
                ? const Color(0xFF141922).withAlpha(dynamicAlpha)
                : AppColors.darkSurface)
            : (isGlass
                ? const Color(0xFFFFFFFF).withAlpha(dynamicAlpha)
                : AppColors.lightSurface));

    final boxShadow = shadows ??
        [
          BoxShadow(
            color: Colors.black.withAlpha(
              isDark ? 105 : (isGlass ? (24 + (glassOpacity * 16).round()) : 12),
            ),
            blurRadius: isGlass ? 26 : 14,
            spreadRadius: isGlass ? -2 : 0,
            offset: const Offset(0, 10),
          ),
          if (isGlass && !isDark)
            BoxShadow(
              color: Colors.white.withAlpha((110 - glassOpacity * 35).round()),
              blurRadius: 10,
              offset: const Offset(0, -1),
            ),
        ];

    final accent = chromaticAccent;
    final secondaryChromatic = accent != null
        ? HSLColor.fromColor(accent)
            .withHue((HSLColor.fromColor(accent).hue + 145) % 360)
            .withSaturation(0.64)
            .toColor()
        : null;

    Widget innerContent = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    if (isGlass) {
      final shaderProgram = LiquidGlassShaderEngine.program;
      final effectiveAccent = accent ??
          (isDark ? const Color(0xFF5D92CC) : const Color(0xFF7CA7D6));

      innerContent = Stack(
        children: [
          // GPU GLSL iOS 27 optical bevel, darkened edge, and specular highlight pass
          if (gradient == null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: shaderProgram != null
                      ? _Ios27ShaderGlassPainter(
                          program: shaderProgram,
                          borderRadius: borderRadius,
                          transparency: glassOpacity,
                          isDark: isDark,
                          pressIntensity: pressIntensity,
                          tintColor: tintColor ?? effectiveAccent,
                          hasExplicitTint: tintColor != null,
                        )
                      : _Ios27SpecularFallbackPainter(
                          borderRadius: borderRadius,
                          isDark: isDark,
                          transparency: glassOpacity,
                          accent: effectiveAccent,
                          pressIntensity: pressIntensity,
                        ),
                ),
              ),
            ),
          if (accent != null && secondaryChromatic != null) ...[
            Positioned(
              left: -20,
              top: -18,
              bottom: -18,
              width: 118,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, 0.05),
                      radius: 0.95,
                      colors: [
                        accent.withAlpha(isDark ? 64 : 58),
                        accent.withAlpha(isDark ? 18 : 16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -18,
              bottom: -18,
              width: 114,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.2, -0.05),
                      radius: 0.95,
                      colors: [
                        secondaryChromatic.withAlpha(isDark ? 54 : 46),
                        secondaryChromatic.withAlpha(isDark ? 14 : 12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          innerContent,
          if (showBorder)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _Ios27ContrastRimPainter(
                    borderRadius: borderRadius,
                    isDark: isDark,
                    transparency: glassOpacity,
                    accent: accent,
                    pressIntensity: pressIntensity,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null
            ? (isGlass && LiquidGlassShaderEngine.program != null && tintColor == null
                ? baseTint.withAlpha((baseTint.a * 255 * 0.35).round())
                : baseTint)
            : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: (!isGlass && showBorder)
            ? Border.all(color: AppColors.borderOf(context), width: 1.0)
            : null,
      ),
      child: innerContent,
    );

    // Liquid Glass Content Diffusion: blur scales smoothly with transparency slider
    // and clamps edges to eliminate black/transparent bleed on Impeller.
    if (isGlass && useBackdropBlur && blurSigma > 0) {
      final diffusionSigma = (blurSigma * (0.62 + 0.65 * glassOpacity)).clamp(12.0, 44.0);
      surface = RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: diffusionSigma,
            sigmaY: diffusionSigma,
            tileMode: TileMode.clamp,
          ),
          child: surface,
        ),
      );
    }

    final bool useSquircleClip = borderRadius.topLeft.x < 100 &&
        borderRadius.topLeft == borderRadius.topRight &&
        borderRadius.topLeft == borderRadius.bottomLeft;
    final ShapeBorder squircleShape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius.topLeft.x * 2.1),
    );

    return Container(
      margin: margin,
      decoration: useSquircleClip
          ? ShapeDecoration(
              shape: squircleShape,
              shadows: boxShadow,
            )
          : BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: boxShadow,
            ),
      child: useSquircleClip
          ? ClipPath.shape(
              shape: squircleShape,
              child: surface,
            )
          : ClipRRect(
              borderRadius: borderRadius,
              child: surface,
            ),
    );
  }
}

class _Ios27ShaderGlassPainter extends CustomPainter {
  final FragmentProgram program;
  final BorderRadius borderRadius;
  final double transparency;
  final bool isDark;
  final double pressIntensity;
  final Color tintColor;
  final bool hasExplicitTint;

  const _Ios27ShaderGlassPainter({
    required this.program,
    required this.borderRadius,
    required this.transparency,
    required this.isDark,
    required this.pressIntensity,
    required this.tintColor,
    required this.hasExplicitTint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, borderRadius.topLeft.x.clamp(1.0, size.shortestSide * 0.5))
      ..setFloat(3, transparency.clamp(0.0, 1.0))
      ..setFloat(4, isDark ? 1.0 : 0.0)
      ..setFloat(5, pressIntensity.clamp(0.0, 1.0))
      ..setFloat(6, tintColor.r)
      ..setFloat(7, tintColor.g)
      ..setFloat(8, tintColor.b)
      ..setFloat(9, hasExplicitTint ? 0.58 : 0.24);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _Ios27ShaderGlassPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.transparency != transparency ||
      oldDelegate.isDark != isDark ||
      oldDelegate.pressIntensity != pressIntensity ||
      oldDelegate.tintColor != tintColor ||
      oldDelegate.hasExplicitTint != hasExplicitTint;
}

class _Ios27SpecularFallbackPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool isDark;
  final double transparency;
  final Color accent;
  final double pressIntensity;

  const _Ios27SpecularFallbackPainter({
    required this.borderRadius,
    required this.isDark,
    required this.transparency,
    required this.accent,
    required this.pressIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withAlpha((28 + pressIntensity * 14).round()),
                accent.withAlpha(14),
                Colors.black.withAlpha((24 + transparency * 20).round()),
              ]
            : [
                Colors.white.withAlpha((155 - transparency * 45 + pressIntensity * 25).round()),
                Colors.white.withAlpha(42),
                const Color(0xFFEAF0F7).withAlpha((55 + transparency * 45).round()),
              ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _Ios27SpecularFallbackPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.isDark != isDark ||
      oldDelegate.transparency != transparency ||
      oldDelegate.accent != accent ||
      oldDelegate.pressIntensity != pressIntensity;
}

/// Renders Apple Liquid Glass dual-edge perimeter:
/// 1. Subtle darkened outer contrast ring for crisp separation over white/busy backgrounds
/// 2. Brighter directional Fresnel specular rim inside the bevel
class _Ios27ContrastRimPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool isDark;
  final double transparency;
  final Color? accent;
  final double pressIntensity;

  const _Ios27ContrastRimPainter({
    required this.borderRadius,
    required this.isDark,
    required this.transparency,
    this.accent,
    this.pressIntensity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Darkened outer edge for crisp layer separation
    final outerDarkRRect = borderRadius.toRRect(rect).deflate(0.35);
    final darkenedEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..color = isDark
          ? Colors.black.withAlpha((118 + transparency * 40).round())
          : const Color(0xFF1D2430).withAlpha((34 + transparency * 24).round());
    canvas.drawRRect(outerDarkRRect, darkenedEdge);

    // 2. Brighter inner Liquid Glass Fresnel specular arc
    final innerSpecRRect = borderRadius.toRRect(rect).deflate(1.1);
    final edgeHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withAlpha((116 + pressIntensity * 40).round()),
                (accent ?? Colors.white).withAlpha(42),
                Colors.white.withAlpha(24),
                Colors.white.withAlpha((72 + pressIntensity * 24).round()),
              ]
            : [
                Colors.white.withAlpha(252),
                (accent ?? const Color(0xFFBBD7F4)).withAlpha(110),
                Colors.white.withAlpha(150),
                Colors.white.withAlpha(240),
              ],
        stops: const [0.0, 0.34, 0.68, 1.0],
      ).createShader(rect);

    canvas.drawRRect(innerSpecRRect, edgeHighlight);
  }

  @override
  bool shouldRepaint(covariant _Ios27ContrastRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.isDark != isDark ||
      oldDelegate.transparency != transparency ||
      oldDelegate.accent != accent ||
      oldDelegate.pressIntensity != pressIntensity;
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
    this.blurSigma = 30,
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

/// iOS 27 Liquid Glass sticky header with dynamic content diffusion and
/// darkened edge hairline that smoothly activates on scroll.
class StickyLiquidGlassHeader extends ConsumerWidget {
  final ValueNotifier<double> scrollOffset;
  final double height;
  final Widget child;

  const StickyLiquidGlassHeader({
    super.key,
    required this.scrollOffset,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDark(context);
    final isGlass = ref.watch(
      settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
    );
    final glassOpacity = ref.watch(
      settingsProvider.select((s) => s.liquidGlassOpacity),
    );
    final bg = AppColors.bgOf(context);

    return ValueListenableBuilder<double>(
      valueListenable: scrollOffset,
      builder: (context, offset, headerChild) {
        final t = ((offset - 4) / 28).clamp(0.0, 1.0);
        final maxHeaderAlpha = lerpDouble(90, 224, glassOpacity)!.round();
        final headerTint = isGlass
            ? (isDark
                ? const Color(0xFF0E1218).withAlpha((t * maxHeaderAlpha).round())
                : const Color(0xFFF6F7F9).withAlpha((t * maxHeaderAlpha).round()))
            : bg.withAlpha((t * 245).round());

        Widget inner = Container(
          height: height,
          decoration: BoxDecoration(
            color: headerTint,
            border: t > 0.12
                ? Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha((t * 38).round())
                          : const Color(0xFF1D2430).withAlpha((t * 36).round()),
                      width: 0.7,
                    ),
                  )
                : null,
          ),
          child: headerChild,
        );

        if (isGlass && t > 0.04) {
          final sigma = (18 + 14 * glassOpacity) * t;
          inner = RepaintBoundary(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.clamp,
                ),
                child: inner,
              ),
            ),
          );
        }

        return inner;
      },
      child: child,
    );
  }
}

/// Spring-like iOS 27 tactile scale & specular gleam feedback wrapper
/// using real damped SpringSimulation physics matching Apple's interactive glass.
class LiquidGlassTap extends ConsumerStatefulWidget {
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
    this.pressedScale = 0.955,
    this.haptic = true,
  });

  @override
  ConsumerState<LiquidGlassTap> createState() => _LiquidGlassTapState();
}

class _LiquidGlassTapState extends ConsumerState<LiquidGlassTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springCtrl;
  bool _pressed = false;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 420.0,
    damping: 26.0,
  );

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController(
      vsync: this,
      value: 1.0,
      lowerBound: 0.85,
      upperBound: 1.10,
    );
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final sim = SpringSimulation(_spring, _springCtrl.value, target, 0.0);
    _springCtrl.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    final hapticsOn = ref.watch(
      settingsProvider.select((s) => s.hapticsEnabled),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
        _animateTo(widget.pressedScale);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _animateTo(1.0);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _animateTo(1.0);
      },
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic && hapticsOn) {
                HapticFeedback.selectionClick();
              }
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic && hapticsOn) {
                HapticFeedback.mediumImpact();
              }
              widget.onLongPress!();
            },
      child: AnimatedBuilder(
        animation: _springCtrl,
        builder: (context, child) {
          return _LiquidGlassPressScope(
            pressIntensity: _pressed ? 1.0 : 0.0,
            child: Transform.scale(
              scale: _springCtrl.value,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Authentic iOS Settings / Apple Music rounded squircle icon badge
class IosSquircleBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const IosSquircleBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
    this.iconSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.56),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.16) ?? color,
            color,
          ],
        ),
        shadows: [
          BoxShadow(
            color: color.withAlpha(65),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: iconSize),
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
    final secondary = accent != null
        ? HSLColor.fromColor(accent)
            .withHue((HSLColor.fromColor(accent).hue + 140) % 360)
            .withSaturation(0.55)
            .toColor()
        : null;

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
                    center: const Alignment(-0.2, -0.5),
                    radius: 1.05,
                    colors: [
                      accent.withAlpha(isDark ? 72 : 28),
                      accent.withAlpha(isDark ? 20 : 9),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (secondary != null)
          Positioned(
            bottom: -140,
            right: -90,
            width: 320,
            height: 320,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 620),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.25, 0.25),
                    radius: 0.95,
                    colors: [
                      secondary.withAlpha(isDark ? 44 : 18),
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

/// Fast 60fps iOS 27 Liquid Glass card for list items and grouped sections.
/// Renders GPU GLSL optical bevel, darkened contrast rim & transparency control
/// without stacking per-item BackdropFilter blurs inside scrolling lists.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? tintColor;
  final Color? chromaticAccent;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showBorder;
  final List<BoxShadow>? shadows;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.radius = 22,
    this.tintColor,
    this.chromaticAccent,
    this.padding,
    this.margin,
    this.showBorder = true,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(radius),
      blurSigma: 0,
      useBackdropBlur: false,
      tintColor: tintColor,
      chromaticAccent: chromaticAccent,
      padding: padding,
      margin: margin,
      showBorder: showBorder,
      shadows: shadows ??
          [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 56 : 12),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
      child: child,
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

    return LiquidGlassTap(
      onTap: onTap,
      child: LiquidGlassCard(
        radius: 22,
        chromaticAccent: const Color(0xFFFF982E),
        child: SizedBox(
          height: 82,
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
                        const Color(0xFFFF9F43).withAlpha(isDark ? 48 : 42),
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
                              Flexible(
                                child: Text(
                                  'hari berturut-turut',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: sub,
                                  ),
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
                    Icon(Icons.chevron_right_rounded, color: sub, size: 20),
                  ],
                ),
              ),
            ],
          ),
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
  final handleColor = isDark ? Colors.white.withAlpha(74) : const Color(0xFF9EA6B2);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(isDark ? 150 : 90),
    builder: (ctx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final isGlass = ref.watch(
            settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
          );
          final glassOpacity = ref.watch(
            settingsProvider.select((s) => s.liquidGlassOpacity),
          );
          final sheetAlpha = lerpDouble(195, 245, glassOpacity)!.round();
          final sheetBg = isGlass
              ? (isDark
                  ? const Color(0xFF141820).withAlpha(sheetAlpha)
                  : const Color(0xFFFDFEFF).withAlpha(sheetAlpha))
              : surface;

          Widget sheetBody = Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * maxHeightFactor,
            ),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(
                top: BorderSide(
                  color: isGlass
                      ? (isDark
                          ? Colors.white.withAlpha(65)
                          : Colors.white.withAlpha(240))
                      : AppColors.borderOf(ctx),
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 120 : 34),
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
                    width: 40,
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

          if (isGlass) {
            final sigma = (20 + 18 * glassOpacity).clamp(16.0, 38.0);
            sheetBody = RepaintBoundary(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                    tileMode: TileMode.clamp,
                  ),
                  child: sheetBody,
                ),
              ),
            );
          }

          return sheetBody;
        },
      );
    },
  );
}
