import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LunarellysLogo extends StatelessWidget {
  final double size;
  final Color? discColor;
  final Color waveColor;

  const LunarellysLogo({
    super.key,
    this.size = 40,
    this.discColor,
    this.waveColor = AppColors.backgroundDeep,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LunarellysLogoPainter(
          discColor: discColor ?? AppColors.brandGreenBright,
          waveColor: waveColor,
        ),
      ),
    );
  }
}

class _LunarellysLogoPainter extends CustomPainter {
  final Color discColor;
  final Color waveColor;

  const _LunarellysLogoPainter({
    required this.discColor,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    final discPaint = Paint()
      ..color = discColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, s * 0.5, discPaint);

    void drawWave({
      required Offset start,
      required Offset control,
      required Offset end,
      required double strokeScale,
    }) {
      final path = Path()
        ..moveTo(start.dx * s, start.dy * s)
        ..quadraticBezierTo(
          control.dx * s,
          control.dy * s,
          end.dx * s,
          end.dy * s,
        );
      final paint = Paint()
        ..color = waveColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * strokeScale;
      canvas.drawPath(path, paint);
    }

    drawWave(
      start: const Offset(0.24, 0.37),
      control: const Offset(0.51, 0.25),
      end: const Offset(0.77, 0.39),
      strokeScale: 0.088,
    );
    drawWave(
      start: const Offset(0.29, 0.52),
      control: const Offset(0.51, 0.42),
      end: const Offset(0.72, 0.54),
      strokeScale: 0.076,
    );
    drawWave(
      start: const Offset(0.34, 0.66),
      control: const Offset(0.51, 0.58),
      end: const Offset(0.67, 0.67),
      strokeScale: 0.066,
    );
  }

  @override
  bool shouldRepaint(covariant _LunarellysLogoPainter oldDelegate) {
    return oldDelegate.discColor != discColor || oldDelegate.waveColor != waveColor;
  }
}
