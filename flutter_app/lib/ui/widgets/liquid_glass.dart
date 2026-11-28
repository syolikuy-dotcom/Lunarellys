import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart' as lge;
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/settings_provider.dart';
import 'artwork_image.dart';

export 'package:liquid_glass_easy/liquid_glass_easy.dart' hide showLiquidGlassSheet;

/// Primary Archys Liquid Glass surface powered by `liquid_glass_easy`.
/// Uses `LiquidGlassLens` (true refractive shader lens on Impeller & inside
/// `LiquidGlassView`, graceful frosted glass on Skia/Web) when backdrop blur is
/// enabled, or `LiquidGlassLite` for scrolling/grouped cards, and adapts cleanly
/// when the user chooses `AppAppearanceStyle.flat`.
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
  final double refractionIndex;
  final double refractionWidth;
  final double magnification;
  final double dispersion;
  final bool interactiveFlex;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.blurSigma = 24,
    this.tintColor,
    this.chromaticAccent,
    this.padding,
    this.margin,
    this.showBorder = true,
    this.useBackdropBlur = true,
    this.gradient,
    this.shadows,
    this.refractionIndex = 1.12,
    this.refractionWidth = 14.0,
    this.magnification = 1.0,
    this.dispersion = 0.0,
    this.interactiveFlex = false,
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

    final clearAlpha = isDark ? 42 : 76;
    final tintedAlpha = isDark ? 196 : 226;
    final dynamicAlpha = lerpDouble(clearAlpha, tintedAlpha, glassOpacity)!.round();

    final baseTint = tintColor != null
        ? (isGlass
            ? tintColor!.withAlpha(
                lerpDouble(
                  (tintColor!.a * 255).round().clamp(44, 158),
                  214,
                  glassOpacity * 0.65,
                )!
                    .round(),
              )
            : tintColor!)
        : (isDark
            ? (isGlass
                ? const Color(0xFF14171D).withAlpha(dynamicAlpha)
                : AppColors.darkSurface)
            : (isGlass
                ? const Color(0xFFFFFFFF).withAlpha(dynamicAlpha)
                : AppColors.lightSurface));

    final radiusValue = borderRadius.topLeft.x.clamp(4.0, 200.0);
    final shape = radiusValue >= 90
        ? const lge.LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 100)
        : lge.LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: radiusValue,
          );

    Widget content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    final accent = chromaticAccent;
    final secondaryChromatic = accent != null
        ? HSLColor.fromColor(accent)
            .withHue((HSLColor.fromColor(accent).hue + 145) % 360)
            .withSaturation(0.58)
            .toColor()
        : null;

    if (isGlass && (accent != null || gradient != null)) {
      content = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (gradient != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: gradient),
                  ),
                ),
              ),
            if (accent != null && secondaryChromatic != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withAlpha(isDark ? 20 : 14),
                          accent.withAlpha(isDark ? 6 : 4),
                          secondaryChromatic.withAlpha(isDark ? 12 : 8),
                        ],
                        stops: const [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            content,
          ],
        ),
      );
    }

    if (!isGlass) {
      final flatDecoration = BoxDecoration(
        color: gradient == null ? baseTint : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(color: AppColors.borderOf(context), width: 0.75)
            : null,
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 64 : 10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
      );
      return Container(
        margin: margin,
        decoration: flatDecoration,
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    final effectiveBlur = useBackdropBlur
        ? (blurSigma * (0.10 + 0.12 * glassOpacity)).clamp(1.2, 4.2)
        : 0.0;

    final specular = showBorder
        ? lge.LiquidGlassLight.specular(
            thickness: 1.5,
            sharpness: 0.72,
            angle: 42.0,
            spread: 0.88,
            intensity: isDark ? 0.44 : 0.85,
            oppositeIntensity: isDark ? 0.22 : 0.55,
            color: Colors.white,
          )
        : const lge.LiquidGlassLight.specular(thickness: 0, intensity: 0, oppositeIntensity: 0);

    final glow = (useBackdropBlur && accent != null)
        ? lge.LiquidGlassLight.glow(
            thickness: 6,
            spread: 0.45,
            intensity: isDark ? 0.22 : 0.16,
            oppositeIntensity: 0.10,
            color: accent,
          )
        : null;

    final lgeShadow = lge.LiquidGlassShadow(
      blur: isDark ? 12 : 10,
      opacity: isDark ? 0.20 : 0.08,
      color: Colors.black,
    );

    Widget result;
    if (useBackdropBlur) {
      result = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: lge.LiquidGlassLens(
          style: lge.LiquidGlassStyle(
            shape: shape,
            specular: specular,
            glow: glow,
            refractionIndex: refractionIndex.clamp(1.03, 1.07),
            refractionWidth: refractionWidth.clamp(5.0, 8.0),
            magnification: magnification,
            dispersion: dispersion,
            saturation: isDark ? 1.12 : 1.18,
            blur: effectiveBlur,
            color: baseTint,
            shadow: lgeShadow,
          ),
          touch: interactiveFlex
              ? const lge.LiquidGlassTouch.flexing(lge.LiquidGlassFlex.subtle())
              : null,
          child: Material(
            type: MaterialType.transparency,
            child: content,
          ),
        ),
      );
    } else {
      result = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadows ??
              [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 56 : 12),
                  blurRadius: 14,
                  spreadRadius: -2,
                  offset: const Offset(0, 5),
                ),
              ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: lge.LiquidGlassLite(
            shape: shape,
            specular: specular,
            glow: glow,
            borderAlpha: showBorder ? 1.0 : 0.0,
            blur: effectiveBlur,
            magnification: 1.0,
            color: baseTint,
            child: Material(
              type: MaterialType.transparency,
              child: content,
            ),
          ),
        ),
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: result);
    }
    return result;
  }
}

class LiquidGlassCapsule extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final Color? tintColor;
  final Color? chromaticAccent;
  final double radius;
  final bool interactiveFlex;

  const LiquidGlassCapsule({
    super.key,
    required this.child,
    this.padding,
    this.blurSigma = 24,
    this.tintColor,
    this.chromaticAccent,
    this.radius = 999,
    this.interactiveFlex = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(radius),
      blurSigma: blurSigma,
      tintColor: tintColor,
      chromaticAccent: chromaticAccent,
      padding: padding,
      interactiveFlex: interactiveFlex,
      child: child,
    );
  }
}

/// Sticky header using `LiquidGlassLite` / `LiquidGlassLens` that smoothly
/// materializes as scroll offset increases without Impeller black-edge glitches.
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
        final maxHeaderAlpha = lerpDouble(92, 168, glassOpacity)!.round();
        final headerTint = isGlass
            ? (isDark
                ? const Color(0xFF0E131B).withAlpha((t * maxHeaderAlpha).round())
                : const Color(0xFFF6F8FB).withAlpha((t * maxHeaderAlpha).round()))
            : bg.withAlpha((t * 245).round());

        Widget inner = Container(
          height: height,
          decoration: BoxDecoration(
            color: headerTint,
            border: t > 0.12
                ? Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha((t * 36).round())
                          : const Color(0xFF1D2430).withAlpha((t * 28).round()),
                      width: 0.7,
                    ),
                  )
                : null,
          ),
          child: headerChild,
        );

        if (isGlass && t > 0.08) {
          final sigma = (4.0 + 3.5 * glassOpacity) * t;
          inner = ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.clamp,
              ),
              child: inner,
            ),
          );
        }

        return inner;
      },
      child: child,
    );
  }
}

/// Tactile spring-physics feedback wrapper using damped SpringSimulation.
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
      onTapDown: (_) => _animateTo(widget.pressedScale),
      onTapUp: (_) => _animateTo(1.0),
      onTapCancel: () => _animateTo(1.0),
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
      child: ScaleTransition(
        scale: _springCtrl,
        child: widget.child,
      ),
    );
  }
}

/// Interactive Liquid Glass Switch powered by `liquid_glass_easy`'s
/// `LiquidGlassSwitch` in Glass mode and crisp Cupertino switch in Flat mode.
class LiquidGlassToggleSwitch extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool reserveSwellRoom;

  const LiquidGlassToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.reserveSwellRoom = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDark(context);
    final isGlass = ref.watch(
      settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
    );
    final accent = activeColor ?? const Color(0xFF34C759);

    if (!isGlass || onChanged == null) {
      return Opacity(
        opacity: onChanged == null ? 0.5 : 1.0,
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: accent,
        ),
      );
    }

    return lge.LiquidGlassSwitch(
      value: value,
      onChanged: (next) {
        if (ref.read(settingsProvider).hapticsEnabled) {
          HapticFeedback.selectionClick();
        }
        onChanged?.call(next);
      },
      activeColor: accent,
      inactiveColor: inactiveColor ??
          (isDark
              ? Colors.white.withAlpha(42)
              : const Color(0x4C787880)),
      thumbColor: Colors.white,
      reserveSwellRoom: reserveSwellRoom,
    );
  }
}

/// Drop-in Liquid Glass Switch tile replacing Material SwitchListTile.
class LiquidGlassSwitchTile extends StatelessWidget {
  final Widget? secondary;
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry contentPadding;
  final Color? activeColor;

  const LiquidGlassSwitchTile({
    super.key,
    this.secondary,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: contentPadding,
        child: Row(
          children: [
            if (secondary != null) ...[
              secondary!,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkOf(context),
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.subOf(context),
                        height: 1.3,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            LiquidGlassToggleSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: activeColor,
              reserveSwellRoom: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Liquid Glass Slider powered by `liquid_glass_easy`'s
/// `LiquidGlassSlider` with stretchy jelly glass thumb, safely wrapped in
/// `LayoutBuilder` so width always adapts cleanly to parent constraints.
class LiquidGlassRangeSlider extends ConsumerWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final Color? activeColor;
  final Color? inactiveColor;
  final Widget? minimumIcon;
  final Widget? maximumIcon;
  final bool compact;

  const LiquidGlassRangeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.activeColor,
    this.inactiveColor,
    this.minimumIcon,
    this.maximumIcon,
    this.compact = false,
  });

  static const _compactLayout = lge.LiquidGlassSliderLayout(
    trackHeight: 4.5,
    thumbWidth: 24,
    thumbHeight: 16,
    liftedThumbWidth: 38,
    liftedThumbHeight: 25,
    iconSize: 16,
    iconGap: 6,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDark(context);
    final isGlass = ref.watch(
      settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
    );
    final accent = activeColor ?? AppColors.horizonBlue;
    final clampedVal = value.clamp(min, max).toDouble();

    if (!isGlass) {
      return Slider(
        value: clampedVal,
        min: min,
        max: max,
        activeColor: accent,
        onChanged: onChanged,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 280.0;
        final safeW = math.max(80.0, avail);
        return lge.LiquidGlassSlider(
          value: clampedVal,
          minimumValue: min,
          maximumValue: max,
          onChanged: onChanged,
          onChangeStart: onChangeStart,
          onChangeEnd: onChangeEnd,
          width: safeW,
          layout: compact ? _compactLayout : const lge.LiquidGlassSliderLayout(),
          activeColor: accent,
          inactiveColor: inactiveColor ??
              (isDark
                  ? Colors.white.withAlpha(38)
                  : Colors.black.withAlpha(22)),
          thumbColor: Colors.white,
          minimumIcon: minimumIcon,
          maximumIcon: maximumIcon,
        );
      },
    );
  }
}

/// Realistic spinning vinyl record ("Piringan Musik Muter") with smooth
/// angular acceleration & deceleration synced to `isPlaying`, concentric
/// groove reflections, and pivoting turntable tonearm.
class SpinningVinylDisc extends StatefulWidget {
  final String? artworkUrl;
  final double size;
  final bool isPlaying;
  final Color accentColor;
  final bool showTonearm;
  final VoidCallback? onTap;

  const SpinningVinylDisc({
    super.key,
    required this.artworkUrl,
    required this.size,
    required this.isPlaying,
    required this.accentColor,
    this.showTonearm = true,
    this.onTap,
  });

  @override
  State<SpinningVinylDisc> createState() => _SpinningVinylDiscState();
}

class _SpinningVinylDiscState extends State<SpinningVinylDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  bool _tickerActive = true;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    );
  }

  void _syncSpin() {
    final shouldSpin = widget.isPlaying && _tickerActive;
    if (shouldSpin && !_spinCtrl.isAnimating) {
      _spinCtrl.repeat();
    } else if (!shouldSpin && _spinCtrl.isAnimating) {
      _spinCtrl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerActive = TickerMode.valuesOf(context).enabled;
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant SpinningVinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final isDark = AppColors.isDark(context);

    final platter = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF20242C),
            Color(0xFF0E1015),
            Color(0xFF171B22),
            Color(0xFF090B0E),
          ],
          stops: [0.0, 0.45, 0.78, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withAlpha(36),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(140),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _VinylGroovesPainter(accent: widget.accentColor),
            ),
          ),
          Container(
            width: s * 0.48,
            height: s * 0.48,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withAlpha(190),
              border: Border.all(
                color: Colors.white.withAlpha(120),
                width: 1.2,
              ),
            ),
            child: ArtworkImage(
              url: widget.artworkUrl,
              size: s * 0.48,
              isCircle: true,
            ),
          ),
          Container(
            width: s * 0.11,
            height: s * 0.11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF151820),
              border: Border.all(
                color: Colors.white.withAlpha(175),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 520),
              width: s * (widget.isPlaying ? 0.98 : 0.88),
              height: s * (widget.isPlaying ? 0.98 : 0.88),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withAlpha(
                      widget.isPlaying ? (isDark ? 98 : 72) : 28,
                    ),
                    blurRadius: widget.isPlaying ? 40 : 20,
                    spreadRadius: widget.isPlaying ? 4 : -4,
                  ),
                ],
              ),
            ),
            RepaintBoundary(
              child: RotationTransition(
                turns: _spinCtrl,
                child: platter,
              ),
            ),
            if (widget.showTonearm)
              Positioned(
                top: -s * 0.04,
                right: s * 0.02,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: widget.isPlaying ? 1.0 : 0.0,
                    ),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (context, engage, _) {
                      final armAngle = lerpDouble(-0.44, 0.06, engage)!;
                      return Transform.rotate(
                        alignment: const Alignment(0.0, -0.78),
                        angle: armAngle,
                        child: CustomPaint(
                          size: Size(s * 0.24, s * 0.46),
                          painter: _TonearmPainter(accent: widget.accentColor),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact rotating vinyl disc badge for MiniPlayer & active TrackTiles.
class MiniSpinningVinyl extends StatefulWidget {
  final String? artworkUrl;
  final double size;
  final bool isPlaying;
  final Color accentColor;

  const MiniSpinningVinyl({
    super.key,
    required this.artworkUrl,
    required this.size,
    required this.isPlaying,
    this.accentColor = AppColors.horizonBlue,
  });

  @override
  State<MiniSpinningVinyl> createState() => _MiniSpinningVinylState();
}

class _MiniSpinningVinylState extends State<MiniSpinningVinyl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  bool _tickerActive = true;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    );
  }

  void _syncSpin() {
    final shouldSpin = widget.isPlaying && _tickerActive;
    if (shouldSpin && !_spinCtrl.isAnimating) {
      _spinCtrl.repeat();
    } else if (!shouldSpin && _spinCtrl.isAnimating) {
      _spinCtrl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerActive = TickerMode.valuesOf(context).enabled;
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant MiniSpinningVinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return RepaintBoundary(
      child: RotationTransition(
        turns: _spinCtrl,
        child: Container(
          width: s,
          height: s,
          padding: EdgeInsets.all((s * 0.12).clamp(3.0, 6.0)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFF141820),
                Color(0xFF2D3340),
                Color(0xFF10131A),
                Color(0xFF272D38),
                Color(0xFF141820),
              ],
            ),
            border: Border.all(
              color: widget.isPlaying
                  ? widget.accentColor.withAlpha(165)
                  : Colors.white.withAlpha(48),
              width: 1.2,
            ),
            boxShadow: [
              if (widget.isPlaying)
                BoxShadow(
                  color: widget.accentColor.withAlpha(88),
                  blurRadius: 10,
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ArtworkImage(
                url: widget.artworkUrl,
                size: s * 0.76,
                isCircle: true,
              ),
              Container(
                width: (s * 0.18).clamp(6.0, 10.0),
                height: (s * 0.18).clamp(6.0, 10.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF11141B),
                  border: Border.all(color: Colors.white.withAlpha(190), width: 1.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  final Color accent;
  const _VinylGroovesPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.48;
    final minR = size.shortestSide * 0.255;

    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    const ringCount = 14;
    for (var i = 0; i < ringCount; i++) {
      final t = i / (ringCount - 1);
      final r = lerpDouble(minR, maxR, t)!;
      groovePaint.color = i.isEven
          ? Colors.white.withAlpha(16)
          : Colors.black.withAlpha(68);
      canvas.drawCircle(center, r, groovePaint);
    }

    // Specular light sheen wedge across the vinyl surface
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withAlpha(32),
          accent.withAlpha(24),
          Colors.transparent,
          Colors.white.withAlpha(26),
          Colors.transparent,
        ],
        stops: const [0.0, 0.14, 0.22, 0.48, 0.68, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawCircle(center, maxR, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _TonearmPainter extends CustomPainter {
  final Color accent;
  const _TonearmPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pivot = Offset(w * 0.62, h * 0.12);

    // Pivot base
    canvas.drawCircle(
      pivot,
      w * 0.22,
      Paint()
        ..color = const Color(0xFF282E3A)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      pivot,
      w * 0.22,
      Paint()
        ..color = Colors.white.withAlpha(140)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Metallic arm shaft
    final elbow = Offset(w * 0.56, h * 0.62);
    final tip = Offset(w * 0.30, h * 0.88);
    final armPath = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(tip.dx, tip.dy);

    canvas.drawPath(
      armPath,
      Paint()
        ..color = Colors.black.withAlpha(105)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      armPath,
      Paint()
        ..color = const Color(0xFFD5DCE6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Cartridge head at tip
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(0.55);
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 10, height: 18),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(headRect, Paint()..color = const Color(0xFF1B1F27));
    canvas.drawRRect(
      headRect,
      Paint()
        ..color = accent.withAlpha(220)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TonearmPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Smooth reactive harmonic audio wave bars for Now Playing / Ambient Mode.
class HarmonicSpectrumBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final int barCount;
  final double height;

  const HarmonicSpectrumBars({
    super.key,
    required this.isPlaying,
    required this.color,
    this.barCount = 24,
    this.height = 34,
  });

  @override
  State<HarmonicSpectrumBars> createState() => _HarmonicSpectrumBarsState();
}

class _HarmonicSpectrumBarsState extends State<HarmonicSpectrumBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _tickerActive = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  void _syncTicker() {
    final shouldRun = widget.isPlaying && _tickerActive;
    if (shouldRun && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!shouldRun && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerActive = TickerMode.valuesOf(context).enabled;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant HarmonicSpectrumBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final phase = _ctrl.value * math.pi * 2;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final norm = (i / math.max(1, widget.barCount - 1));
              final bell = math.sin(norm * math.pi);
              final wave = widget.isPlaying
                  ? (0.32 +
                      0.68 *
                          (0.5 +
                              0.5 *
                                  math.sin(phase * (1.0 + (i % 3) * 0.5) +
                                      i * 0.72)))
                  : 0.16;
              final h = (widget.height * (0.14 + 0.86 * bell * wave))
                  .clamp(4.0, widget.height);
              return Container(
                width: 3.2,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(
                    widget.isPlaying ? (130 + (bell * 120).round()) : 90,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          );
        },
      ),
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
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 520),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.78),
                    radius: 1.15,
                    colors: [
                      accent.withAlpha(isDark ? 64 : 24),
                      accent.withAlpha(isDark ? 18 : 7),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
        if (secondary != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 620),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.75, 0.85),
                    radius: 1.10,
                    colors: [
                      secondary.withAlpha(isDark ? 36 : 14),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
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

/// Fast 60fps Liquid Glass card powered by `liquid_glass_easy`'s `LiquidGlassLite`
/// for scrolling lists and grouped sections without stacking BackdropFilters.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? tintColor;
  final Color? chromaticAccent;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showBorder;
  final Gradient? gradient;
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
    this.gradient,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(radius),
      blurSigma: 0,
      useBackdropBlur: false,
      tintColor: tintColor,
      chromaticAccent: chromaticAccent,
      padding: padding,
      margin: margin,
      showBorder: showBorder,
      gradient: gradient,
      shadows: shadows,
      child: child,
    );
  }
}

/// Warm layered Percikan streak flame icon
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
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final isDark = AppColors.isDark(context);

    return LiquidGlassTap(
      onTap: onTap,
      child: LiquidGlassCard(
        radius: 22,
        chromaticAccent: const Color(0xFFFF8C24),
        gradient: RadialGradient(
          center: const Alignment(-0.78, 0.0),
          radius: 0.85,
          colors: [
            const Color(0xFFFF8C24).withAlpha(isDark ? 42 : 28),
            Colors.transparent,
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const PercikanFlameIcon(size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
    );
  }
}

/// Unified modal bottom sheet powered by `liquid_glass_easy`'s
/// `LiquidGlassSheet` when in Glass mode, or crisp native sheet in Flat mode.
Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double maxHeightFactor = 0.90,
}) {
  final isDark = AppColors.isDark(context);
  final ink = AppColors.inkOf(context);
  final surface = AppColors.cardOf(context);
  final handleColor = isDark ? Colors.white.withAlpha(88) : const Color(0xFF9EA6B2);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(isDark ? 155 : 92),
    builder: (ctx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final isGlass = ref.watch(
            settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
          );
          final glassOpacity = ref.watch(
            settingsProvider.select((s) => s.liquidGlassOpacity),
          );

          final maxH = MediaQuery.of(ctx).size.height * maxHeightFactor;
          final sheetAlpha = lerpDouble(116, 186, glassOpacity)!.round();
          final sheetBg = isGlass
              ? (isDark
                  ? const Color(0xFF141822).withAlpha(sheetAlpha)
                  : const Color(0xFFFCFDFF).withAlpha(sheetAlpha))
              : surface;

          if (isGlass) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: lge.LiquidGlassSheet(
                  anchor: lge.LiquidGlassSheetAnchor.attached,
                  grabber: true,
                  grabberColor: handleColor,
                  safeArea: true,
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                  foregroundColor: ink,
                  style: lge.LiquidGlassStyle(
                    shape: const lge.LiquidGlassShape.continuousRoundedRectangle(
                      cornerRadius: 32,
                    ),
                    specular: lge.LiquidGlassLight.specular(
                      thickness: 3.0,
                      intensity: isDark ? 0.56 : 0.88,
                      oppositeIntensity: 0.28,
                    ),
                    color: sheetBg,
                    blur: (2.6 + 3.2 * glassOpacity).clamp(2.4, 5.8),
                    refractionIndex: 1.05,
                    refractionWidth: 7,
                    saturation: isDark ? 1.12 : 1.18,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: builder(ctx),
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxH),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(
                  top: BorderSide(color: AppColors.borderOf(ctx), width: 1.0),
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
            ),
          );
        },
      );
    },
  );
}

/// Theme-adaptive Liquid Glass alert dialog powered by `liquid_glass_easy`'s
/// `showLiquidGlassDialog` + `LiquidGlassAlertDialog` in Glass mode, or standard
/// Material `AlertDialog` in Flat mode.
Future<T?> showArchysGlassDialog<T>({
  required BuildContext context,
  Widget? icon,
  Widget? title,
  Widget? content,
  List<Widget>? actions,
  List<Widget> Function(BuildContext dialogContext)? actionsBuilder,
}) {
  return _openArchysDialog<T>(
    context: context,
    isDark: AppColors.isDark(context),
    ink: AppColors.inkOf(context),
    sub: AppColors.subOf(context),
    icon: icon,
    title: title,
    content: content,
    actions: actions,
    actionsBuilder: actionsBuilder,
  );
}

Future<T?> _openArchysDialog<T>({
  required BuildContext context,
  required bool isDark,
  required Color ink,
  required Color sub,
  Widget? icon,
  Widget? title,
  Widget? content,
  List<Widget>? actions,
  List<Widget> Function(BuildContext dialogContext)? actionsBuilder,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final settings = container.read(settingsProvider);
  final isGlass = settings.appearanceStyle == AppAppearanceStyle.glass;

  if (!isGlass) {
    return showDialog<T>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: icon,
        title: title,
        content: content,
        actions: actionsBuilder != null ? actionsBuilder(dialogCtx) : actions,
      ),
    );
  }

  final alpha = lerpDouble(112, 180, settings.liquidGlassOpacity)!.round();
  final tint = isDark
      ? const Color(0xFF161B26).withAlpha(alpha)
      : const Color(0xFFFDFEFF).withAlpha(alpha);

  return lge.showLiquidGlassDialog<T>(
    context: context,
    barrierColor: Colors.black.withAlpha(isDark ? 130 : 72),
    builder: (dialogCtx) => lge.LiquidGlassAlertDialog(
      icon: icon,
      title: title,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      content: content,
      contentTextStyle: TextStyle(
        fontSize: 14,
        color: sub,
        height: 1.4,
      ),
      actions: actionsBuilder != null ? actionsBuilder(dialogCtx) : actions,
      style: lge.LiquidGlassStyle(
        shape: const lge.LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: 30,
        ),
        specular: lge.LiquidGlassLight.specular(
          thickness: 3.0,
          intensity: isDark ? 0.56 : 0.88,
          oppositeIntensity: 0.28,
        ),
        color: tint,
        blur: (2.6 + 3.2 * settings.liquidGlassOpacity).clamp(2.4, 5.8),
        refractionIndex: 1.05,
        refractionWidth: 7,
        saturation: isDark ? 1.12 : 1.18,
      ),
    ),
  );
}

/// Authentic iOS inset-grouped uppercase section header.
class IosSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const IosSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 7),
  });

  @override
  Widget build(BuildContext context) {
    final sub = AppColors.subOf(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.45,
                color: sub,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Authentic iOS inset-grouped list card with hairline dividers between rows.
class IosGroupedListCard extends StatelessWidget {
  final List<Widget> children;
  final double radius;
  final Color? chromaticAccent;
  final EdgeInsetsGeometry? margin;
  final double dividerIndent;

  const IosGroupedListCard({
    super.key,
    required this.children,
    this.radius = 20,
    this.chromaticAccent,
    this.margin,
    this.dividerIndent = 58,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.borderOf(context);
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i < children.length - 1) {
        spaced.add(
          Divider(
            height: 0.6,
            thickness: 0.6,
            indent: dividerIndent,
            color: dividerColor,
          ),
        );
      }
    }
    return LiquidGlassCard(
      radius: radius,
      chromaticAccent: chromaticAccent,
      margin: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: spaced,
      ),
    );
  }
}


