import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Modern Archys acoustic emblem:
/// Curved sound-wave arc halo framing 4 symmetrical rounded equalizer bars.
class ArchysHorizonLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? accentColor;
  final double animationProgress;

  const ArchysHorizonLogo({
    super.key,
    this.size = 76,
    this.color,
    this.accentColor,
    this.animationProgress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final activeColor = color ??
        (isDark ? const Color(0xFFF4F8FC) : const Color(0xFF0F172A));
    final secondaryAccent = accentColor ??
        (isDark ? const Color(0xFF7EC8FF) : const Color(0xFF2563EB));

    return CustomPaint(
      size: Size.square(size),
      painter: _ArchysEmblemPainter(
        primaryColor: activeColor,
        accentColor: secondaryAccent,
        isDark: isDark,
        progress: animationProgress.clamp(0.0, 1.0),
      ),
    );
  }
}

/// Selectable 20-style rounded square launcher icon preview matching "Gaya ikon aplikasi".
class ArchysAppIconTile extends StatelessWidget {
  final dynamic style; // AppIconStyle
  final double size;
  final bool selected;

  const ArchysAppIconTile({
    super.key,
    required this.style,
    this.size = 64,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgTop = style.bgTop as Color;
    final Color bgBottom = style.bgBottom as Color;
    final Color primary = style.primary as Color;
    final Color accent = style.accent as Color;
    final bool hasInnerBox = style.hasInnerBox as bool;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      padding: EdgeInsets.all(selected ? 2.5 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.27),
        border: selected
            ? Border.all(
                color: AppColors.isDark(context)
                    ? Colors.white
                    : AppColors.iosBlue,
                width: 2.2,
              )
            : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withAlpha(90),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.23),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgTop, bgBottom],
          ),
          border: Border.all(
            color: Colors.white.withAlpha(36),
            width: 0.7,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft top gloss
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size * 0.44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(size * 0.22),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withAlpha(40),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (hasInnerBox)
              Container(
                width: size * 0.68,
                height: size * 0.68,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(34),
                  borderRadius: BorderRadius.circular(size * 0.16),
                  border: Border.all(
                    color: Colors.white.withAlpha(95),
                    width: 0.8,
                  ),
                ),
              ),
            ArchysHorizonLogo(
              size: size * 0.62,
              color: primary,
              accentColor: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedArchysLogo extends StatefulWidget {
  final double size;
  final Color? color;
  final bool loopPulse;

  const AnimatedArchysLogo({
    super.key,
    this.size = 86,
    this.color,
    this.loopPulse = true,
  });

  @override
  State<AnimatedArchysLogo> createState() => _AnimatedArchysLogoState();
}

class _AnimatedArchysLogoState extends State<AnimatedArchysLogo>
    with TickerProviderStateMixin {
  late final AnimationController _revealCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.loopPulse) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_revealCtrl, _pulseCtrl]),
        builder: (context, _) {
          final reveal = Curves.easeOutCubic.transform(_revealCtrl.value);
          final breathe = widget.loopPulse
              ? 1.0 + (math.sin(_pulseCtrl.value * math.pi) * 0.03)
              : 1.0;

          return Transform.scale(
            scale: (0.86 + 0.14 * reveal) * breathe,
            child: Opacity(
              opacity: reveal.clamp(0.0, 1.0),
              child: ArchysHorizonLogo(
                size: widget.size,
                color: widget.color,
                animationProgress: reveal,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArchysEmblemPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final bool isDark;
  final double progress;

  const _ArchysEmblemPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.isDark,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));

    // 1. Soft acoustic aura glow
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withAlpha(((isDark ? 60 : 38) * progress).round()),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.48));
    canvas.drawCircle(Offset(cx, cy), w * 0.48, auraPaint);

    // 2. Clean open harmonic arch / halo cradling the sound bars
    final archStroke = (w * 0.095).clamp(1.6, 12.0);
    final arcRadius = w * 0.345 * (0.72 + 0.28 * t);
    final arcRect = Rect.fromCircle(
      center: Offset(cx, cy + h * 0.02),
      radius: arcRadius,
    );
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = archStroke
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor,
          Color.lerp(primaryColor, accentColor, 0.35) ?? primaryColor,
        ],
      ).createShader(arcRect);
    // Draws a sleek 230-degree upper acoustic arch (open at the bottom cleanly)
    canvas.drawArc(
      arcRect,
      math.pi * 0.86,
      math.pi * 1.28 * t,
      false,
      arcPaint,
    );

    // Subtle specular highlight along top arc edge
    if (t > 0.35) {
      canvas.drawArc(
        arcRect.deflate(archStroke * 0.16),
        math.pi * 1.05,
        math.pi * 0.52 * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (archStroke * 0.28).clamp(0.8, 2.6)
          ..color = Colors.white.withAlpha((135 * progress).round()),
      );
    }

    // 3. Four crisp vertical equalizer bars centered inside the arch
    const barRatios = [0.28, 0.50, 0.41, 0.24];
    final barW = (w * 0.088).clamp(1.5, 10.5);
    final gap = w * 0.058;
    final totalBarsW = (barW * 4) + (gap * 3);
    final startX = cx - totalBarsW * 0.5;
    final baseCenterY = cy + h * 0.075;

    for (var i = 0; i < 4; i++) {
      final localT = ((progress - i * 0.06) / 0.82).clamp(0.0, 1.0);
      final eased = Curves.easeOutBack.transform(localT);
      final barH = (h * barRatios[i] * eased).clamp(barW, h * 0.56);
      final x = startX + i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barW * 0.5, baseCenterY - (i == 1 ? h * 0.02 : 0)),
          width: barW,
          height: barH,
        ),
        Radius.circular(barW * 0.5),
      );
      final isAccentBar = i == 1 || i == 2;
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isAccentBar
                ? [
                    Color.lerp(accentColor, Colors.white, 0.28) ?? accentColor,
                    accentColor,
                  ]
                : [primaryColor, primaryColor.withAlpha(220)],
          ).createShader(rect.outerRect),
      );
    }

    // 4. Tiny resonance orb dot beneath center gap for visual balance
    final dotR = (w * 0.042 * t).clamp(0.9, 5.0);
    canvas.drawCircle(
      Offset(cx, h * 0.81),
      dotR,
      Paint()..color = accentColor.withAlpha((235 * progress).round()),
    );
  }

  @override
  bool shouldRepaint(covariant _ArchysEmblemPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isDark != isDark ||
      oldDelegate.progress != progress;
}

class ArchysLogo extends StatelessWidget {
  final double size;
  final bool animate;

  const ArchysLogo({
    super.key,
    this.size = 48,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    if (animate) {
      return AnimatedArchysLogo(size: size);
    }
    return ArchysHorizonLogo(size: size);
  }
}

// Backward-compatible aliases so existing imports continue working cleanly
class LunarellysHorizonLogo extends ArchysHorizonLogo {
  const LunarellysHorizonLogo({
    super.key,
    super.size = 76,
    super.color,
    super.animationProgress = 1.0,
  });
}

class AnimatedLunarellysLogo extends AnimatedArchysLogo {
  const AnimatedLunarellysLogo({
    super.key,
    super.size = 86,
    super.color,
    super.loopPulse = true,
  });
}

class LunarellysLogo extends ArchysLogo {
  const LunarellysLogo({
    super.key,
    super.size = 48,
    super.animate = false,
  });
}

/// Custom slanted-book-shelf icon matching the Pustaka tab icon
class LibraryBooksIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;

  const LibraryBooksIcon({
    super.key,
    this.size = 22,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LibraryBooksPainter(color: color, filled: filled),
    );
  }
}

class _LibraryBooksPainter extends CustomPainter {
  final Color color;
  final bool filled;
  const _LibraryBooksPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * (filled ? 0.095 : 0.075)).clamp(1.6, 2.8)
      ..strokeCap = StrokeCap.round;

    final x1 = w * 0.20;
    final x2 = w * 0.38;
    final x3 = w * 0.56;
    final yTop = h * 0.16;
    final yBot = h * 0.84;

    canvas.drawLine(Offset(x1, yTop), Offset(x1, yBot), stroke);
    canvas.drawLine(Offset(x2, yTop), Offset(x2, yBot), stroke);
    canvas.drawLine(Offset(x3, yTop), Offset(x3, yBot), stroke);
    canvas.drawLine(Offset(w * 0.72, yTop + h * 0.02), Offset(w * 0.87, yBot), stroke);
  }

  @override
  bool shouldRepaint(covariant _LibraryBooksPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

class YouTubeMusicLogoIcon extends StatelessWidget {
  final double size;
  const YouTubeMusicLogoIcon({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.ytRed,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: (size * 0.05).clamp(1.5, 2.8)),
          ),
          child: Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: size * 0.44,
            ),
          ),
        ),
      ),
    );
  }
}

class SpotifyLogoIcon extends StatelessWidget {
  final double size;
  const SpotifyLogoIcon({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SpotifyPainter(),
    );
  }
}

class _SpotifyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = AppColors.spotifyGreen);

    final wavePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      wavePaint.strokeWidth = (size.width * (0.092 - i * 0.014)).clamp(1.8, 5.0);
      final yOffset = size.height * (0.37 + i * 0.145);
      final halfSpan = size.width * (0.28 - i * 0.045);
      final arch = size.height * (0.065 - i * 0.01);
      final path = Path()
        ..moveTo(c.dx - halfSpan, yOffset + arch * 0.4)
        ..quadraticBezierTo(
          c.dx + size.width * 0.02,
          yOffset - arch,
          c.dx + halfSpan,
          yOffset + arch * 0.75,
        );
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InstagramLogoIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const InstagramLogoIcon({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).iconTheme.color ?? Colors.black;
    return CustomPaint(
      size: Size.square(size),
      painter: _InstagramPainter(color: c),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  final Color color;
  const _InstagramPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.085).clamp(1.5, 2.5);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final inset = w * 0.11;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2),
        Radius.circular(w * 0.24),
      ),
      stroke,
    );

    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.19, stroke);
    canvas.drawCircle(
      Offset(w * 0.72, h * 0.28),
      (w * 0.055).clamp(1.2, 2.2),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _InstagramPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TikTokLogoIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const TikTokLogoIcon({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).iconTheme.color ?? Colors.black;
    return CustomPaint(
      size: Size.square(size),
      painter: _TikTokPainter(color: c),
    );
  }
}

class _TikTokPainter extends CustomPainter {
  final Color color;
  const _TikTokPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.105).clamp(1.8, 3.0);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(w * 0.56, h * 0.16)
      ..lineTo(w * 0.56, h * 0.67)
      ..arcToPoint(
        Offset(w * 0.26, h * 0.68),
        radius: Radius.circular(w * 0.16),
        clockwise: true,
      )
      ..arcToPoint(
        Offset(w * 0.43, h * 0.50),
        radius: Radius.circular(w * 0.15),
        clockwise: true,
      );
    canvas.drawPath(path, stroke);

    final hook = Path()
      ..moveTo(w * 0.56, h * 0.16)
      ..quadraticBezierTo(w * 0.60, h * 0.34, w * 0.78, h * 0.35);
    canvas.drawPath(hook, stroke);
  }

  @override
  bool shouldRepaint(covariant _TikTokPainter oldDelegate) =>
      oldDelegate.color != color;
}
