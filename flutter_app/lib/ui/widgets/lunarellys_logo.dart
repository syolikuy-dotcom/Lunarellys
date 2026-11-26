import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LunarellysHorizonLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const LunarellysHorizonLogo({
    super.key,
    this.size = 76,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.horizonBlue;
    return CustomPaint(
      size: Size.square(size),
      painter: _HorizonLogoPainter(color: activeColor),
    );
  }
}

class _HorizonLogoPainter extends CustomPainter {
  final Color color;
  const _HorizonLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final baseY = h * 0.58;
    final radius = w * 0.36;

    canvas.save();
    // Clip to top semicircle above baseY
    final semiClip = Path()
      ..moveTo(cx - radius, baseY)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, baseY), radius: radius),
        math.pi,
        math.pi,
        false,
      )
      ..close();
    canvas.clipPath(semiClip);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw horizontal stacked horizon slices inside semicircle (sunset stripes)
    final sliceSpecs = [
      (top: 0.0, height: 0.42),
      (top: 0.49, height: 0.14),
      (top: 0.70, height: 0.12),
      (top: 0.89, height: 0.11),
    ];
    for (final s in sliceSpecs) {
      final y0 = baseY - radius + (s.top * radius);
      final sh = s.height * radius;
      canvas.drawRect(Rect.fromLTWH(0, y0, w, sh), fillPaint);
    }
    canvas.restore();

    // Dark slate horizon line bar
    final linePaint = Paint()
      ..color = color.withAlpha(240)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (w * 0.048).clamp(2.2, 6.0)
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.08, baseY + h * 0.065),
      Offset(w * 0.92, baseY + h * 0.065),
      linePaint,
    );

    // Sharp ocean chevron / wave line below
    final waveYTop = baseY + h * 0.14;
    final waveYBot = baseY + h * 0.255;
    final wavePath = Path()
      ..moveTo(w * 0.12, waveYTop + (waveYBot - waveYTop) * 0.45)
      ..lineTo(w * 0.25, waveYTop)
      ..lineTo(w * 0.375, waveYBot)
      ..lineTo(w * 0.50, waveYTop)
      ..lineTo(w * 0.625, waveYBot)
      ..lineTo(w * 0.75, waveYTop)
      ..lineTo(w * 0.88, waveYTop + (waveYBot - waveYTop) * 0.55);

    canvas.drawPath(
      wavePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.048).clamp(2.2, 6.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HorizonLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}

class LunarellysLogo extends StatelessWidget {
  final double size;
  final bool animate;

  const LunarellysLogo({
    super.key,
    this.size = 48,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return LunarellysHorizonLogo(
      size: size,
      color: dark ? AppColors.horizonBlueSoft : AppColors.horizonBlue,
    );
  }
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
    // Slanted 4th spine leaning right
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

