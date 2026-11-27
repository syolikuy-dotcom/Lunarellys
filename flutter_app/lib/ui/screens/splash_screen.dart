import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/lunarellys_logo.dart';

class LaunchSplashGate extends StatefulWidget {
  final Widget child;
  const LaunchSplashGate({super.key, required this.child});

  @override
  State<LaunchSplashGate> createState() => _LaunchSplashGateState();
}

class _LaunchSplashGateState extends State<LaunchSplashGate>
    with SingleTickerProviderStateMixin {
  bool _fadingOut = false;
  bool _removed = false;
  late final AnimationController _ctrl;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _ringScale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..forward();

    _textOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.32, 0.85, curve: Curves.easeOutCubic),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.24),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.32, 0.90, curve: Curves.easeOutCubic),
      ),
    );
    _ringScale = Tween<double>(begin: 0.72, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    Timer(const Duration(milliseconds: 1450), () {
      if (mounted) setState(() => _fadingOut = true);
    });
    Timer(const Duration(milliseconds: 1860), () {
      if (mounted) setState(() => _removed = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bg = isDark ? const Color(0xFF0B1520) : const Color(0xFFF6F7F9);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return Stack(
      children: [
        widget.child,
        if (!_removed)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _fadingOut,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOut,
                opacity: _fadingOut ? 0.0 : 1.0,
              child: ColoredBox(
                color: bg,
                child: SafeArea(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Soft liquid glass halo expansion
                      AnimatedBuilder(
                        animation: _ringScale,
                        builder: (context, _) => Transform.scale(
                          scale: _ringScale.value,
                          child: Container(
                            width: 196,
                            height: 196,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.horizonBlue.withAlpha(isDark ? 72 : 34),
                                  AppColors.horizonBlueSoft.withAlpha(isDark ? 24 : 12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LiquidGlassSurface(
                            borderRadius: BorderRadius.circular(36),
                            blurSigma: 28,
                            chromaticAccent: AppColors.horizonBlueSoft,
                            padding: const EdgeInsets.all(22),
                            child: const AnimatedLunarellysLogo(
                              size: 96,
                              loopPulse: true,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FadeTransition(
                            opacity: _textOpacity,
                            child: SlideTransition(
                              position: _textSlide,
                              child: Column(
                                children: [
                                  Text(
                                    AppConfig.appName,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.7,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'High-Fidelity Music Streaming',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: sub,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 34,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Column(
                            children: [
                              CupertinoActivityIndicator(
                                radius: 11,
                                color: isDark
                                    ? AppColors.horizonBlueSoft
                                    : AppColors.horizonBlue,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'by ${AppConfig.developerName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sub.withAlpha(190),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
      ],
    );
  }
}
