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
  int _loopGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restartLoop());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled) {
      _restartLoop();
    } else {
      _loopGen++;
    }
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _restartLoop());
    }
  }

  Future<void> _restartLoop() async {
    final gen = ++_loopGen;
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    try {
      while (mounted && gen == _loopGen && TickerMode.valuesOf(context).enabled) {
        await Future<void>.delayed(widget.pauseDuration);
        if (!mounted || gen != _loopGen || !_scroll.hasClients) break;
        final maxExtent = _scroll.position.maxScrollExtent;
        if (maxExtent <= 4) break;
        final ms = ((maxExtent / widget.velocityPxPerSec) * 1000)
            .round()
            .clamp(1200, 12000);
        await _scroll.animateTo(
          maxExtent,
          duration: Duration(milliseconds: ms),
          curve: Curves.linear,
        );
        if (!mounted || gen != _loopGen) break;
        await Future<void>.delayed(widget.pauseDuration);
        if (!mounted || gen != _loopGen || !_scroll.hasClients) break;
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      // Scroll controller disposed or detached mid-animation.
    }
  }

  @override
  void dispose() {
    _loopGen++;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroller = SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        widget.text,
        maxLines: 1,
        softWrap: false,
        style: widget.style,
      ),
    );

    return ClipRect(
      child: AnimatedBuilder(
        animation: _scroll,
        builder: (context, child) {
          final hasDims =
              _scroll.hasClients && _scroll.position.hasContentDimensions;
          final offset = hasDims ? _scroll.offset : 0.0;
          final maxExt = hasDims ? _scroll.position.maxScrollExtent : 0.0;
          final fadeLeft = offset > 2.0;
          final fadeRight = maxExt > 2.0 && offset < maxExt - 2.0;

          if (!fadeLeft && !fadeRight) {
            return child!;
          }

          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                fadeLeft ? Colors.transparent : Colors.white,
                Colors.white,
                Colors.white,
                fadeRight ? Colors.transparent : Colors.white,
              ],
              stops: const [0.0, 0.06, 0.90, 1.0],
            ).createShader(bounds),
            child: child,
          );
        },
        child: scroller,
      ),
    );
  }
}
