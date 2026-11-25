import 'package:flutter/material.dart';

class AnimatedEqualizer extends StatefulWidget {
  final Color color;
  final bool isPlaying;
  final double size;

  const AnimatedEqualizer({
    super.key,
    required this.color,
    required this.isPlaying,
    this.size = 20,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _barFactor(double phaseOffset) {
    if (!widget.isPlaying) return 0.35;
    final t = (_controller.value + phaseOffset) % 1.0;
    final wave = (t < 0.5 ? t * 2 : (1.0 - t) * 2);
    return 0.25 + (wave * 0.75);
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = widget.size * 0.2;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(barWidth, _barFactor(0.0)),
              _bar(barWidth, _barFactor(0.35)),
              _bar(barWidth, _barFactor(0.7)),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(double width, double heightFactor) {
    return Container(
      width: width,
      height: widget.size * heightFactor,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
