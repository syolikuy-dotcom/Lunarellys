import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration pauseDuration;
  final double velocityPxPerSec;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.pauseDuration = const Duration(milliseconds: 1400),
    this.velocityPxPerSec = 36,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scroll = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoop());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoop());
    }
  }

  Future<void> _startLoop() async {
    if (_running || !mounted) return;
    _running = true;
    try {
      while (mounted) {
        await Future<void>.delayed(widget.pauseDuration);
        if (!mounted || !_scroll.hasClients) break;
        final maxExtent = _scroll.position.maxScrollExtent;
        if (maxExtent <= 4) break;
        final ms = ((maxExtent / widget.velocityPxPerSec) * 1000).round().clamp(1200, 12000);
        await _scroll.animateTo(
          maxExtent,
          duration: Duration(milliseconds: ms),
          curve: Curves.linear,
        );
        if (!mounted) break;
        await Future<void>.delayed(widget.pauseDuration);
        if (!mounted || !_scroll.hasClients) break;
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        maxLines: 1,
        softWrap: false,
        style: widget.style,
      ),
    );
  }
}
