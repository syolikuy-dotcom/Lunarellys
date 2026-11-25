import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
import '../../data/services/api_client.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/media_card.dart';
import '../widgets/track_tile.dart';
import '../widgets/user_avatar_button.dart';
import 'detail_screens.dart';
import 'home_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenDrawer;
  const SearchScreen({super.key, required this.onOpenDrawer});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _filter = 'all';
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  List<String> _suggestions = const [];
  SearchResponseModel? _result;
  List<MusicItem> _extraItems = const [];
  String? _continuation;

  static const _filters = [
    ('all', 'All'),
    ('songs', 'Songs'),
    ('artists', 'Artists'),
    ('albums', 'Albums'),
    ('playlists', 'Playlists'),
    ('videos', 'Videos'),
  ];

  static const _browseColors = [
    Color(0xFFE13300),
    Color(0xFF006450),
    Color(0xFF8400E7),
    Color(0xFF1E3264),
    Color(0xFFE8115B),
    Color(0xFF148A08),
    Color(0xFFBC5900),
    Color(0xFF0D73EC),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final list = await ref.read(apiClientProvider).getSuggestions(val.trim());
        if (mounted) setState(() => _suggestions = list);
      } catch (_) {}
    });
  }

  Future<void> _performSearch(String query, {String? filterOverride}) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final activeFilter = filterOverride ?? _filter;
    FocusScope.of(context).unfocus();
    setState(() {
      _filter = activeFilter;
      _loading = true;
      _error = null;
      _suggestions = const [];
      _extraItems = const [];
      _continuation = null;
    });

    await ref.read(libraryProvider.notifier).addSearchHistory(q);

    try {
      final res = await ref.read(apiClientProvider).search(q, filter: activeFilter);
      if (!mounted) return;
      setState(() {
        _result = res;
        _continuation = res.continuation;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is MusicApiException
            ? err.message
            : 'Unable to search right now. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_continuation == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(apiClientProvider).search(
            _controller.text.trim(),
            filter: _filter,
            continuation: _continuation,
          );
      if (!mounted) return;
      setState(() {
        _extraItems = [..._extraItems, ...res.results];
        _continuation = res.continuation;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openItem(MusicItem item, List<MusicItem> playable) {
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
            queue: playable,
            contextName: 'Search',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(libraryProvider).searchHistory;
    final moodsAsync = ref.watch(homeMoodsProvider);
    final allItems = [...?_result?.results, ..._extraItems];
    final playable = allItems.where((i) => i.isPlayable).toList();
    final cards = allItems.where((i) => !i.isPlayable).toList();
    final isWide = MediaQuery.of(context).size.width >= 640;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            UserAvatarButton(size: 34, onTap: widget.onOpenDrawer),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Search',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
              onChanged: (v) {
                setState(() {});
                _onChanged(v);
              },
              onSubmitted: (v) => _performSearch(v),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'What do you want to listen to?',
                hintStyle: const TextStyle(color: Color(0xFF535353), fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.black87),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.black87),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _result = null;
                            _suggestions = const [];
                            _extraItems = const [];
                            _error = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_result != null || _controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final (key, label) = _filters[i];
                    final active = _filter == key;
                    return ChoiceChip(
                      label: Text(label),
                      selected: active,
                      onSelected: (_) {
                        setState(() => _filter = key);
                        if (_controller.text.trim().isNotEmpty) {
                          _performSearch(_controller.text, filterOverride: key);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.spotifyGreen),
                  )
                : _suggestions.isNotEmpty
                    ? ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _suggestions.length,
                        itemBuilder: (ctx, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            leading: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                            title: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.north_west_rounded, size: 17, color: AppColors.textMuted),
                            onTap: () {
                              _controller.text = s;
                              _performSearch(s);
                            },
                          );
                        },
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          )
                        : _result == null
                            ? _buildBrowseIdle(history, moodsAsync.valueOrNull ?? const [])
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 132),
                                children: [
                                  if (_result!.topResult != null && _filter == 'all') ...[
                                    Text('Top result', style: Theme.of(context).textTheme.titleLarge),
                                    const SizedBox(height: 10),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _openItem(_result!.topResult!, playable),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceElevated,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            ArtworkImage(
                                              url: _result!.topResult!.bestThumbUrl(size: 240),
                                              size: 76,
                                              radius: 8,
                                              isCircle: _result!.topResult!.type == 'artist',
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _result!.topResult!.title,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: Theme.of(context).textTheme.titleLarge,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${_result!.topResult!.type.toUpperCase()} · ${_result!.topResult!.artistDisplay}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: Theme.of(context).textTheme.bodyMedium,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: const BoxDecoration(
                                                color: AppColors.spotifyGreen,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.black,
                                                size: 26,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                  ],
                                  if (playable.isNotEmpty) ...[
                                    Text('Songs', style: Theme.of(context).textTheme.titleLarge),
                                    const SizedBox(height: 8),
                                    ...playable.map((t) => TrackTile(track: t, queue: playable)),
                                    const SizedBox(height: 20),
                                  ],
                                  if (cards.isNotEmpty) ...[
                                    Text(
                                      'Albums, Artists & Playlists',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: cards.length,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isWide ? 4 : 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 14,
                                        mainAxisExtent: 248,
                                      ),
                                      itemBuilder: (ctx, i) => LayoutBuilder(
                                        builder: (_, box) => Center(
                                          child: MediaCard(
                                            item: cards[i],
                                            width: box.maxWidth.clamp(120.0, 156.0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (_continuation != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 20),
                                      child: Center(
                                        child: OutlinedButton(
                                          onPressed: _loadingMore ? null : _loadMore,
                                          child: _loadingMore
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.spotifyGreen,
                                                  ),
                                                )
                                              : const Text('Load More'),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseIdle(List<String> history, List<MusicMood> moods) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 132),
      children: [
        if (history.isNotEmpty) ...[
          Text('Recent searches', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          ...history.take(6).map(
                (q) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded, color: AppColors.textSecondary),
                  title: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                    onPressed: () => ref.read(libraryProvider.notifier).removeSearchHistory(q),
                  ),
                  onTap: () {
                    _controller.text = q;
                    _performSearch(q);
                  },
                ),
              ),
          const SizedBox(height: 18),
        ],
        Text('Browse all', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (moods.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Search songs, artists, albums, or playlists',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: moods.take(16).length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 86,
            ),
            itemBuilder: (ctx, i) {
              final mood = moods[i];
              final color = _browseColors[i % _browseColors.length];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MoodPlaylistsScreen(mood: mood),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: color,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -12,
                          bottom: -10,
                          child: Transform.rotate(
                            angle: math.pi / 7,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(55),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.graphic_eq_rounded,
                                color: Colors.white54,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 44, 12),
                          child: Text(
                            mood.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              height: 1.2,
                              color: Colors.white,
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
      ],
    );
  }
}
