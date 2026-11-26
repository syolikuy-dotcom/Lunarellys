import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Clean minimalist Lunarellys emblem: sculptural crescent paired with dual
/// harmonic sound bars on a deep obsidian squircle.
class LunarellysLogo extends StatelessWidget {
  final double size;
  final Color? accentColor;

  const LunarellysLogo({
    super.key,
    this.size = 40,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LunarellysLogoPainter(
          accentColor: accentColor ?? AppColors.brandGreenBright,
        ),
      ),
    );
  }
}

class _LunarellysLogoPainter extends CustomPainter {
  final Color accentColor;

  const _LunarellysLogoPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size(s, s);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.26));

    // Clean deep obsidian squircle background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF121A1E),
          Color(0xFF0A0E11),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // Subtle crisp glass edge
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.03).clamp(0.8, 2.0)
      ..color = Colors.white.withAlpha(24);
    canvas.drawRRect(rrect.deflate(s * 0.015), borderPaint);

    // Sculptural crescent (scaled cleanly inside squircle)
    final outerMoon = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(s * 0.514, s * 0.50),
        radius: s * 0.326,
      ));
    final cutoutMoon = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(s * 0.667, s * 0.458),
        radius: s * 0.271,
      ));
    final crescent = Path.combine(PathOperation.difference, outerMoon, cutoutMoon);
    canvas.drawPath(crescent, Paint()..color = accentColor);

    // Two clean rounded harmonic bars inside crescent cavity
    final barPaint = Paint()..color = Colors.white;
    final barW = s * 0.078;
    final barR = Radius.circular(barW / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.590, s * 0.299, barW, s * 0.319),
        barR,
      ),
      barPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.721, s * 0.382, barW, s * 0.236),
        barR,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LunarellysLogoPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}
