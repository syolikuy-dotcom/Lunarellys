import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';
import '../widgets/google_logo.dart';
import '../widgets/lunarellys_logo.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool allowBack;
  const AuthScreen({super.key, this.allowBack = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with TickerProviderStateMixin {
  late final AnimationController _ambientCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _actionsFade;
  late final Animation<Offset> _actionsSlide;

  bool _googlePressed = false;
  bool _guestPressed = false;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();

    _logoFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));

    _titleFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.18, 0.68, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
    ));

    _actionsFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.42, 1.0, curve: Curves.easeOut),
    );
    _actionsSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    final result = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (result.launched) {
      if (widget.allowBack && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }
    if (result.oauthUnconfigured) {
      _showGoogleUnavailableSheet();
      return;
    }
    if (result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message!)),
      );
    }
  }

  Future<void> _handleGuest() async {
    await ref.read(authProvider.notifier).continueAsGuest();
    if (!mounted) return;
    if (widget.allowBack && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _showGoogleUnavailableSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const GoogleLogoIcon(size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Google Sign-In Unavailable',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Google Sign-In is temporarily unavailable right now. You can continue listening as a Guest immediately.',
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleGuest();
                  },
                  child: const Text('Continue as Guest'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (_, __) {
              final t = _ambientCtrl.value;
              final pulse = 0.85 + 0.25 * math.sin(t * math.pi);
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.2 + 0.35 * t, -0.55 + 0.15 * t),
                    radius: 1.15 * pulse,
                    colors: [
                      AppColors.brandGreen.withAlpha(68),
                      const Color(0xFF143522).withAlpha(110),
                      AppColors.backgroundDeep,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (ctx, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.allowBack)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _logoFade,
                        child: SlideTransition(
                          position: _logoSlide,
                          child: Column(
                            children: [
                              AnimatedBuilder(
                                animation: _ambientCtrl,
                                builder: (_, child) {
                                  final scale = 1.0 + 0.045 * math.sin(_ambientCtrl.value * math.pi * 2);
                                  return Transform.scale(scale: scale, child: child);
                                },
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.brandGreenBright.withAlpha(95),
                                        blurRadius: 36,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const LunarellysLogo(size: 96),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'LUNARELLYS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  letterSpacing: 3.4,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandGreenBright,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: Column(
                            children: [
                              Text(
                                'Millions of songs.\nFree on Lunarellys.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -0.9,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Stream high-quality audio, sing with synced lyrics, save offline tracks, and sync playlists with your Google account.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      FadeTransition(
                        opacity: _actionsFade,
                        child: SlideTransition(
                          position: _actionsSlide,
                          child: Column(
                            children: [
                              if (auth.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    auth.error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                                  ),
                                ),
                              GestureDetector(
                                onTapDown: (_) => setState(() => _googlePressed = true),
                                onTapUp: (_) => setState(() => _googlePressed = false),
                                onTapCancel: () => setState(() => _googlePressed = false),
                                onTap: auth.isAuthenticating ? null : _handleGoogleLogin,
                                child: AnimatedScale(
                                  scale: _googlePressed ? 0.97 : 1.0,
                                  duration: const Duration(milliseconds: 110),
                                  child: Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(80),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: auth.isAuthenticating
                                        ? const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.black,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const GoogleLogoIcon(size: 20),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Continue with Google',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTapDown: (_) => setState(() => _guestPressed = true),
                                onTapUp: (_) => setState(() => _guestPressed = false),
                                onTapCancel: () => setState(() => _guestPressed = false),
                                onTap: _handleGuest,
                                child: AnimatedScale(
                                  scale: _guestPressed ? 0.97 : 1.0,
                                  duration: const Duration(milliseconds: 110),
                                  child: Container(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: AppColors.borderStrong, width: 1.3),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Continue as Guest',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
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
        ],
      ),
    );
  }
}
