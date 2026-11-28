import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/device_permissions_service.dart';
import '../../state/dynamic_island_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/dynamic_island.dart';
import '../widgets/ios_control_center.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/lunarellys_drawer.dart';
import '../widgets/mini_player.dart';
import '../widgets/subscreen_mini_player.dart';
import 'detail_screens.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'you_screen.dart';

/// Shared scroll-collapse state so tab FABs smoothly reposition with the
/// morphing Liquid Glass bottom navigation capsule.
final navCollapsedProvider = StateProvider<bool>((ref) => false);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _navCollapsed = false;
  double _lastScrollPixels = 0;
  String _lastSyncedLyricsTrackId = '';
  Object? _lastSyncedLyricsRef;
  DateTime _lastPositionSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastSyncedPositionMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerOverlayActions();
      _syncSystemDynamicIsland(forceLyrics: true);
      unawaited(_ensureInitialPermissions());
    });
  }

  @override
  void dispose() {
    ref
        .read(devicePermissionsProvider.notifier)
        .setDynamicIslandActionHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(devicePermissionsProvider.notifier).refresh());
      _syncSystemDynamicIsland(forceLyrics: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _syncSystemDynamicIsland(forceLyrics: true);
    }
  }

  void _registerOverlayActions() {
    if (!mounted) return;
    ref.read(devicePermissionsProvider.notifier).setDynamicIslandActionHandler(
      (action) {
        if (!mounted) return;
        final player = ref.read(playerProvider.notifier);
        if (action.startsWith('seek:')) {
          final ms = int.tryParse(action.substring(5));
          if (ms != null) {
            unawaited(player.seek(Duration(milliseconds: ms)));
          }
          return;
        }
        switch (action) {
          case 'toggle':
            unawaited(player.togglePlayPause());
            break;
          case 'next':
            unawaited(player.skipNext());
            break;
          case 'prev':
            unawaited(player.skipPrevious());
            break;
          case 'open':
            if (ref.read(playerProvider).currentTrack != null) {
              _openNowPlaying();
            }
            break;
        }
      },
    );
  }

  void _syncSystemDynamicIsland({bool forceLyrics = false}) {
    if (!mounted || kIsWeb) return;
    final player = ref.read(playerProvider);
    final settings = ref.read(settingsProvider);
    final track = player.currentTrack;
    final trackId = track?.id ?? '';
    final accent = (settings.dynamicAlbumColors ? player.dynamicColor : null) ??
        const Color(0xFF5DA7E8);

    List<Map<String, dynamic>>? serializedLyrics;
    final lyricsObj = player.lyrics;
    final lyricsChanged = forceLyrics ||
        trackId != _lastSyncedLyricsTrackId ||
        !identical(lyricsObj, _lastSyncedLyricsRef);
    if (lyricsChanged) {
      _lastSyncedLyricsTrackId = trackId;
      _lastSyncedLyricsRef = lyricsObj;
      if (lyricsObj != null && lyricsObj.lines.isNotEmpty) {
        serializedLyrics = lyricsObj.lines.map((l) {
          final secondary = settings.aiTranslateLyrics &&
                  (l.translated?.trim().isNotEmpty ?? false)
              ? l.translated!.trim()
              : (settings.romanizeLyrics &&
                      (l.romanized?.trim().isNotEmpty ?? false)
                  ? l.romanized!.trim()
                  : null);
          return <String, dynamic>{
            if (l.timeMs != null) 'timeMs': l.timeMs,
            'text': l.text,
            if (secondary != null) 'secondary': secondary,
          };
        }).toList(growable: false);
      } else {
        serializedLyrics = const <Map<String, dynamic>>[];
      }
    }

    final posMs = player.position.inMilliseconds;
    final durMs = player.duration.inMilliseconds;
    _lastPositionSyncAt = DateTime.now();
    _lastSyncedPositionMs = posMs;

    unawaited(
      ref.read(devicePermissionsProvider.notifier).updatePlaybackAndLyrics(
            enabled: settings.dynamicIslandEnabled,
            alwaysVisible: settings.dynamicIslandAlwaysVisible,
            systemOverlayEnabled: settings.dynamicIslandSystemOverlay,
            positionMode: settings.dynamicIslandPosition,
            lockScreenLyricsEnabled: settings.lockScreenLyricsEnabled,
            hasTrack: track != null,
            trackId: trackId,
            title: track?.title ?? AppConfig.appName,
            artist: track?.artistDisplay ?? 'Siap memutar musik',
            artUrl: track?.bestThumbUrl(size: 400) ?? '',
            isPlaying: player.isPlaying,
            positionMs: posMs,
            durationMs: durMs,
            lyricsOffsetMs: settings.lyricsOffsetMs,
            accentColor: accent.toARGB32(),
            lyrics: serializedLyrics,
          ),
    );
  }

  Future<void> _ensureInitialPermissions() async {
    if (!mounted || kIsWeb) return;
    final permsNotifier = ref.read(devicePermissionsProvider.notifier);
    await permsNotifier.refresh();
    if (!mounted) return;
    final perms = ref.read(devicePermissionsProvider);
    final islandEnabled = ref.read(settingsProvider).dynamicIslandEnabled;
    final prefs = ref.read(sharedPreferencesProvider);
    const promptedKey = 'prompted_notifications_ios27_v1';
    final alreadyPrompted = prefs.getBool(promptedKey) ?? false;

    if (!alreadyPrompted && islandEnabled && !perms.notificationsGranted) {
      await prefs.setBool(promptedKey, true);
      final granted = await permsNotifier.requestNotifications();
      if (mounted && granted) {
        ref.read(dynamicIslandEventProvider.notifier).show(
              const DynamicIslandEvent(
                icon: Icons.verified_rounded,
                title: 'Dynamic Island Aktif',
                subtitle: 'Notifikasi & kontrol layar kunci siap',
                accent: Color(0xFF22C55E),
              ),
            );
      }
    }
  }

  void _openNowPlaying() => openNowPlayingSheet(context);

  void _setCollapsed(bool collapsed) {
    if (_navCollapsed == collapsed) return;
    setState(() => _navCollapsed = collapsed);
    ref.read(navCollapsedProvider.notifier).state = collapsed;
  }

  void _selectTab(int idx) {
    if (ref.read(settingsProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _selectedIndex = idx;
      _navCollapsed = false;
      _lastScrollPixels = 0;
    });
    ref.read(navCollapsedProvider.notifier).state = false;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final pixels = notification.metrics.pixels;
    final delta = pixels - _lastScrollPixels;
    _lastScrollPixels = pixels;

    if (pixels <= 20) {
      if (_navCollapsed) _setCollapsed(false);
      return false;
    }

    if (delta > 8 && !_navCollapsed && pixels > 64) {
      _setCollapsed(true);
    } else if (delta < -10 && _navCollapsed) {
      _setCollapsed(false);
    }
    return false;
  }

  IconData _activeIconFor(int index) {
    return switch (index) {
      0 => CupertinoIcons.house_fill,
      1 => CupertinoIcons.search,
      2 => CupertinoIcons.music_albums_fill,
      _ => CupertinoIcons.person_fill,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProvider.select((s) => s.currentTrack?.id), (_, __) {
      _syncSystemDynamicIsland(forceLyrics: true);
    });
    ref.listen(playerProvider.select((s) => s.lyrics), (_, __) {
      _syncSystemDynamicIsland(forceLyrics: true);
    });
    ref.listen(playerProvider.select((s) => s.isPlaying), (_, __) {
      _syncSystemDynamicIsland();
    });
    ref.listen(playerProvider.select((s) => s.duration), (_, __) {
      _syncSystemDynamicIsland();
    });
    ref.listen(playerProvider.select((s) => s.position), (_, nextPos) {
      final now = DateTime.now();
      final deltaMs = (nextPos.inMilliseconds - _lastSyncedPositionMs).abs();
      final elapsedSince = now.difference(_lastPositionSyncAt).inMilliseconds;
      if (deltaMs > 1800 || elapsedSince >= 1500) {
        _syncSystemDynamicIsland();
      }
    });
    ref.listen(playerProvider.select((s) => s.dynamicColor), (_, __) {
      _syncSystemDynamicIsland();
    });
    ref.listen(settingsProvider.select((s) => s.dynamicIslandEnabled), (_, __) {
      _syncSystemDynamicIsland();
    });
    ref.listen(
      settingsProvider.select((s) => s.dynamicIslandAlwaysVisible),
      (_, __) => _syncSystemDynamicIsland(),
    );
    ref.listen(
      settingsProvider.select((s) => s.dynamicIslandSystemOverlay),
      (_, __) => _syncSystemDynamicIsland(),
    );
    ref.listen(
      settingsProvider.select((s) => s.dynamicIslandPosition),
      (_, __) => _syncSystemDynamicIsland(),
    );
    ref.listen(
      settingsProvider.select((s) => s.lockScreenLyricsEnabled),
      (_, __) => _syncSystemDynamicIsland(),
    );
    ref.listen(
      settingsProvider.select((s) => s.lyricsOffsetMs),
      (_, __) => _syncSystemDynamicIsland(),
    );
    ref.listen(
      settingsProvider.select((s) => s.dynamicAlbumColors),
      (_, __) => _syncSystemDynamicIsland(),
    );

    final hasTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack != null),
    );
    final dynamicColor = ref.watch(
      playerProvider.select((s) => s.dynamicColor),
    );
    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );
    final dynamicAlbumColors = ref.watch(
      settingsProvider.select((s) => s.dynamicAlbumColors),
    );
    final isGlass = ref.watch(
      settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
    );
    final glassOpacity = ref.watch(
      settingsProvider.select((s) => s.liquidGlassOpacity),
    );
    final T = AppStrings.of(appLanguage);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenW = MediaQuery.sizeOf(context).width;
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    final accent = dynamicAlbumColors ? dynamicColor : null;
    final glassAccent = accent ?? AppColors.horizonBlue;
    final showCompactInline = _navCollapsed;
    final barWidth = math.max(260.0, math.min(540.0, screenW - 28.0));

    final pagesBody = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          SearchScreen(),
          LibraryScreen(),
          YouScreen(),
        ],
      ),
    );

    final overlayWidgets = <Widget>[
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
        child: IgnorePointer(
          ignoring: !showCompactInline,
          child: LiquidGlassTap(
            onTap: () => _setCollapsed(false),
            child: LiquidGlassSurface(
              borderRadius: BorderRadius.circular(999),
              blurSigma: 28,
              chromaticAccent: glassAccent,
              interactiveFlex: true,
              child: SizedBox(
                width: 58,
                height: 58,
                child: Center(
                  child: Icon(
                    _activeIconFor(_selectedIndex),
                    color: ink,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // Expanded 4-tab Navigation Capsule (LiquidGlassTabBar in Glass mode, Flat pill in Flat mode)
      if (isGlass)
        _buildLiquidGlassNavLayer(
          visible: !showCompactInline,
          bottomInset: bottomInset,
          barWidth: barWidth,
          isDark: isDark,
          ink: ink,
          sub: sub,
          accent: glassAccent,
          glassOpacity: glassOpacity,
          T: T,
        )
      else
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: 14,
          right: 14,
          bottom: bottomInset + (showCompactInline ? -88 : 10),
          child: IgnorePointer(
            ignoring: showCompactInline,
            child: _buildFlatNavCapsule(
              T: T,
              ink: ink,
              sub: sub,
              isDark: isDark,
            ),
          ),
        ),

      // Authentic iPhone top-right swipe-down gesture for Control Center
      Positioned(
        top: 0,
        right: 0,
        width: 88,
        height: MediaQuery.of(context).padding.top + 38,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 160) {
              showIosControlCenter(
                context,
                ref,
                onOpenEqualizer: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EqualizerScreen(),
                  ),
                ),
              );
            }
          },
        ),
      ),

      // Floating iOS Dynamic Island & Live Activity Overlay
      DynamicIslandOverlay(
        onOpenEqualizer: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const EqualizerScreen(),
          ),
        ),
      ),
    ];

    return PopScope(
      canPop: _selectedIndex == 0 && !showCompactInline,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (showCompactInline) {
          _setCollapsed(false);
        } else if (_selectedIndex != 0) {
          _selectTab(0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        drawer: LunarellysDrawer(
          onNavigateTab: (tabIdx) => _selectTab(tabIdx),
        ),
        body: isGlass
            ? LiquidGlassView(
                realTimeCapture: !ui.ImageFilter.isShaderFilterSupported,
                backgroundWidget: LiquidGlassAmbientBackground(
                  accentColor: accent,
                  child: pagesBody,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    fit: StackFit.expand,
                    children: overlayWidgets,
                  ),
                ),
              )
            : LiquidGlassAmbientBackground(
                accentColor: accent,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    pagesBody,
                    ...overlayWidgets,
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLiquidGlassNavLayer({
    required bool visible,
    required double bottomInset,
    required double barWidth,
    required bool isDark,
    required Color ink,
    required Color sub,
    required Color accent,
    required double glassOpacity,
    required AppStrings T,
  }) {
    final barAlpha = ui.lerpDouble(isDark ? 95 : 138, isDark ? 205 : 225, glassOpacity)!.round();
    final barColor = isDark
        ? Color.fromARGB(barAlpha, 24, 28, 36)
        : Color.fromARGB(barAlpha, 255, 255, 255);

    LiquidGlassTabBarItem buildTab(IconData icon, IconData activeIcon, String label) {
      return LiquidGlassTabBarItem(
        label: label,
        iconBuilder: (context, g) => Icon(
          g.selected ? activeIcon : icon,
          size: g.size,
          color: g.color,
          shadows: g.selected
              ? [Shadow(color: g.color.withAlpha(110), blurRadius: 12)]
              : null,
        ),
      );
    }

    final tabBar = LiquidGlassTabBar(
      items: [
        buildTab(CupertinoIcons.house, CupertinoIcons.house_fill, T.navHome),
        buildTab(CupertinoIcons.search, CupertinoIcons.search, T.navSearch),
        buildTab(CupertinoIcons.music_albums, CupertinoIcons.music_albums_fill, T.navLibrary),
        buildTab(CupertinoIcons.person, CupertinoIcons.person_fill, T.navYou),
      ],
      selectedIndex: _selectedIndex,
      onChanged: _selectTab,
      visibility: visible,
      width: barWidth,
      height: 62,
      itemPadding: 4,
      margin: const EdgeInsets.only(bottom: 10),
      alignment: Alignment.bottomCenter,
      swell: const LiquidGlassTabBarSwell(scale: 0.032, grip: 0.78),
      style: LiquidGlassStyle(
        shape: const LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 32),
        specular: LiquidGlassLight.specular(
          thickness: 4.5,
          intensity: isDark ? 0.68 : 0.95,
          oppositeIntensity: 0.45,
        ),
        glow: LiquidGlassLight.glow(
          thickness: 8,
          intensity: 0.24,
          oppositeIntensity: 0.14,
          color: accent,
        ),
        color: barColor,
        blur: (3.0 + glassOpacity * 4.5).clamp(2.5, 9.0),
        saturation: isDark ? 1.25 : 1.7,
        refractionIndex: 1.18,
        refractionWidth: 16,
        shadow: LiquidGlassShadow(
          blur: 20,
          opacity: isDark ? 0.28 : 0.12,
        ),
      ),
      itemStyle: LiquidGlassTabItemStyle(
        selectedColor: accent,
        unselectedColor: sub.withAlpha(isDark ? 215 : 225),
        iconSize: 22,
        underGlassIconSize: 25,
        labelFontSize: 10.5,
        underGlassLabelFontSize: 11.0,
        iconLabelGap: 2,
        selectedFontWeight: FontWeight.w700,
        unselectedFontWeight: FontWeight.w600,
      ),
      pillStyle: LiquidGlassTabPillStyle(
        mode: LiquidGlassPillMode.both,
        rest: LiquidGlassStyle(
          shape: const LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 28),
          color: isDark
              ? Colors.white.withAlpha(28)
              : accent.withAlpha(24),
        ),
      ),
    );

    if (ui.ImageFilter.isShaderFilterSupported) {
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: !visible,
          child: tabBar,
        ),
      );
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: 14,
      right: 14,
      bottom: bottomInset + (visible ? 10 : -88),
      child: IgnorePointer(
        ignoring: !visible,
        child: Center(child: tabBar),
      ),
    );
  }

  Widget _buildFlatNavCapsule({
    required AppStrings T,
    required Color ink,
    required Color sub,
    required bool isDark,
  }) {
    return LiquidGlassCapsule(
      blurSigma: 0,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            _FlatNavTabItem(
              selected: _selectedIndex == 0,
              label: T.navHome,
              ink: ink,
              sub: sub,
              isDark: isDark,
              iconBuilder: (active, color) => Icon(
                active ? CupertinoIcons.house_fill : CupertinoIcons.house,
                color: color,
                size: 22,
              ),
              onTap: () => _selectTab(0),
            ),
            _FlatNavTabItem(
              selected: _selectedIndex == 1,
              label: T.navSearch,
              ink: ink,
              sub: sub,
              isDark: isDark,
              iconBuilder: (active, color) => Icon(
                CupertinoIcons.search,
                color: color,
                size: 22,
              ),
              onTap: () => _selectTab(1),
            ),
            _FlatNavTabItem(
              selected: _selectedIndex == 2,
              label: T.navLibrary,
              ink: ink,
              sub: sub,
              isDark: isDark,
              iconBuilder: (active, color) => Icon(
                active
                    ? CupertinoIcons.music_albums_fill
                    : CupertinoIcons.music_albums,
                color: color,
                size: 22,
              ),
              onTap: () => _selectTab(2),
            ),
            _FlatNavTabItem(
              selected: _selectedIndex == 3,
              label: T.navYou,
              ink: ink,
              sub: sub,
              isDark: isDark,
              iconBuilder: (active, color) => Icon(
                active ? CupertinoIcons.person_fill : CupertinoIcons.person,
                color: color,
                size: 22,
              ),
              onTap: () => _selectTab(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatNavTabItem extends StatelessWidget {
  final bool selected;
  final String label;
  final Color ink;
  final Color sub;
  final bool isDark;
  final Widget Function(bool active, Color color) iconBuilder;
  final VoidCallback onTap;

  const _FlatNavTabItem({
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
            color: selected
                ? (isDark
                    ? Colors.white.withAlpha(24)
                    : Colors.black.withAlpha(14))
                : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconBuilder(selected, color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.8,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
