import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/animated_eq.dart';
import '../widgets/artwork_image.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/lunarellys_logo.dart';
import '../widgets/track_tile.dart';
import 'detail_screens.dart';
import 'main_shell.dart';
import 'you_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  // 0 = YouTube, 1 = Perangkat
  int _sourceTab = 0;

  // YouTube sub-filters matching screenshots + backend MUSIC_FILTERS
  static const List<(String apiFilter, String label)> _ytFilters = [
    ('all', 'Semua'),
    ('songs', 'Lagu'),
    ('videos', 'Video'),
    ('albums', 'Album'),
    ('artists', 'Artis'),
    ('community_playlists', 'Playlist komunitas'),
    ('featured_playlists', 'Playlist pilihan'),
  ];
  String _selectedYtFilter = 'all';

  // Perangkat sub-filters
  static const List<String> _deviceFilters = [
    'Semua',
    'Lagu',
    'Album',
    'Artis',
    'Playlist',
  ];
  int _selectedDeviceFilter = 0;

  List<String> _suggestions = const [];
  MusicItem? _topResult;
  List<MusicItem> _results = const [];
  String? _continuation;
  bool _searching = false;
  bool _loadingMore = false;
  bool _hasSearched = false;
  String? _error;

  static const List<(String label, String query)> _browseGenres = [
    ('Pop', 'Pop Indonesia Hits'),
    ('Dangdut', 'Dangdut Koplo Hits'),
    ('Hip Hop', 'Hip Hop Rap Hits'),
    ('Rock', 'Rock Alternatif Indonesia'),
    ('Indie', 'Indie Pop Indonesia'),
    ('Santai', 'Musik Santai Sore'),
    ('Semangat', 'Lagu Semangat Olahraga'),
    ('Galau', 'Lagu Galau Populer'),
    ('Akustik', 'Akustik Santai Indonesia'),
    ('K-Pop', 'K-Pop Top Hits'),
    ('Jazz', 'Jazz Populer Indonesia'),
    ('Koplo', 'Koplo Terbaru'),
    ('Fokus', 'Musik Fokus Instrumental'),
    ('Tidur', 'Musik Pengantar Tidur'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _suggestions = const [];
        _topResult = null;
        _results = const [];
        _continuation = null;
        _hasSearched = false;
        _error = null;
      });
      return;
    }
    if (_sourceTab == 1) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final list = await ref.read(apiClientProvider).getSuggestions(q);
        if (mounted && _controller.text.trim() == q) {
          setState(() => _suggestions = list);
        }
      } catch (_) {}
    });
  }

  Future<void> _executeSearch(String query, {String? filterOverride}) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _focusNode.unfocus();
    final filter = filterOverride ?? _selectedYtFilter;
    _controller.text = clean;
    _controller.selection = TextSelection.collapsed(offset: clean.length);

    if (_sourceTab == 1) {
      setState(() {});
      return;
    }

    unawaited(ref.read(libraryProvider.notifier).addSearchHistory(clean));

    setState(() {
      _searching = true;
      _hasSearched = true;
      _error = null;
      _suggestions = const [];
    });

    try {
      final res = await ref.read(apiClientProvider).search(clean, filter: filter);
      if (!mounted) return;
      setState(() {
        _topResult = res.topResult;
        _results = res.results;
        _continuation = res.continuation;
        _searching = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _searching = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _continuation == null) return;
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(apiClientProvider).search(
            q,
            filter: _selectedYtFilter,
            continuation: _continuation,
          );
      if (!mounted) return;
      setState(() {
        _results = [..._results, ...res.results];
        _continuation = res.continuation;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openItem(MusicItem item, {List<MusicItem>? customQueue}) {
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
      final q = customQueue ?? _results.where((e) => e.isPlayable).toList();
      ref.read(playerProvider.notifier).playTrack(
            item,
            queue: q.isEmpty ? [item] : q,
            contextName: 'Pencarian',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );
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
    final navCollapsed = ref.watch(navCollapsedProvider);
    final T = AppStrings.of(appLanguage);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final card = AppColors.cardOf(context);
    final query = _controller.text.trim();

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12 + islandClearance, 16, 10),
                child: Column(
                  children: [
                    LiquidGlassCapsule(
                      blurSigma: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(CupertinoIcons.chevron_back, color: ink, size: 20),
                            onPressed: () {
                              if (query.isNotEmpty || _hasSearched) {
                                _controller.clear();
                                _onQueryChanged('');
                              } else {
                                _focusNode.unfocus();
                              }
                            },
                          ),
                          if (!_hasSearched && query.isEmpty) ...[
                            Icon(CupertinoIcons.search, color: sub, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              textInputAction: TextInputAction.search,
                              onChanged: _onQueryChanged,
                              onSubmitted: _executeSearch,
                              style: TextStyle(fontSize: 15, color: ink),
                              decoration: InputDecoration(
                                hintText: _sourceTab == 0 ? T.searchHint : T.searchLocalHint,
                                hintStyle: TextStyle(color: sub, fontSize: 15),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (query.isNotEmpty)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(CupertinoIcons.xmark_circle_fill, color: sub, size: 19),
                              onPressed: () {
                                _controller.clear();
                                _onQueryChanged('');
                              },
                            )
                          else
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(CupertinoIcons.mic_fill, color: ink, size: 20),
                              tooltip: T.recognizeSong,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SongRecognitionScreen(),
                                  ),
                                );
                              },
                            ),
                        ],
                        ),
                      ),
                    ),
                    if (!_hasSearched) ...[
                      const SizedBox(height: 10),
                      LiquidGlassCapsule(
                        blurSigma: 0,
                        padding: const EdgeInsets.all(4),
                        child: SizedBox(
                          height: 36,
                          child: Row(
                            children: [
                              _segmentButton(
                                label: 'YouTube',
                                selected: _sourceTab == 0,
                                card: card,
                                ink: ink,
                                sub: sub,
                                onTap: () => setState(() => _sourceTab = 0),
                              ),
                              _segmentButton(
                                label: 'Perangkat',
                                selected: _sourceTab == 1,
                                card: card,
                                ink: ink,
                                sub: sub,
                                onTap: () => setState(() => _sourceTab = 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _sourceTab == 1
                    ? _buildDeviceSearchView(context)
                    : _buildYoutubeBody(context, T),
              ),
            ],
          ),

          // Floating Mic button above MiniPlayer when viewing search results
          if (_hasSearched && _sourceTab == 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom +
                  (navCollapsed ? (hasTrack ? 86 : 84) : (hasTrack ? 156 : 92)),
              child: LiquidGlassTap(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SongRecognitionScreen(),
                  ),
                ),
                child: LiquidGlassSurface(
                  borderRadius: BorderRadius.circular(999),
                  blurSigma: 28,
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(CupertinoIcons.mic_fill, color: ink, size: 21),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _segmentButton({
    required String label,
    required bool selected,
    required Color card,
    required Color ink,
    required Color sub,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? card : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? ink : sub,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYoutubeBody(BuildContext context, AppStrings T) {
    final library = ref.watch(libraryProvider);
    final query = _controller.text.trim();
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    if (!_hasSearched && query.isEmpty) {
      final recent = library.recentlyPlayed;
      final mostPlayed = library.top50Tracks.take(8).toList();

      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 170),
        children: [
          // Clean history rows matching screenshot
          if (library.searchHistory.isNotEmpty) ...[
            ...library.searchHistory.take(5).map((item) {
              return InkWell(
                onTap: () => _executeSearch(item),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 9, 10, 9),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: sub, size: 21),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15.5, color: ink),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close_rounded, color: sub, size: 19),
                        onPressed: () =>
                            ref.read(libraryProvider.notifier).removeSearchHistory(item),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.north_west_rounded, color: sub, size: 19),
                        onPressed: () {
                          _controller.text = item;
                          _controller.selection =
                              TextSelection.collapsed(offset: item.length);
                          _onQueryChanged(item);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // Terakhir diputar horizontal cards
          if (recent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Terakhir diputar',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            SizedBox(
              height: 192,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recent.length.clamp(0, 12),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final track = recent[idx];
                  return LiquidGlassTap(
                    onTap: () => _openItem(track, customQueue: recent),
                    child: SizedBox(
                      width: 142,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ArtworkImage(
                            url: track.bestThumbUrl(size: 320),
                            size: 142,
                            radius: 14,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          Text(
                            track.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: sub),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Paling sering diputar numbered list
          if (mostPlayed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'Paling sering diputar',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            ...mostPlayed.asMap().entries.map((entry) {
              final idx = entry.key;
              final track = entry.value;
              return LiquidGlassTap(
                onTap: () => _openItem(track, customQueue: mostPlayed),
                onLongPress: () => showTrackOptionsSheet(context, ref, track),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: sub,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ArtworkImage(
                        url: track.bestThumbUrl(size: 160),
                        size: 52,
                        radius: 10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            Text(
                              track.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.5, color: sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 18),
          ],

          // Jelajahi semua 2-column grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(T.browseAll, style: Theme.of(context).textTheme.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _browseGenres.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.15,
              ),
              itemBuilder: (context, index) {
                final (label, genreQuery) = _browseGenres[index];
                return _buildGenreTile(label, genreQuery);
              },
            ),
          ),
        ],
      );
    }

    if (query.isNotEmpty && !_hasSearched && _suggestions.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 150),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final s = _suggestions[i];
          return ListTile(
            leading: Icon(Icons.search_rounded, color: sub),
            title: Text(s, style: TextStyle(color: ink, fontWeight: FontWeight.w500)),
            trailing: IconButton(
              icon: Icon(Icons.north_west_rounded, size: 18, color: sub),
              onPressed: () {
                _controller.text = s;
                _controller.selection = TextSelection.collapsed(offset: s.length);
                _onQueryChanged(s);
              },
            ),
            onTap: () => _executeSearch(s),
          );
        },
      );
    }

    // Group results nicely when on 'all' filter (matching 16-22-18-00)
    final tracksGroup = _results.where((e) => e.isPlayable).toList();
    final albumsGroup = _results
        .where((e) => e.type == 'album' || e.type == 'single' || e.type == 'ep')
        .toList();
    final artistsGroup = _results.where((e) => e.type == 'artist').toList();
    final playlistsGroup = _results.where((e) => e.type == 'playlist').toList();

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _ytFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final (filterKey, filterLabel) = _ytFilters[index];
              final selected = _selectedYtFilter == filterKey;
              return ChoiceChip(
                label: Text(filterLabel),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedYtFilter = filterKey);
                  if (_controller.text.trim().isNotEmpty) {
                    _executeSearch(_controller.text, filterOverride: filterKey);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _searching
              ? Center(child: CircularProgressIndicator(color: ink))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => _executeSearch(_controller.text),
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _results.isEmpty && _topResult == null
                      ? const Center(child: Text('Tidak ada hasil ditemukan.'))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 170),
                          children: [
                            if (_topResult != null) ...[
                              Text(T.topResult,
                                  style: Theme.of(context).textTheme.headlineMedium),
                              const SizedBox(height: 8),
                              _buildTopResultRow(_topResult!),
                              const SizedBox(height: 20),
                            ],
                            if (_selectedYtFilter == 'all') ...[
                              if (tracksGroup.isNotEmpty) ...[
                                Text('Lagu',
                                    style: Theme.of(context).textTheme.headlineMedium),
                                const SizedBox(height: 6),
                                ...tracksGroup.map(
                                  (t) => TrackTile(track: t, queue: tracksGroup),
                                ),
                                const SizedBox(height: 18),
                              ],
                              if (albumsGroup.isNotEmpty) ...[
                                Text('Album',
                                    style: Theme.of(context).textTheme.headlineMedium),
                                const SizedBox(height: 6),
                                ...albumsGroup.map((item) => _resultEntityRow(item)),
                                const SizedBox(height: 18),
                              ],
                              if (artistsGroup.isNotEmpty) ...[
                                Text('Artis',
                                    style: Theme.of(context).textTheme.headlineMedium),
                                const SizedBox(height: 6),
                                ...artistsGroup.map((item) => _resultEntityRow(item)),
                                const SizedBox(height: 18),
                              ],
                              if (playlistsGroup.isNotEmpty) ...[
                                Text('Playlist',
                                    style: Theme.of(context).textTheme.headlineMedium),
                                const SizedBox(height: 6),
                                ...playlistsGroup.map((item) => _resultEntityRow(item)),
                              ],
                            ] else ...[
                              ..._results.map((item) {
                                if (item.isPlayable) {
                                  return TrackTile(
                                    track: item,
                                    queue: _results.where((e) => e.isPlayable).toList(),
                                  );
                                }
                                return _resultEntityRow(item);
                              }),
                            ],
                            if (_continuation != null) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: OutlinedButton(
                                  onPressed: _loadingMore ? null : _loadMore,
                                  child: _loadingMore
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Muat lebih banyak'),
                                ),
                              ),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }

  Widget _resultEntityRow(MusicItem item) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      leading: ArtworkImage(
        url: item.bestThumbUrl(size: 160),
        size: 52,
        radius: 10,
        isCircle: item.type == 'artist',
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      subtitle: item.type == 'artist' && item.subtitle.isEmpty
          ? null
          : Text(
              [
                if (item.artistDisplay.isNotEmpty) item.artistDisplay,
                if (item.subtitle.isNotEmpty) item.subtitle,
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: sub),
            ),
      trailing: IconButton(
        icon: Icon(Icons.more_vert_rounded, color: sub, size: 20),
        onPressed: () {
          if (item.type == 'artist') {
            ref.read(libraryProvider.notifier).toggleFollowArtist(item);
          } else if (item.type == 'playlist') {
            ref.read(libraryProvider.notifier).toggleSavePlaylist(item);
          } else {
            ref.read(libraryProvider.notifier).toggleSaveAlbum(item);
          }
        },
      ),
      onTap: () => _openItem(item),
    );
  }

  Widget _buildTopResultRow(MusicItem item) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final isCurrent = ref.watch(
      playerProvider.select((s) => s.currentTrack?.id == item.id),
    );
    final isPlayingNow = ref.watch(
      playerProvider.select((s) => s.currentTrack?.id == item.id && s.isPlaying),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openItem(item),
      onLongPress: item.isPlayable ? () => showTrackOptionsSheet(context, ref, item) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ArtworkImage(
                  url: item.bestThumbUrl(size: 200),
                  size: 56,
                  radius: 10,
                  isCircle: item.type == 'artist',
                ),
                if (isCurrent)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(235),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AnimatedEqualizer(
                        color: Colors.black,
                        isPlaying: isPlayingNow,
                        size: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      item.artistDisplay,
                      if (item.duration != null) item.duration!,
                    ].where((e) => e.isNotEmpty).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: sub),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: ink, size: 20),
              onPressed: () {
                if (item.isPlayable) {
                  showTrackOptionsSheet(context, ref, item);
                } else {
                  _openItem(item);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSearchView(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final query = _controller.text.trim().toLowerCase();
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    final allSongs = <MusicItem>{
      ...library.downloadedTracks,
      ...library.likedSongs,
      ...library.recentlyPlayed,
    }.toList();

    bool matches(String text) => query.isEmpty || text.toLowerCase().contains(query);

    final songs =
        allSongs.where((t) => matches('${t.title} ${t.artistDisplay}')).toList();
    final albums = library.savedAlbums
        .where((a) => matches('${a.title} ${a.artistDisplay}'))
        .toList();
    final artists =
        library.followedArtists.where((a) => matches(a.title)).toList();
    final playlists =
        library.playlists.where((p) => matches(p.name)).toList();

    final showEmptyPrompt = query.isEmpty &&
        allSongs.isEmpty &&
        albums.isEmpty &&
        artists.isEmpty &&
        playlists.isEmpty;

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _deviceFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return ChoiceChip(
                label: Text(_deviceFilters[index]),
                selected: _selectedDeviceFilter == index,
                onSelected: (_) => setState(() => _selectedDeviceFilter = index),
              );
            },
          ),
        ),
        Expanded(
          child: query.isEmpty || showEmptyPrompt
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LunarellysHorizonLogo(
                          size: 62,
                          color: sub.withAlpha(110),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ketik untuk mencari lagu di perangkat',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14.5, color: sub),
                        ),
                        const SizedBox(height: 70),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
                  children: [
                    if ((_selectedDeviceFilter == 0 || _selectedDeviceFilter == 1) &&
                        songs.isNotEmpty) ...[
                      Text('Lagu', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      ...songs.map((t) => TrackTile(track: t, queue: songs)),
                      const SizedBox(height: 14),
                    ],
                    if ((_selectedDeviceFilter == 0 || _selectedDeviceFilter == 2) &&
                        albums.isNotEmpty) ...[
                      Text('Album', style: Theme.of(context).textTheme.titleMedium),
                      ...albums.map(
                        (a) => ListTile(
                          leading: ArtworkImage(
                              url: a.bestThumbUrl(size: 160), size: 46, radius: 8),
                          title: Text(a.title,
                              style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                          subtitle:
                              Text(a.artistDisplay, style: TextStyle(color: sub)),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => AlbumScreen(albumId: a.id)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if ((_selectedDeviceFilter == 0 || _selectedDeviceFilter == 3) &&
                        artists.isNotEmpty) ...[
                      Text('Artis', style: Theme.of(context).textTheme.titleMedium),
                      ...artists.map(
                        (a) => ListTile(
                          leading: ArtworkImage(
                            url: a.bestThumbUrl(size: 160),
                            size: 46,
                            isCircle: true,
                          ),
                          title: Text(a.title,
                              style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => ArtistScreen(artistId: a.id)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if ((_selectedDeviceFilter == 0 || _selectedDeviceFilter == 4) &&
                        playlists.isNotEmpty) ...[
                      Text('Playlist',
                          style: Theme.of(context).textTheme.titleMedium),
                      ...playlists.map(
                        (p) => ListTile(
                          leading: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.pillOf(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.queue_music_rounded, color: ink),
                          ),
                          title: Text(p.name,
                              style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.tracks.length} lagu',
                              style: TextStyle(color: sub)),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LocalPlaylistScreen(playlistId: p.id),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (songs.isEmpty &&
                        albums.isEmpty &&
                        artists.isEmpty &&
                        playlists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text('Tidak ditemukan di perangkat.',
                              style: TextStyle(color: sub)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGenreTile(String label, String genreQuery) {
    final ink = AppColors.inkOf(context);

    return LiquidGlassTap(
      onTap: () => _executeSearch(genreQuery, filterOverride: 'all'),
      child: LiquidGlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}
