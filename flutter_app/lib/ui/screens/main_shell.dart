import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../services/device_permissions_service.dart';
import '../../state/dynamic_island_provider.dart';
import '../../state/library_provider.dart';
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
    final customAccentVal = settings.dynamicIslandAccentValue;
    final accent = customAccentVal != 0
        ? Color(customAccentVal)
        : ((settings.dynamicAlbumColors ? player.dynamicColor : null) ??
            const Color(0xFF5DA7E8));

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
            presetKey: settings.dynamicIslandPreset.key,
            islandScale: settings.dynamicIslandScale,
            islandYOffset: settings.dynamicIslandYOffset,
            showLyrics: settings.dynamicIslandShowLyrics,
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

  void _shuffleFromHome(AppStrings T) {
    final library = ref.read(libraryProvider);
    final homePool = ref.read(homePlayablePoolProvider);
    final seen = <String>{};
    final pool = <MusicItem>[];
    for (final item in [
      ...homePool,
      ...library.recentlyPlayed,
      ...library.likedSongs,
      ...library.top50Tracks,
    ]) {
      if (item.isPlayable && item.id.isNotEmpty && seen.add(item.id)) {
        pool.add(item);
      }
    }
    if (pool.isNotEmpty) {
      if (ref.read(settingsProvider).hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      ref.read(playerProvider.notifier).playShuffled(
            pool,
            contextName: T.navHome,
          );
    }
  }

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
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    final accent = dynamicAlbumColors ? dynamicColor : null;
    final glassAccent = accent ?? AppColors.horizonBlue;
    final showCompactInline = _navCollapsed;
    final showHomeFabs = _selectedIndex == 0;
    final fabBottom = showCompactInline
        ? bottomInset + (hasTrack ? 80.0 : 22.0)
        : bottomInset + (hasTrack ? 162.0 : 86.0);

    final pagesBody = RepaintBoundary(
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            TickerMode(enabled: _selectedIndex == 0, child: const HomeScreen()),
            TickerMode(enabled: _selectedIndex == 1, child: const SearchScreen()),
            TickerMode(enabled: _selectedIndex == 2, child: const LibraryScreen()),
            TickerMode(enabled: _selectedIndex == 3, child: const YouScreen()),
          ],
        ),
      ),
    );

    final overlayWidgets = <Widget>[
      // Floating Mic & Shuffle action buttons above the TabBar / MiniPlayer (Beranda)
      AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        right: showHomeFabs ? 16 : -72,
        bottom: fabBottom,
        child: IgnorePointer(
          ignoring: !showHomeFabs,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: showHomeFabs ? 1.0 : 0.0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              scale: showHomeFabs ? 1.0 : 0.82,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidGlassTap(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SongRecognitionScreen(),
                        ),
                      );
                    },
                    child: LiquidGlassSurface(
                      borderRadius: BorderRadius.circular(999),
                      blurSigma: isGlass ? 10 : 0,
                      useBackdropBlur: isGlass,
                      chromaticAccent: glassAccent,
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Center(
                          child: Icon(
                            CupertinoIcons.mic_fill,
                            color: ink,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LiquidGlassTap(
                    onTap: () => _shuffleFromHome(T),
                    child: LiquidGlassSurface(
                      borderRadius: BorderRadius.circular(999),
                      blurSigma: isGlass ? 10 : 0,
                      useBackdropBlur: isGlass,
                      chromaticAccent: glassAccent,
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Center(
                          child: Icon(
                            CupertinoIcons.shuffle,
                            color: ink,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

      // Collapsed state: left circular active-tab orb animated identically in Flat & Glass
      AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        left: showCompactInline ? 14 : -76,
        bottom: bottomInset + 12,
        child: IgnorePointer(
          ignoring: !showCompactInline,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: showCompactInline ? 1.0 : 0.0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              scale: showCompactInline ? 1.0 : 0.72,
              child: LiquidGlassTap(
                onTap: () => _setCollapsed(false),
                child: LiquidGlassSurface(
                  borderRadius: BorderRadius.circular(999),
                  blurSigma: isGlass ? 10 : 0,
                  useBackdropBlur: isGlass,
                  chromaticAccent: glassAccent,
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
        ),
      ),

      // Expanded 4-tab Navigation Capsule (identical smooth slide/fade animation in Flat & Glass)
      AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        left: 14,
        right: 14,
        bottom: bottomInset + (showCompactInline ? -88 : 10),
        child: IgnorePointer(
          ignoring: showCompactInline,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: showCompactInline ? 0.0 : 1.0,
            child: isGlass
                ? _buildLiquidGlassNavLayer(
                    T: T,
                    ink: ink,
                    sub: sub,
                    isDark: isDark,
                    accent: glassAccent,
                    glassOpacity: glassOpacity,
                  )
                : _buildFlatNavCapsule(
                    T: T,
                    ink: ink,
                    sub: sub,
                    isDark: isDark,
                  ),
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
    required AppStrings T,
    required Color ink,
    required Color sub,
    required bool isDark,
    required Color accent,
    required double glassOpacity,
  }) {
    final alignX = -1.0 + (_selectedIndex * (2.0 / 3.0));
    final pillFill = isDark
        ? Colors.white.withAlpha(ui.lerpDouble(30, 48, glassOpacity)!.round())
        : Colors.white.withAlpha(ui.lerpDouble(195, 232, glassOpacity)!.round());

    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(999),
      blurSigma: 12,
      useBackdropBlur: true,
      chromaticAccent: accent,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: SizedBox(
        height: 54,
        child: Stack(
          children: [
            // Smoothly sliding Liquid Glass selection indicator (matches reference screenshots)
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment(alignX, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.25,
                  heightFactor: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pillFill,
                        borderRadius: BorderRadius.circular(999),
                        gradient: !isDark
                            ? const RadialGradient(
                                center: Alignment(0, 0.25),
                                radius: 1.05,
                                colors: [
                                  Color(0x46FFE999),
                                  Color(0xDDFFFFFF),
                                ],
                              )
                            : null,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withAlpha(64)
                              : Colors.black.withAlpha(16),
                          width: 0.7,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 42 : 12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _FlatNavTabItem(
                  selected: _selectedIndex == 0,
                  label: T.navHome,
                  ink: ink,
                  sub: sub,
                  isDark: isDark,
                  showTileBg: false,
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
                  showTileBg: false,
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
                  showTileBg: false,
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
                  showTileBg: false,
                  iconBuilder: (active, color) => Icon(
                    active ? CupertinoIcons.person_fill : CupertinoIcons.person,
                    color: color,
                    size: 22,
                  ),
                  onTap: () => _selectTab(3),
                ),
              ],
            ),
          ],
        ),
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
  final bool showTileBg;
  final Widget Function(bool active, Color color) iconBuilder;
  final VoidCallback onTap;

  const _FlatNavTabItem({
    required this.selected,
    required this.label,
    required this.ink,
    required this.sub,
    required this.isDark,
    this.showTileBg = true,
    required this.iconBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final color = selected ? activeColor : sub;
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
            color: (showTileBg && selected)
                ? (isDark
                    ? Colors.white.withAlpha(24)
                    : AppColors.lightTextPrimary.withAlpha(14))
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
