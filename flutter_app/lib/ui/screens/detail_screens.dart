import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
import '../../data/services/api_client.dart';
import '../../state/auth_provider.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/google_logo.dart';
import '../widgets/media_card.dart';
import '../widgets/track_tile.dart';
import 'auth_screen.dart';

class ArtistScreen extends ConsumerWidget {
  final String artistId;
  const ArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(apiClientProvider).getArtist(artistId);
    final shuffleActive = ref.watch(playerProvider.select((s) => s.shuffle));
    final isFollowed = ref.watch(libraryProvider.select((l) => l.isArtistFollowed(artistId)));

    return Scaffold(
      body: FutureBuilder<MusicArtistDetail>(
        future: future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.spotifyGreen),
            );
          }
          if (snap.hasError || !snap.hasData) {
            final msg = snap.error is MusicApiException
                ? (snap.error as MusicApiException).message
                : 'Unable to load artist right now.';
            return Scaffold(
              appBar: AppBar(title: const Text('Artist')),
              body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(msg, textAlign: TextAlign.center))),
            );
          }
          final artist = snap.data!;
          final allSongs = artist.sections
              .expand((s) => s.items)
              .where((i) => i.isPlayable)
              .toList();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 270,
                pinned: true,
                backgroundColor: AppColors.background,
                flexibleSpace: LayoutBuilder(
                  builder: (_, constraints) {
                    final collapsed = constraints.biggest.height <=
                        MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
                    return FlexibleSpaceBar(
                      title: collapsed
                          ? Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF2E3A4D),
                              AppColors.background,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Center(
                            child: ArtworkImage(
                              url: artist.bestThumbUrl(size: 600),
                              size: 168,
                              isCircle: true,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artist.name, style: Theme.of(context).textTheme.headlineLarge),
                      if (artist.subscribers != null) ...[
                        const SizedBox(height: 4),
                        Text(artist.subscribers!, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => ref
                                .read(libraryProvider.notifier)
                                .toggleFollowArtist(artist.toMusicItem()),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isFollowed ? AppColors.spotifyGreen : AppColors.borderStrong,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              isFollowed ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: isFollowed ? AppColors.spotifyGreenBright : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (allSongs.isNotEmpty) ...[
                            IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: shuffleActive ? AppColors.spotifyGreen : AppColors.textSecondary,
                              ),
                              tooltip: 'Shuffle Artist',
                              onPressed: () => ref
                                  .read(playerProvider.notifier)
                                  .playShuffled(allSongs, contextName: artist.name),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => ref
                                  .read(playerProvider.notifier)
                                  .playTrack(allSongs.first, queue: allSongs, contextName: artist.name),
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: AppColors.spotifyGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) {
                    final sec = artist.sections[idx];
                    final isSongs = sec.items.isNotEmpty && sec.items.every((i) => i.isPlayable);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              sec.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (isSongs)
                            ...sec.items.asMap().entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: TrackTile(
                                      track: entry.value,
                                      queue: sec.items,
                                      trackNumber: entry.key + 1,
                                    ),
                                  ),
                                )
                          else
                            SizedBox(
                              height: 238,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                itemCount: sec.items.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 14),
                                itemBuilder: (_, i) => MediaCard(
                                  item: sec.items[i],
                                  width: 148,
                                  contextLabel: artist.name,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  childCount: artist.sections.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 132)),
            ],
          );
        },
      ),
    );
  }
}

class AlbumScreen extends ConsumerStatefulWidget {
  final String albumId;
  const AlbumScreen({super.key, required this.albumId});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  MusicAlbumDetail? _album;
  List<MusicItem> _tracks = const [];
  String? _continuation;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).getAlbum(widget.albumId);
      if (!mounted) return;
      setState(() {
        _album = res;
        _tracks = res.tracks;
        _continuation = res.continuation;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is MusicApiException
            ? err.message
            : 'Unable to load album right now.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_continuation == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(apiClientProvider).getAlbum(
            widget.albumId,
            continuation: _continuation,
          );
      if (!mounted) return;
      setState(() {
        _tracks = [..._tracks, ...res.tracks];
        _continuation = res.continuation;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shuffleActive = ref.watch(playerProvider.select((s) => s.shuffle));
    final isSaved = ref.watch(libraryProvider.select((l) => l.isAlbumSaved(widget.albumId)));

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.spotifyGreen)),
      );
    }
    if (_error != null || _album == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Album')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Unable to load album right now.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loadInitial, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final album = _album!;
    final artistStr = album.artists.map((a) => a.name).join(', ');
    final meta = [
      album.type.isNotEmpty ? '${album.type[0].toUpperCase()}${album.type.substring(1)}' : 'Album',
      if (album.year != null) '${album.year}',
      '${album.trackCount ?? _tracks.length} songs',
    ].join(' · ');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: LayoutBuilder(
              builder: (_, constraints) {
                final collapsed = constraints.biggest.height <=
                    MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
                return FlexibleSpaceBar(
                  title: collapsed
                      ? Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF3A3054),
                          AppColors.background,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Container(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x88000000),
                                blurRadius: 28,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ArtworkImage(
                            url: album.bestThumbUrl(size: 600),
                            size: 196,
                            radius: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.title, style: Theme.of(context).textTheme.headlineMedium),
                  if (artistStr.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      artistStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(meta, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isSaved ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                          color: isSaved ? AppColors.spotifyGreen : AppColors.textSecondary,
                          size: 26,
                        ),
                        tooltip: isSaved ? 'Saved in Library' : 'Save Album',
                        onPressed: () => ref
                            .read(libraryProvider.notifier)
                            .toggleSaveAlbum(album.toMusicItem()),
                      ),
                      if (album.duration != null)
                        Expanded(
                          child: Text(
                            album.duration!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else
                        const Spacer(),
                      if (_tracks.isNotEmpty) ...[
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: shuffleActive ? AppColors.spotifyGreen : AppColors.textSecondary,
                          ),
                          tooltip: 'Shuffle Album',
                          onPressed: () => ref
                              .read(playerProvider.notifier)
                              .playShuffled(_tracks, contextName: album.title),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => ref
                              .read(playerProvider.notifier)
                              .playTrack(_tracks.first, queue: _tracks, contextName: album.title),
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: AppColors.spotifyGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => TrackTile(
                  track: _tracks[i],
                  queue: _tracks,
                  trackNumber: i + 1,
                  showArtwork: false,
                ),
                childCount: _tracks.length,
              ),
            ),
          ),
          if (_continuation != null && _continuation!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.spotifyGreen),
                          )
                        : const Text('Load More Tracks'),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 132)),
        ],
      ),
    );
  }
}

class PlaylistScreen extends ConsumerStatefulWidget {
  final String playlistId;
  const PlaylistScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  MusicPlaylistDetail? _playlist;
  List<MusicItem> _tracks = const [];
  String? _continuation;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).getPlaylist(widget.playlistId);
      if (!mounted) return;
      setState(() {
        _playlist = res;
        _tracks = res.tracks;
        _continuation = res.continuation;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is MusicApiException
            ? err.message
            : 'Unable to load playlist right now.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_continuation == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(apiClientProvider).getPlaylist(
            widget.playlistId,
            continuation: _continuation,
          );
      if (!mounted) return;
      setState(() {
        _tracks = [..._tracks, ...res.tracks];
        _continuation = res.continuation;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shuffleActive = ref.watch(playerProvider.select((s) => s.shuffle));
    final isSaved = ref.watch(libraryProvider.select((l) => l.isPlaylistSaved(widget.playlistId)));

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.spotifyGreen)),
      );
    }
    if (_error != null || _playlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Unable to load playlist right now.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loadInitial, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final pl = _playlist!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: LayoutBuilder(
              builder: (_, constraints) {
                final collapsed = constraints.biggest.height <=
                    MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
                return FlexibleSpaceBar(
                  title: collapsed
                      ? Text(pl.title, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF1E4638),
                          AppColors.background,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Container(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x88000000),
                                blurRadius: 28,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ArtworkImage(
                            url: pl.bestThumbUrl(size: 600),
                            size: 196,
                            radius: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pl.title, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    [if (pl.author != null) pl.author!, '${_tracks.length} songs'].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isSaved ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                          color: isSaved ? AppColors.spotifyGreen : AppColors.textSecondary,
                          size: 26,
                        ),
                        tooltip: isSaved ? 'Saved in Library' : 'Save Playlist',
                        onPressed: () => ref
                            .read(libraryProvider.notifier)
                            .toggleSavePlaylist(pl.toMusicItem()),
                      ),
                      if (pl.duration != null)
                        Expanded(
                          child: Text(
                            pl.duration!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else
                        const Spacer(),
                      if (_tracks.isNotEmpty) ...[
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: shuffleActive ? AppColors.spotifyGreen : AppColors.textSecondary,
                          ),
                          tooltip: 'Shuffle Playlist',
                          onPressed: () => ref
                              .read(playerProvider.notifier)
                              .playShuffled(_tracks, contextName: pl.title),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => ref
                              .read(playerProvider.notifier)
                              .playTrack(_tracks.first, queue: _tracks, contextName: pl.title),
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: AppColors.spotifyGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => TrackTile(track: _tracks[i], queue: _tracks),
                childCount: _tracks.length,
              ),
            ),
          ),
          if (_continuation != null && _continuation!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.spotifyGreen),
                          )
                        : const Text('Load More Tracks'),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 132)),
        ],
      ),
    );
  }
}

class LocalPlaylistScreen extends ConsumerWidget {
  final String playlistId;
  const LocalPlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(libraryProvider).playlists;
    final shuffleActive = ref.watch(playerProvider.select((s) => s.shuffle));

    UserPlaylist? pl;
    for (final item in playlists) {
      if (item.id == playlistId) {
        pl = item;
        break;
      }
    }
    if (pl == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: const Center(child: Text('Playlist not found')),
      );
    }

    final playlist = pl;
    final coverUrl = playlist.tracks.isNotEmpty ? playlist.tracks.first.bestThumbUrl(size: 500) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename Playlist',
            onPressed: () => _showRename(context, ref, playlist),
          ),
        ],
      ),
      body: playlist.tracks.isEmpty
          ? const Center(child: Text('No songs in this playlist yet'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 132),
              itemCount: playlist.tracks.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (coverUrl != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ArtworkImage(url: coverUrl, size: 180, radius: 8),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(playlist.name, style: Theme.of(context).textTheme.headlineMedium),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${playlist.tracks.length} songs',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: shuffleActive ? AppColors.spotifyGreen : AppColors.textSecondary,
                              ),
                              onPressed: () => ref
                                  .read(playerProvider.notifier)
                                  .playShuffled(playlist.tracks, contextName: playlist.name),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => ref.read(playerProvider.notifier).playTrack(
                                    playlist.tracks.first,
                                    queue: playlist.tracks,
                                    contextName: playlist.name,
                                  ),
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: AppColors.spotifyGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 30),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                final track = playlist.tracks[i - 1];
                return TrackTile(
                  track: track,
                  queue: playlist.tracks,
                  trailingExtra: IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 38),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 19, color: AppColors.textMuted),
                    onPressed: () => ref
                        .read(libraryProvider.notifier)
                        .removeTrackFromPlaylist(playlist.id, track.id),
                  ),
                );
              },
            ),
    );
  }

  void _showRename(BuildContext context, WidgetRef ref, UserPlaylist playlist) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).renamePlaylist(playlist.id, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class MoodPlaylistsScreen extends ConsumerWidget {
  final MusicMood mood;
  const MoodPlaylistsScreen({super.key, required this.mood});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(apiClientProvider).getMoodPlaylists(mood.browseId, mood.params);
    return Scaffold(
      appBar: AppBar(title: Text(mood.name)),
      body: FutureBuilder<List<MusicSection>>(
        future: future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.spotifyGreen),
            );
          }
          if (snap.hasError || !snap.hasData) {
            final msg = snap.error is MusicApiException
                ? (snap.error as MusicApiException).message
                : 'Unable to load mood right now.';
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(msg, textAlign: TextAlign.center)));
          }
          final sections = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 132),
            itemCount: sections.length,
            itemBuilder: (ctx, idx) {
              final sec = sections[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        sec.title.isEmpty ? mood.name : sec.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    SizedBox(
                      height: 238,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: sec.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) => MediaCard(
                          item: sec.items[i],
                          width: 148,
                          contextLabel: mood.name,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final library = ref.watch(libraryProvider);
    final user = auth.user;
    final isGoogle = auth.isSignedInGoogle;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.spotifyGreen.withAlpha(55),
                  AppColors.surfaceElevated,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: isGoogle ? AppColors.surfaceHigh : AppColors.spotifyGreen,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: user?.picture.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: user!.picture,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(
                              user.initials,
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            user?.initials ?? 'L',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: isGoogle ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.name ?? 'Guest Listener',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  isGoogle ? (user?.email ?? 'Google Account') : 'Local Device Account',
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                if (!isGoogle)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthScreen(allowBack: true),
                        ),
                      );
                    },
                    icon: const GoogleLogoIcon(size: 18),
                    label: const Text('Connect Google Account'),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: auth.isSyncing
                            ? null
                            : () => ref.read(libraryProvider.notifier).syncWithCloud(),
                        icon: auth.isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: Text(auth.isSyncing ? 'Syncing...' : 'Sync Cloud Library'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).signOut();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Your Library Summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              _statTile('Liked Songs', '${library.likedSongs.length}', Icons.favorite_rounded),
              _statTile('Playlists', '${library.playlists.length}', Icons.queue_music_rounded),
              _statTile('Following', '${library.followedArtists.length}', Icons.person_rounded),
              _statTile('Offline', '${library.downloadedTracks.length}', Icons.download_done_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.spotifyGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _aboutTapCount = 0;
  DateTime? _lastTapAt;

  void _handleAboutTap() {
    final now = DateTime.now();
    if (_lastTapAt == null || now.difference(_lastTapAt!) > const Duration(seconds: 2)) {
      _aboutTapCount = 1;
    } else {
      _aboutTapCount += 1;
    }
    _lastTapAt = now;
    if (_aboutTapCount >= 7) {
      _aboutTapCount = 0;
      _openAdminAccessDialog();
    }
  }

  void _openAdminAccessDialog() {
    final passCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    var busy = false;
    String? statusMsg;
    var ok = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded, color: AppColors.spotifyGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Admin Access', style: Theme.of(ctx).textTheme.titleLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your server ADMIN_PASSCODE to verify node health or apply a private endpoint override.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Admin Passcode',
                      hintText: 'Required',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Custom Node URL (optional)',
                      hintText: 'Leave blank to keep active build URL',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: keyCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API Key Override (optional)',
                      hintText: 'Leave blank to keep current key',
                    ),
                  ),
                  if (statusMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      statusMsg!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ok ? AppColors.spotifyGreenBright : AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final pass = passCtrl.text.trim();
                                  final customUrl = urlCtrl.text.trim();
                                  final customKey = keyCtrl.text.trim();
                                  if (pass.isEmpty) {
                                    setSheetState(() {
                                      ok = false;
                                      statusMsg = 'Admin passcode is required.';
                                    });
                                    return;
                                  }
                                  if (customUrl.isNotEmpty &&
                                      !customUrl.startsWith('http://') &&
                                      !customUrl.startsWith('https://')) {
                                    setSheetState(() {
                                      ok = false;
                                      statusMsg = 'Custom URL must start with http:// or https://';
                                    });
                                    return;
                                  }
                                  setSheetState(() {
                                    busy = true;
                                    statusMsg = null;
                                  });
                                  try {
                                    final api = ref.read(apiClientProvider);
                                    final stats = await api.verifyAdminAndFetchStats(
                                      passcode: pass,
                                      overrideBaseUrl: customUrl,
                                      overrideApiKey: customKey,
                                    );
                                    if (!mounted || !ctx.mounted) return;
                                    if (customUrl.isNotEmpty || customKey.isNotEmpty) {
                                      final cur = ref.read(settingsProvider);
                                      await ref.read(settingsProvider.notifier).setServerConfig(
                                            url: customUrl.isNotEmpty ? customUrl : cur.serverUrl,
                                            apiKey: customKey.isNotEmpty ? customKey : cur.apiKey,
                                          );
                                    }
                                    if (!ctx.mounted) return;
                                    setSheetState(() {
                                      busy = false;
                                      ok = true;
                                      statusMsg =
                                          'Verified · Node ${stats['node'] ?? ''} · Uptime ${stats['uptime'] ?? 0}s · Mem ${stats['memoryMb'] ?? 0}MB';
                                    });
                                  } catch (err) {
                                    if (!ctx.mounted) return;
                                    setSheetState(() {
                                      busy = false;
                                      ok = false;
                                      statusMsg = err.toString();
                                    });
                                  }
                                },
                          child: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Text('Verify & Apply'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                await ref.read(settingsProvider.notifier).resetServerConfig();
                                if (!ctx.mounted) return;
                                setSheetState(() {
                                  ok = true;
                                  statusMsg = 'Restored build default endpoint.';
                                });
                              },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      passCtrl.dispose();
      urlCtrl.dispose();
      keyCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final downloadsCount = ref.watch(libraryProvider.select((l) => l.downloadedTracks.length));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        children: [
          Text('Account & Sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const GoogleLogoIcon(size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.isSignedInGoogle ? (auth.user?.name ?? 'Google Account') : 'Guest Listener',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      Text(
                        auth.isSignedInGoogle
                            ? (auth.user?.email ?? 'Cloud library sync active')
                            : 'Sign in with Google to sync liked songs & playlists',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (auth.isSignedInGoogle)
                  TextButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                    child: const Text('Log out'),
                  )
                else
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthScreen(allowBack: true),
                        ),
                      );
                    },
                    child: const Text('Sign in'),
                  ),
              ],
            ),
          ),
          const Divider(height: 36),
          Text('Playback & Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Audio Streaming Quality'),
            subtitle: Text(settings.audioQuality.label),
            trailing: DropdownButton<AudioQuality>(
              value: settings.audioQuality,
              dropdownColor: AppColors.surfaceElevated,
              onChanged: (q) {
                if (q != null) ref.read(settingsProvider.notifier).setAudioQuality(q);
              },
              items: AudioQuality.values
                  .map((q) => DropdownMenuItem(value: q, child: Text(q.label)))
                  .toList(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: AppColors.spotifyGreen,
            title: const Text('Dynamic Album Colors'),
            subtitle: const Text('Tint Now Playing backdrop from album artwork'),
            value: settings.dynamicAlbumColors,
            onChanged: (v) => ref.read(settingsProvider.notifier).setDynamicColors(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: AppColors.spotifyGreen,
            title: const Text('Autoplay Radio'),
            subtitle: const Text('Keep playing similar songs when your queue ends'),
            value: settings.autoRadio,
            onChanged: (v) => ref.read(settingsProvider.notifier).setAutoRadio(v),
          ),
          const Divider(height: 32),
          Text('Storage', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Offline Storage'),
            subtitle: Text('$downloadsCount downloaded tracks saved locally'),
            trailing: const Icon(Icons.folder_outlined, color: AppColors.textSecondary),
          ),
          const Divider(height: 32),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(AppConfig.appName),
            subtitle: const Text('Version 1.0.0'),
            onTap: _handleAboutTap,
          ),
        ],
      ),
    );
  }
}
