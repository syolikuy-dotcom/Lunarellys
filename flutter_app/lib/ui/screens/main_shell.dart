import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/lunarellys_drawer.dart';
import '../widgets/lunarellys_logo.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'search_screen.dart';
import 'you_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _navCollapsed = false;
  double _lastScrollPixels = 0;

  void _openNowPlaying() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved);
          return FadeTransition(
            opacity: Tween<double>(begin: 0.75, end: 1.0).animate(curved),
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  void _selectTab(int idx) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = idx;
      _navCollapsed = false;
      _lastScrollPixels = 0;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final pixels = notification.metrics.pixels;
    final delta = pixels - _lastScrollPixels;
    _lastScrollPixels = pixels;

    if (pixels <= 20) {
      if (_navCollapsed) {
        setState(() => _navCollapsed = false);
      }
      return false;
    }

    if (delta > 8 && !_navCollapsed && pixels > 64) {
      setState(() => _navCollapsed = true);
    } else if (delta < -10 && _navCollapsed) {
      setState(() => _navCollapsed = false);
    }
    return false;
  }

  IconData _activeIconFor(int index) {
    return switch (index) {
      0 => Icons.home_rounded,
      1 => Icons.search_rounded,
      2 => Icons.library_music_rounded,
      _ => Icons.person_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final settings = ref.watch(settingsProvider);
    final hasTrack = player.currentTrack != null;
    final T = AppStrings.of(settings.appLanguage);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    final accent = settings.dynamicAlbumColors ? player.dynamicColor : null;
    final glassAccent = accent ?? const Color(0xFF7FA3C7);
    final showCompactInline = _navCollapsed;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: LunarellysDrawer(
        onNavigateTab: (tabIdx) => _selectTab(tabIdx),
      ),
      body: LiquidGlassAmbientBackground(
        accentColor: accent,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: const [
                  HomeScreen(),
                  SearchScreen(),
                  LibraryScreen(),
                  YouScreen(),
                ],
              ),

              // Smooth spring morphing MiniPlayer between floating expanded & inline compact pill
              if (hasTrack)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: showCompactInline ? 80 : 12,
                  right: showCompactInline ? 14 : 12,
                  bottom: bottomInset + (showCompactInline ? 12 : 84),
                  child: MiniPlayer(
                    compact: showCompactInline,
                    onTap: _openNowPlaying,
                  ),
                ),

              // Collapsed state: left circular active-tab Liquid Glass orb
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: 14,
                bottom: bottomInset + (showCompactInline ? 12 : -76),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: showCompactInline ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !showCompactInline,
                    child: LiquidGlassTap(
                      onTap: () => setState(() => _navCollapsed = false),
                      child: LiquidGlassSurface(
                        borderRadius: BorderRadius.circular(999),
                        blurSigma: 28,
                        chromaticAccent: glassAccent,
                        child: SizedBox(
                          width: 58,
                          height: 58,
                          child: Center(
                            child: _selectedIndex == 2
                                ? LibraryBooksIcon(size: 22, color: ink, filled: true)
                                : Icon(_activeIconFor(_selectedIndex), color: ink, size: 25),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Expanded 4-tab Liquid Glass bottom navigation capsule
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: 14,
                right: 14,
                bottom: bottomInset + (showCompactInline ? -88 : 10),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  scale: showCompactInline ? 0.92 : 1.0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: showCompactInline ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: showCompactInline,
                      child: LiquidGlassCapsule(
                        blurSigma: 28,
                        chromaticAccent: hasTrack ? glassAccent : null,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: SizedBox(
                          height: 54,
                          child: Row(
                            children: [
                              _NavTabItem(
                                selected: _selectedIndex == 0,
                                label: T.navHome,
                                ink: ink,
                                sub: sub,
                                isDark: isDark,
                                iconBuilder: (active, color) => Icon(
                                  active ? Icons.home_rounded : Icons.home_outlined,
                                  color: color,
                                  size: 23,
                                ),
                                onTap: () => _selectTab(0),
                              ),
                              _NavTabItem(
                                selected: _selectedIndex == 1,
                                label: T.navSearch,
                                ink: ink,
                                sub: sub,
                                isDark: isDark,
                                iconBuilder: (active, color) => Icon(
                                  Icons.search_rounded,
                                  color: color,
                                  size: 23,
                                ),
                                onTap: () => _selectTab(1),
                              ),
                              _NavTabItem(
                                selected: _selectedIndex == 2,
                                label: T.navLibrary,
                                ink: ink,
                                sub: sub,
                                isDark: isDark,
                                iconBuilder: (active, color) => LibraryBooksIcon(
                                  size: 21,
                                  color: color,
                                  filled: active,
                                ),
                                onTap: () => _selectTab(2),
                              ),
                              _NavTabItem(
                                selected: _selectedIndex == 3,
                                label: T.navYou,
                                ink: ink,
                                sub: sub,
                                isDark: isDark,
                                iconBuilder: (active, color) => Icon(
                                  active ? Icons.person_rounded : Icons.person_outline_rounded,
                                  color: color,
                                  size: 23,
                                ),
                                onTap: () => _selectTab(3),
                              ),
                            ],
                          ),
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
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final bool selected;
  final String label;
  final Color ink;
  final Color sub;
  final bool isDark;
  final Widget Function(bool active, Color color) iconBuilder;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.selected,
    required this.label,
    required this.ink,
    required this.sub,
    required this.isDark,
    required this.iconBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? ink : sub;
    final activePill = isDark
        ? Colors.white.withAlpha(26)
        : Colors.black.withAlpha(14);

    return Expanded(
      child: LiquidGlassTap(
        onTap: onTap,
        pressedScale: 0.92,
        haptic: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected ? activePill : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                scale: selected ? 1.06 : 1.0,
                child: iconBuilder(selected, color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
