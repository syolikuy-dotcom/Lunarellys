import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/ios_control_center.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/media_card.dart';
import '../widgets/track_tile.dart';
import 'detail_screens.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _speedDialPageCtrl = PageController();
  final PageController _quickPicksPageCtrl = PageController(viewportFraction: 0.90);

  List<MusicSection> _sections = const [];
  List<MusicMood> _moods = const [];
  String? _selectedMoodName;
  bool _loading = true;
  bool _loadingMood = false;
  String? _error;
  int _speedDialPage = 0;
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    final hasCache = _restoreCachedHome();
    if (hasCache) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishPlayablePool();
      });
    }
    unawaited(_loadData(silent: hasCache));
  }

  void _publishPlayablePool() {
    ref.read(homePlayablePoolProvider.notifier).state = _collectAllPlayable();
  }

  bool _restoreCachedHome() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final rawSec = prefs.getString('cached_home_sections_v2');
      final rawMoods = prefs.getString('cached_home_moods_v2');
      if (rawSec == null || rawSec.isEmpty) return false;
      final decodedSec = jsonDecode(rawSec);
      if (decodedSec is! List) return false;
      final secs = decodedSec
          .whereType<Map>()
          .map((m) => MusicSection.fromJson(Map<String, dynamic>.from(m)))
          .where((s) => s.items.isNotEmpty)
          .toList();
      if (secs.isEmpty) return false;
      var moods = const <MusicMood>[];
      if (rawMoods != null && rawMoods.isNotEmpty) {
        final decodedMoods = jsonDecode(rawMoods);
        if (decodedMoods is List) {
          moods = decodedMoods
              .whereType<Map>()
              .map((m) => MusicMood.fromJson(Map<String, dynamic>.from(m)))
              .where((m) => m.name.isNotEmpty)
              .toList();
        }
      }
      _sections = secs;
      _moods = moods;
      _loading = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _saveCachedHome(List<MusicSection> secs, List<MusicMood> moods) {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (secs.isNotEmpty) {
        prefs.setString(
          'cached_home_sections_v2',
          jsonEncode(secs.take(12).map((s) => s.toJson()).toList()),
        );
      }
      if (moods.isNotEmpty) {
        prefs.setString(
          'cached_home_moods_v2',
          jsonEncode(moods.take(24).map((m) => m.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollOffset.dispose();
    _speedDialPageCtrl.dispose();
    _quickPicksPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent || _sections.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
        _selectedMoodName = null;
      });
    } else {
      setState(() {
        _error = null;
        _selectedMoodName = null;
      });
    }

    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait<dynamic>([
        api.getHome(),
        api.getMoods().catchError((_) => const <MusicMood>[]),
      ]);
      if (!mounted) return;
      final secs = results[0] as List<MusicSection>;
      final moods = results[1] as List<MusicMood>;
      setState(() {
        if (secs.isNotEmpty) _sections = secs;
        if (moods.isNotEmpty) _moods = moods;
        _loading = false;
      });
      _publishPlayablePool();
      _saveCachedHome(secs, moods);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        if (_sections.isEmpty) _error = err.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectMood(MusicMood? mood) async {
    if (mood == null || mood.name == _selectedMoodName) {
      await _loadData();
      return;
    }
    setState(() {
      _selectedMoodName = mood.name;
      _loadingMood = true;
    });
    try {
      final secs = await ref.read(apiClientProvider).getMoodPlaylists(mood.browseId, mood.params);
      if (!mounted) return;
      setState(() {
        if (secs.isNotEmpty) _sections = secs;
        _loadingMood = false;
      });
      _publishPlayablePool();
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMood = false);
      }
    }
  }

  List<MusicItem> _collectAllPlayable() {
    final seen = <String>{};
    final out = <MusicItem>[];
    for (final s in _sections) {
      for (final item in s.items) {
        if (item.isPlayable && item.id.isNotEmpty && seen.add(item.id)) {
          out.add(item);
        }
      }
    }
    for (final r in ref.read(libraryProvider).recentlyPlayed) {
      if (r.isPlayable && seen.add(r.id)) out.add(r);
    }
    return out;
  }

  void _openItem(MusicItem item, List<MusicItem> queue, String contextLabel) {
    HapticFeedback.selectionClick();
    if (item.type == 'artist') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ArtistScreen(artistId: item.id)),
      );
    } else if (item.type == 'album' || item.type == 'single' || item.type == 'ep') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AlbumScreen(albumId: item.id)),
      );
    } else if (item.type == 'playlist') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlistId: item.id)),
      );
    } else {
      ref.read(playerProvider.notifier).playTrack(
            item,
            queue: queue.where((e) => e.isPlayable).toList(),
            contextName: contextLabel,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );
    final showStreakOnHome = ref.watch(
      settingsProvider.select((s) => s.showStreakOnHome),
    );
    final library = ref.watch(libraryProvider);
    final hasTrack = ref.watch(playerProvider.select((s) => s.currentTrack != null));
    final islandEnabled = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandEnabled),
    );
    final islandAlways = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandAlwaysVisible),
    );
    final islandPosition = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandPosition),
    );
    final islandShown = islandEnabled && (islandAlways || hasTrack);
    final islandClearance =
        islandShown ? (islandPosition == 'notch' ? 8.0 : 42.0) : 0.0;
    final isGlass = ref.watch(
      settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
    );
    final T = AppStrings.of(appLanguage);
    final greeting = T.greeting(DateTime.now().hour);
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final pill = AppColors.pillOf(context);
    final topPad = MediaQuery.of(context).padding.top;

    final allTracks = _collectAllPlayable();

    // 2x3 Compact Quick-Resume Grid right below greeting (up to 6 tracks)
    final compactResumeItems = <MusicItem>[];
    final resumeSeen = <String>{};
    for (final item in [
      ...library.recentlyPlayed,
      ...library.likedSongs,
      ...allTracks,
    ]) {
      if (item.id.isNotEmpty && resumeSeen.add(item.id)) {
        compactResumeItems.add(item);
      }
      if (compactResumeItems.length >= 6) break;
    }

    // Speed Dial 3x3 (up to 27 items -> 3 pages)
    final speedDialPool = <MusicItem>[];
    final seenIds = <String>{};
    for (final p in [
      ...library.pinnedSpeedDialItems,
      ...library.recentlyPlayed,
      ...library.likedSongs,
      for (final s in _sections) ...s.items,
    ]) {
      if (p.id.isNotEmpty && seenIds.add(p.id)) {
        speedDialPool.add(p);
      }
      if (speedDialPool.length >= 27) break;
    }

    // Quick Picks 4-row vertical paged columns
    final quickPickTracks = allTracks.take(24).toList();

    // Editorial tall spotlight cards (albums/playlists from sections)
    final editorialCards = <MusicItem>[];
    for (final s in _sections) {
      for (final item in s.items) {
        if (!item.isPlayable && item.type != 'artist') {
          editorialCards.add(item);
        }
      }
    }

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical) {
              _scrollOffset.value = n.metrics.pixels;
            }
            return false;
          },
          child: RefreshIndicator(
            color: ink,
            onRefresh: _loadData,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                0,
                topPad + 14 + islandClearance,
                0,
                MediaQuery.of(context).padding.bottom + 210,
              ),
              children: [
                // Clean full-width Greeting header + Control Center quick button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      LiquidGlassTap(
                        onTap: () => showIosControlCenter(
                          context,
                          ref,
                          onOpenEqualizer: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const EqualizerScreen(),
                            ),
                          ),
                        ),
                        child: LiquidGlassCapsule(
                          blurSigma: 0,
                          padding: const EdgeInsets.all(9),
                          child: Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 18,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2x3 Compact Quick-Resume Grid
                if (!_loading && compactResumeItems.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: compactResumeItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 58,
                      ),
                      itemBuilder: (context, idx) {
                        final item = compactResumeItems[idx];
                        return _CompactResumeTile(
                          item: item,
                          onTap: () => _openItem(item, compactResumeItems, T.navHome),
                          onLongPress: () {
                            if (item.isPlayable) {
                              showTrackOptionsSheet(context, ref, item);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Percikan Streak Banner Card
                if (!_loading && showStreakOnHome) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PercikanBannerCard(
                      streakDays: library.currentStreak,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const StatsRecapScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Mood pill chips
                SizedBox(
                  height: 40,
                  child: _loading && _moods.isEmpty
                      ? ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: 5,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => _shimmerBox(
                            context,
                            width: 78 + (i % 3) * 20,
                            height: 36,
                            radius: 999,
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _moods.length.clamp(0, 12),
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final mood = _moods[index];
                            final selected = _selectedMoodName == mood.name;
                            return LiquidGlassTap(
                              onTap: () => _selectMood(mood),
                              pressedScale: 0.94,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected ? ink : pill,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Center(
                                  child: Text(
                                    mood.name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                      color: selected
                                          ? (isDark ? Colors.black : Colors.white)
                                          : ink,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),

                if (_loading)
                  _buildLoadingSkeleton(context)
                else if (_error != null && _sections.isEmpty)
                  _buildErrorState(context)
                else ...[
                  if (_loadingMood)
                    const LinearProgressIndicator(minHeight: 2),

                  // 1. ANDALANMU (3x3 Speed Dial Grid)
                  if (speedDialPool.isNotEmpty) ...[
                    InkWell(
                      onTap: () => _showSectionBrowseSheet(
                        context,
                        T.speedDial,
                        speedDialPool,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                T.speedDial,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(CupertinoIcons.chevron_forward, color: sub, size: 20),
                          ],
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: _buildSpeedDialPager(context, speedDialPool),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 2. PILIHAN CEPAT (4-row paged track columns)
                  if (quickPickTracks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              T.quickPicks,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              ref.read(playerProvider.notifier).playTrack(
                                    quickPickTracks.first,
                                    queue: quickPickTracks,
                                    contextName: T.quickPicks,
                                  );
                            },
                            child: Text(
                              T.playAll,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sub,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RepaintBoundary(
                      child: _buildQuickPicksPager(context, quickPickTracks, T.quickPicks),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 3. EDITORIAL TALL FEATURED CARDS (2-up spotlight)
                  if (editorialCards.length >= 2) ...[
                    _buildEditorialSpotlight(context, editorialCards.take(6).toList()),
                    const SizedBox(height: 24),
                  ],

                  // 4. REMAINING SECTIONS (with optional mood-style eyebrow subtitles)
                  ..._sections.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final sec = entry.value;
                    if (sec.items.isEmpty) return const SizedBox.shrink();

                    final allPlayableSec = sec.items.where((e) => e.isPlayable).toList();
                    if (idx.isOdd && allPlayableSec.length >= 4) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _showSectionBrowseSheet(
                                context,
                                sec.title,
                                allPlayableSec,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sec.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.headlineMedium,
                                      ),
                                    ),
                                    Icon(CupertinoIcons.chevron_forward, color: sub, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            _buildQuickPicksPager(context, allPlayableSec, sec.title),
                          ],
                        ),
                      );
                    }

                    final isTrendingCommunity =
                        sec.title.toLowerCase().contains('komunitas') ||
                        sec.title.toLowerCase().contains('community') ||
                        idx == 2;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _showSectionBrowseSheet(
                              context,
                              sec.title,
                              sec.items,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (sec.title.toLowerCase().contains('hujan') ||
                                      sec.title.toLowerCase().contains('mendung') ||
                                      idx == 3)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        'LAGU-LAGU UNTUK HARI YANG MENDUNG',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                          color: sub,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          sec.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.headlineMedium,
                                        ),
                                      ),
                                      Icon(CupertinoIcons.chevron_forward, color: sub, size: 20),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            height: isTrendingCommunity ? 210 : 204,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: sec.items.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (context, itemIdx) {
                                final item = sec.items[itemIdx];
                                if (isTrendingCommunity && itemIdx < sec.items.length) {
                                  return MediaCard(
                                    item: item,
                                    contextQueue: allPlayableSec,
                                    width: 148,
                                    contextLabel: sec.title,
                                  );
                                }
                                return MediaCard(
                                  item: item,
                                  contextQueue: allPlayableSec,
                                  width: 142,
                                  contextLabel: sec.title,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // 5. SUASANA DAN GENRE (2-column grid)
                  if (_moods.isNotEmpty) ...[
                    InkWell(
                      onTap: () => _showAllMoodsSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                T.moodAndGenres,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(CupertinoIcons.chevron_forward, color: sub, size: 20),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _moods.length.clamp(0, 10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.35,
                        ),
                        itemBuilder: (context, index) {
                          final mood = _moods[index];
                          return LiquidGlassTap(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MoodPlaylistsScreen(mood: mood),
                              ),
                            ),
                            child: LiquidGlassCard(
                              radius: 16,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  mood.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),

        // Sticky Liquid Glass "Beranda" top header on scroll (zero setState lag)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _scrollOffset,
            builder: (context, offset, child) {
              final stickyOpacity = ((offset - 32) / 36).clamp(0.0, 1.0);
              if (stickyOpacity <= 0.02) return const SizedBox.shrink();
              return IgnorePointer(
                ignoring: stickyOpacity < 0.2,
                child: Opacity(
                  opacity: stickyOpacity,
                  child: child,
                ),
              );
            },
            child: isGlass
                ? ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 6,
                        sigmaY: 6,
                        tileMode: TileMode.clamp,
                      ),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          topPad + (islandShown ? 44 : 10),
                          16,
                          12,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? const Color(0xFF0E1218)
                                  : const Color(0xFFF6F7FB))
                              .withAlpha(isDark ? 152 : 176),
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.borderOf(context).withAlpha(110),
                              width: 0.6,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                T.navHome,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: ink,
                                ),
                              ),
                            ),
                            LiquidGlassTap(
                              onTap: () => showIosControlCenter(
                                context,
                                ref,
                                onOpenEqualizer: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const EqualizerScreen(),
                                  ),
                                ),
                              ),
                              child: Icon(
                                CupertinoIcons.slider_horizontal_3,
                                size: 21,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topPad + (islandShown ? 44 : 10),
                      16,
                      12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.borderOf(context),
                          width: 0.7,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            T.navHome,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: ink,
                            ),
                          ),
                        ),
                        LiquidGlassTap(
                          onTap: () => showIosControlCenter(
                            context,
                            ref,
                            onOpenEqualizer: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const EqualizerScreen(),
                              ),
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 21,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialPager(BuildContext context, List<MusicItem> items) {
    final pageCount = ((items.length + 8) ~/ 9).clamp(1, 3);
    final width = MediaQuery.of(context).size.width;
    final tileW = (width - 32 - 20) / 3;
    final cellH = tileW / 0.78;
    final gridHeight = cellH * 3 + 22;
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final currentId = ref.watch(playerProvider.select((s) => s.currentTrack?.id));
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final accent =
        ref.watch(playerProvider.select((s) => s.dynamicColor)) ?? AppColors.horizonBlue;

    return Column(
      children: [
        SizedBox(
          height: gridHeight,
          child: PageView.builder(
            controller: _speedDialPageCtrl,
            itemCount: pageCount,
            onPageChanged: (p) => setState(() => _speedDialPage = p),
            itemBuilder: (context, pageIdx) {
              final start = pageIdx * 9;
              final end = (start + 9).clamp(0, items.length);
              final pageItems = items.sublist(start, end);

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: pageItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, i) {
                  final item = pageItems[i];
                  final isCurrent = currentId != null && item.id == currentId;
                  return LiquidGlassTap(
                    onTap: () => _openItem(item, items, 'Andalanmu'),
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      if (item.isPlayable) {
                        showTrackOptionsSheet(context, ref, item);
                      } else {
                        ref.read(libraryProvider.notifier).togglePinSpeedDial(item);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                LayoutBuilder(
                                  builder: (ctx, c) => ArtworkImage(
                                    url: item.bestThumbUrl(size: 320),
                                    width: c.maxWidth,
                                    height: c.maxHeight,
                                    size: c.maxWidth,
                                    radius: 14,
                                    isCircle: item.type == 'artist',
                                    preserveFull: item.type != 'artist',
                                  ),
                                ),
                                if (isCurrent)
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: MiniSpinningVinyl(
                                      artworkUrl: item.bestThumbUrl(size: 140),
                                      size: 28,
                                      isPlaying: isPlaying,
                                      accentColor: accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                            color: isCurrent
                                ? AppColors.readableAccent(
                                    accent,
                                    Theme.of(context).brightness,
                                  )
                                : ink,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (pageCount > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (i) {
              final active = i == _speedDialPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? ink : sub.withAlpha(80),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickPicksPager(
    BuildContext context,
    List<MusicItem> tracks,
    String contextLabel,
  ) {
    final columnCount = ((tracks.length + 3) ~/ 4).clamp(1, 8);
    return SizedBox(
      height: 266,
      child: PageView.builder(
        controller: _quickPicksPageCtrl,
        padEnds: false,
        itemCount: columnCount,
        itemBuilder: (context, colIdx) {
          final start = colIdx * 4;
          final end = (start + 4).clamp(0, tracks.length);
          final colTracks = tracks.sublist(start, end);
          return Padding(
            padding: EdgeInsets.only(
              left: colIdx == 0 ? 12 : 4,
              right: 8,
            ),
            child: Column(
              children: colTracks
                  .map(
                    (t) => TrackTile(
                      track: t,
                      queue: tracks,
                      compact: true,
                      onTapOverride: () {
                        HapticFeedback.selectionClick();
                        ref.read(playerProvider.notifier).playTrack(
                              t,
                              queue: tracks,
                              contextName: contextLabel,
                            );
                      },
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorialSpotlight(BuildContext context, List<MusicItem> cards) {
    return SizedBox(
      height: 238,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = cards[i];
          return LiquidGlassTap(
            onTap: () => _openItem(item, const [], item.title),
            child: SizedBox(
              width: 184,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ArtworkImage(
                      url: item.bestThumbUrl(size: 500),
                      width: 184,
                      height: 238,
                      size: 238,
                      radius: 18,
                      preserveFull: true,
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(115),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 26, 12, 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xA6000000),
                              Color(0xD9000000),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            if (item.subtitle.isNotEmpty || item.artistDisplay.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.subtitle.isNotEmpty ? item.subtitle : item.artistDisplay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shimmerBox(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 14,
  }) {
    final isDark = AppColors.isDark(context);
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1D222B) : const Color(0xFFE7E9EE),
      highlightColor: isDark ? const Color(0xFF2B313D) : const Color(0xFFF6F7FA),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tileW = (width - 32 - 20) / 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(context, width: 130, height: 26, radius: 8),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 14,
            children: List.generate(
              9,
              (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(context, width: tileW, height: tileW, radius: 14),
                  const SizedBox(height: 6),
                  _shimmerBox(context, width: tileW * 0.72, height: 11, radius: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          _shimmerBox(context, width: 150, height: 24, radius: 8),
          const SizedBox(height: 12),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _shimmerBox(context, width: 50, height: 50, radius: 8),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBox(context, width: 180, height: 13, radius: 4),
                      const SizedBox(height: 6),
                      _shimmerBox(context, width: 110, height: 11, radius: 4),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 46, color: AppColors.subOf(context)),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Gagal memuat beranda',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat ulang'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionBrowseSheet(
    BuildContext context,
    String title,
    List<MusicItem> items,
  ) {
    final ink = AppColors.inkOf(context);
    final playable = items.where((e) => e.isPlayable).toList();
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
                  ),
                ),
                if (playable.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(playerProvider.notifier).playTrack(
                            playable.first,
                            queue: playable,
                            contextName: title,
                          );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Putar Semua'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 20),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                if (item.isPlayable) {
                  return TrackTile(track: item, queue: playable);
                }
                return ListTile(
                  leading: ArtworkImage(
                    url: item.bestThumbUrl(size: 160),
                    size: 48,
                    radius: 10,
                    isCircle: item.type == 'artist',
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    item.subtitle.isNotEmpty ? item.subtitle : item.artistDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openItem(item, playable, title);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAllMoodsSheet(BuildContext context) {
    final ink = AppColors.inkOf(context);
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Row(
              children: [
                Text(
                  'Semua Suasana & Genre',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              itemCount: _moods.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
              ),
              itemBuilder: (_, i) {
                final m = _moods[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MoodPlaylistsScreen(mood: m),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.pillOf(ctx),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactResumeTile extends StatelessWidget {
  final MusicItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CompactResumeTile({
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);

    return LiquidGlassTap(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.96,
      child: LiquidGlassCard(
        radius: 15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Row(
            children: [
              ArtworkImage(
                url: item.bestThumbUrl(size: 160),
                size: 58,
                radius: 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.18,
                      color: ink,
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
