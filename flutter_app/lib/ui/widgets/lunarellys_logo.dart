import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Minimalist Apple Liquid Glass Archys monogram:
/// Sleek architectural "A" arch + inner acoustic resonance pearl + horizontal bridge.
class ArchysHorizonLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final double animationProgress;

  const ArchysHorizonLogo({
    super.key,
    this.size = 76,
    this.color,
    this.animationProgress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final activeColor = color ??
        (isDark ? const Color(0xFFF4F8FC) : const Color(0xFF0F172A));
    final secondaryAccent = isDark
        ? const Color(0xFF7EC8FF)
        : const Color(0xFF2563EB);

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

    // 1. Subtle sapphire glass aura behind crest
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withAlpha(((isDark ? 64 : 42) * progress).round()),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.48));
    canvas.drawCircle(Offset(cx, cy), w * 0.48, auraPaint);

    // 2. Crisp geometric precision ring rim (subtle Liquid Glass perimeter)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.022).clamp(0.9, 2.2)
      ..color = accentColor.withAlpha((72 * progress).round());
    canvas.drawCircle(Offset(cx, cy), w * 0.42 * progress, ringPaint);

    // 3. Architectural "A" Arch Monogram
    final archT = Curves.easeOutCubic.transform((progress * 1.12).clamp(0.0, 1.0));
    final topY = h * 0.17;
    final botY = h * 0.81;
    final spanX = w * 0.30 * archT;
    final legW = w * 0.095;

    final archPath = Path()
      ..moveTo(cx, topY)
      ..cubicTo(
        cx + w * 0.06,
        topY,
        cx + spanX * 0.45,
        h * 0.34,
        cx + spanX,
        botY,
      )
      ..lineTo(cx + spanX - legW, botY)
      ..lineTo(cx, h * 0.41)
      ..lineTo(cx - spanX + legW, botY)
      ..lineTo(cx - spanX, botY)
      ..cubicTo(
        cx - spanX * 0.45,
        h * 0.34,
        cx - w * 0.06,
        topY,
        cx,
        topY,
      )
      ..close();

    final archPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor,
          Color.lerp(primaryColor, accentColor, 0.28) ?? primaryColor,
        ],
      ).createShader(Rect.fromLTWH(0, topY, w, botY - topY));
    canvas.drawPath(archPath, archPaint);

    // 4. Inner specular bevel highlight along upper-left arch slope
    if (archT > 0.3) {
      final bevelPath = Path()
        ..moveTo(cx - w * 0.015, topY + h * 0.03)
        ..quadraticBezierTo(
          cx - spanX * 0.48,
          h * 0.42,
          cx - spanX * 0.82,
          botY - h * 0.14,
        );
      canvas.drawPath(
        bevelPath,
        Paint()
          ..color = Colors.white.withAlpha(((isDark ? 120 : 140) * progress).round())
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (w * 0.025).clamp(0.9, 2.5),
      );
    }

    // 5. Harmonic acoustic bridge crossbar
    final barT = Curves.easeOutCubic.transform(((progress - 0.15) / 0.85).clamp(0.0, 1.0));
    if (barT > 0.02) {
      final barHalfW = w * 0.155 * barT;
      final barY = h * 0.635;
      final barH = (h * 0.088).clamp(2.2, 8.5);
      final barRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, barY), width: barHalfW * 2, height: barH),
        Radius.circular(barH * 0.5),
      );
      canvas.drawRRect(
        barRRect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              accentColor,
              Color.lerp(accentColor, Colors.white, 0.22) ?? accentColor,
            ],
          ).createShader(barRRect.outerRect),
      );
    }

    // 6. Resonance pearl orb nestled cleanly inside arch apex
    final orbT = Curves.easeOutBack.transform(((progress - 0.2) / 0.8).clamp(0.0, 1.0));
    if (orbT > 0.01) {
      final orbCenter = Offset(cx, h * 0.485);
      final orbRadius = (w * 0.058) * orbT;
      canvas.drawCircle(
        orbCenter,
        orbRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.35),
            colors: [
              Colors.white.withAlpha(230),
              accentColor,
              Color.lerp(accentColor, primaryColor, 0.35) ?? accentColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: orbCenter, radius: orbRadius)),
      );
    }
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
