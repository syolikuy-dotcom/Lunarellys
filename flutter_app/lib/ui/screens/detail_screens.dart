import 'dart:math' as math;
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
import '../widgets/liquid_glass.dart';
import '../widgets/lunarellys_logo.dart';
import '../widgets/media_card.dart';
import '../widgets/track_tile.dart';
import 'auth_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';

class ArtistScreen extends ConsumerWidget {
  final String artistId;
  const ArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(apiClientProvider).getArtist(artistId);
    final shuffleActive = ref.watch(playerProvider.select((s) => s.shuffle));
    final isFollowed = ref.watch(libraryProvider.select((l) => l.isArtistFollowed(artistId)));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LiquidGlassAmbientBackground(
        child: FutureBuilder<MusicArtistDetail>(
        future: future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brandGreen),
            );
          }
          if (snap.hasError || !snap.hasData) {
            final msg = snap.error is MusicApiException
                ? (snap.error as MusicApiException).message
                : 'Unable to load artist right now.';
            return Scaffold(
              backgroundColor: Colors.transparent,
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
                backgroundColor: const Color(0xCC0A0D10),
                flexibleSpace: LayoutBuilder(
                  builder: (_, constraints) {
                    final collapsed = constraints.biggest.height <=
                        MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
                    return FlexibleSpaceBar(
                      title: collapsed
                          ? Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF1D3B46).withAlpha(190),
                              Colors.transparent,
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
                                color: isFollowed ? AppColors.brandGreen : AppColors.borderStrong,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              isFollowed ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: isFollowed ? AppColors.brandGreenBright : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (allSongs.isNotEmpty) ...[
                            IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: shuffleActive ? AppColors.brandGreen : AppColors.textSecondary,
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
                                  color: AppColors.brandGreen,
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
              const SliverToBoxAdapter(child: SizedBox(height: 164)),
            ],
          );
        },
      ),
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
        backgroundColor: AppColors.background,
        body: LiquidGlassAmbientBackground(
          child: Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
        ),
      );
    }
    if (_error != null || _album == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Album')),
        body: LiquidGlassAmbientBackground(
          child: Center(
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
      backgroundColor: AppColors.background,
      body: LiquidGlassAmbientBackground(
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xCC0A0D10),
            flexibleSpace: LayoutBuilder(
              builder: (_, constraints) {
                final collapsed = constraints.biggest.height <=
                    MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
                return FlexibleSpaceBar(
                  title: collapsed
                      ? Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF28264A).withAlpha(190),
                          Colors.transparent,
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
                          color: isSaved ? AppColors.brandGreen : AppColors.textSecondary,
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
                            color: shuffleActive ? AppColors.brandGreen : AppColors.textSecondary,
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
                              color: AppColors.brandGreen,
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen),
                          )
                        : const Text('Load More Tracks'),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 164)),
        ],
      ),
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
        backgroundColor: AppColors.background,
        body: LiquidGlassAmbientBackground(
          child: Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
        ),
      );
    }
    if (_error != null || _playlist == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Playlist')),
        body: LiquidGlassAmbientBackground(
          child: Center(
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
        ),
      );
    }

    final pl = _playlist!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LiquidGlassAmbientBackground(
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xCC0A0D10),
            flexibleSpace: LayoutBuilder(
              builder: (_, constraints) {
                final collapsed = constraints.biggest.height <=
                    MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
                return FlexibleSpaceBar(
                  title: collapsed
                      ? Text(pl.title, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF153E36).withAlpha(190),
                          Colors.transparent,
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
                          color: isSaved ? AppColors.brandGreen : AppColors.textSecondary,
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
                            color: shuffleActive ? AppColors.brandGreen : AppColors.textSecondary,
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
                              color: AppColors.brandGreen,
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen),
                          )
                        : const Text('Load More Tracks'),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 164)),
        ],
      ),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0x990A0D10),
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename Playlist',
            onPressed: () => _showRename(context, ref, playlist),
          ),
        ],
      ),
      body: LiquidGlassAmbientBackground(
        child: playlist.tracks.isEmpty
            ? const Center(child: Text('No songs in this playlist yet'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 164),
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
                                color: shuffleActive ? AppColors.brandGreen : AppColors.textSecondary,
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
                                  color: AppColors.brandGreen,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0x990A0D10),
        title: Text(mood.name),
      ),
      body: LiquidGlassAmbientBackground(
        child: FutureBuilder<List<MusicSection>>(
        future: future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brandGreen),
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
            padding: const EdgeInsets.only(bottom: 164),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0x990A0D10),
        title: const Text('Profile'),
      ),
      body: LiquidGlassAmbientBackground(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 164),
        children: [
          LiquidGlassSurface(
            borderRadius: 24,
            padding: const EdgeInsets.all(20),
            tintColor: AppColors.brandDeep,
            borderColor: AppColors.brandGreen.withAlpha(88),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: isGoogle ? AppColors.surfaceHigh : AppColors.brandGreen,
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
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 82,
            ),
            children: [
              _statTile('Liked Songs', '${library.likedSongs.length}', Icons.favorite_rounded),
              _statTile('Playlists', '${library.playlists.length}', Icons.queue_music_rounded),
              _statTile('Following', '${library.followedArtists.length}', Icons.person_rounded),
              _statTile('Offline', '${library.downloadedTracks.length}', Icons.download_done_rounded),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return LiquidGlassSurface(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandGreenBright, size: 22),
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
      _openAdminNodeSheet();
    }
  }

  void _openAdminNodeSheet() {
    final cur = ref.read(settingsProvider);
    final urlCtrl = TextEditingController(text: cur.serverUrl);
    final keyCtrl = TextEditingController(text: cur.apiKey);
    final passCtrl = TextEditingController();
    var busy = false;
    NodeProbeResult? probeResult;
    String? adminMsg;
    var adminOk = false;

    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, color: AppColors.brandGreenBright),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Admin & Node Setup',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure your Pterodactyl / self-hosted node endpoint (HTTP/HTTPS & custom ports) or run admin diagnostics.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.brandGreenBright),
                      label: const Text('Pterodactyl Preset (:4686)'),
                      onPressed: () {
                        urlCtrl.text = AppConfig.pterodactylExampleUrl;
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.restore_rounded, size: 16, color: AppColors.textSecondary),
                      label: const Text('Build Default'),
                      onPressed: () {
                        urlCtrl.text = AppConfig.defaultBaseUrl;
                        keyCtrl.text = AppConfig.defaultApiKey;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Node Base URL',
                    hintText: AppConfig.pterodactylExampleUrl,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key (optional)',
                    hintText: 'Leave blank if API_KEYS is empty',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Admin Passcode (for diagnostics)',
                    hintText: 'ADMIN_PASSCODE',
                  ),
                ),
                if (probeResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (probeResult!.ok ? AppColors.brandGreen : AppColors.error).withAlpha(28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (probeResult!.ok ? AppColors.brandGreen : AppColors.error).withAlpha(90),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          probeResult!.ok
                              ? '${probeResult!.service} v${probeResult!.version} · ${probeResult!.message}'
                              : 'Connection Failed · ${probeResult!.message}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: probeResult!.ok ? AppColors.brandGreenBright : AppColors.error,
                          ),
                        ),
                        if (probeResult!.ok) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Region: ${probeResult!.region} · OAuth: ${probeResult!.googleOAuthConfigured ? 'Ready' : 'Off'}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (adminMsg != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (adminOk ? AppColors.brandGreen : AppColors.error).withAlpha(24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (adminOk ? AppColors.brandGreen : AppColors.error).withAlpha(90),
                      ),
                    ),
                    child: Text(
                      adminMsg!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: adminOk ? AppColors.brandGreenBright : AppColors.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setSheetState(() {
                                busy = true;
                                adminMsg = null;
                              });
                              final res = await ref.read(apiClientProvider).probeNode(
                                    overrideBaseUrl: urlCtrl.text,
                                    overrideApiKey: keyCtrl.text,
                                  );
                              if (!ctx.mounted) return;
                              setSheetState(() {
                                busy = false;
                                probeResult = res;
                              });
                            },
                      child: const Text('Test Node'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final pass = passCtrl.text.trim();
                              if (pass.isEmpty) {
                                setSheetState(() {
                                  adminOk = false;
                                  adminMsg = 'Enter ADMIN_PASSCODE to run diagnostics.';
                                });
                                return;
                              }
                              setSheetState(() {
                                busy = true;
                                adminMsg = null;
                              });
                              try {
                                final stats = await ref.read(apiClientProvider).verifyAdminAndFetchStats(
                                      passcode: pass,
                                      overrideBaseUrl: urlCtrl.text.trim(),
                                      overrideApiKey: keyCtrl.text.trim(),
                                    );
                                if (!ctx.mounted) return;
                                setSheetState(() {
                                  busy = false;
                                  adminOk = true;
                                  adminMsg =
                                      'Verified · Node ${stats['node'] ?? ''} · Uptime ${stats['uptime'] ?? 0}s · Mem ${stats['memoryMb'] ?? 0}MB';
                                });
                              } catch (err) {
                                if (!ctx.mounted) return;
                                setSheetState(() {
                                  busy = false;
                                  adminOk = false;
                                  adminMsg = err.toString();
                                });
                              }
                            },
                      child: const Text('Verify Admin'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              await ref.read(settingsProvider.notifier).resetServerConfig();
                              urlCtrl.text = AppConfig.defaultBaseUrl;
                              keyCtrl.text = AppConfig.defaultApiKey;
                              ref.invalidate(homeFeedProvider);
                              ref.invalidate(homeMoodsProvider);
                              ref.invalidate(exploreProvider);
                              if (!ctx.mounted) return;
                              setSheetState(() {
                                adminOk = true;
                                adminMsg = 'Restored build default endpoint.';
                              });
                            },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await ref.read(settingsProvider.notifier).setServerConfig(
                                  url: urlCtrl.text,
                                  apiKey: keyCtrl.text,
                                );
                            ref.invalidate(homeFeedProvider);
                            ref.invalidate(homeMoodsProvider);
                            ref.invalidate(exploreProvider);
                            if (!mounted || !ctx.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Connected to ${AppConfig.normalizeServerUrl(urlCtrl.text)}',
                                ),
                              ),
                            );
                          },
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('Save & Apply Node'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      urlCtrl.dispose();
      keyCtrl.dispose();
      passCtrl.dispose();
    });
  }

  void _showPlayerBgPicker(AppSettingsState settings) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player background style', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...PlayerBackgroundStyle.values.map((style) {
              final selected = settings.playerBackgroundStyle == style;
              return RadioListTile<PlayerBackgroundStyle>(
                value: style,
                groupValue: settings.playerBackgroundStyle,
                activeColor: AppColors.brandGreenBright,
                title: Text(style.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  style.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                selected: selected,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).setPlayerBackgroundStyle(val);
                    Navigator.pop(ctx);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSliderStylePicker(AppSettingsState settings) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player slider style', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 104,
              children: PlayerSliderStyle.values.map((style) {
                final selected = settings.sliderStyle == style;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    ref.read(settingsProvider.notifier).setSliderStyle(style);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brandGreen.withAlpha(32)
                          : Colors.white.withAlpha(14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.brandGreenBright : AppColors.border,
                        width: selected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 26,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _SliderStylePreviewPainter(
                              style: style,
                              activeColor: selected ? AppColors.brandGreenBright : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          style.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected ? AppColors.brandGreenBright : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioQualityPicker(AppSettingsState settings) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audio quality preference', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...AudioQuality.values.map((q) {
              return RadioListTile<AudioQuality>(
                value: q,
                groupValue: settings.audioQuality,
                activeColor: AppColors.brandGreenBright,
                title: Text(q.label),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).setAudioQuality(val);
                    Navigator.pop(ctx);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(AppSettingsState settings) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language_rounded, color: AppColors.brandGreenBright),
                const SizedBox(width: 10),
                Text('Application language', style: Theme.of(ctx).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 10),
            ...AppLanguageOption.values.map((lang) {
              return RadioListTile<AppLanguageOption>(
                value: lang,
                groupValue: settings.appLanguage,
                activeColor: AppColors.brandGreenBright,
                title: Text(lang.label),
                subtitle: Text(
                  lang.subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).setAppLanguage(val);
                    Navigator.pop(ctx);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final downloadsCount = ref.watch(libraryProvider.select((l) => l.downloadedTracks.length));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0x990A0D10),
        title: const Text('Settings'),
      ),
      body: LiquidGlassAmbientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 164),
          children: [
            GestureDetector(
              onTap: _handleAboutTap,
              child: LiquidGlassSurface(
                borderRadius: 22,
                padding: const EdgeInsets.all(18),
                tintColor: AppColors.brandDeep,
                borderColor: AppColors.brandGreen.withAlpha(88),
                child: Row(
                  children: [
                    const LunarellysLogo(size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppConfig.appName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.brandGreen.withAlpha(42),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.brandGreen.withAlpha(90)),
                                ),
                                child: const Text(
                                  'v${AppConfig.appVersion}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandGreenBright,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'The world of music dedicated to you',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, 'Interface'),
            _SettingsGroupCard(
              children: [
                _SettingsSwitchRow(
                  icon: Icons.layers_outlined,
                  title: 'Mini-player dynamic background',
                  subtitle: 'Tint mini-player with album palette',
                  value: settings.miniPlayerDynamicBg,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setMiniPlayerDynamicBg(v),
                ),
                _SettingsTapRow(
                  icon: Icons.blur_on_rounded,
                  title: 'Player background style',
                  subtitle: settings.playerBackgroundStyle.label,
                  onTap: () => _showPlayerBgPicker(settings),
                ),
                _SettingsTapRow(
                  icon: Icons.tune_rounded,
                  title: 'Player slider style',
                  subtitle: settings.sliderStyle.label,
                  onTap: () => _showSliderStylePicker(settings),
                ),
                _SettingsSwitchRow(
                  icon: Icons.palette_outlined,
                  title: 'Dynamic album colors',
                  subtitle: 'Adapt app accent from playing artwork',
                  value: settings.dynamicAlbumColors,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setDynamicColors(v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, 'Player'),
            _SettingsGroupCard(
              children: [
                _SettingsTapRow(
                  icon: Icons.music_note_rounded,
                  title: 'Audio quality preference',
                  subtitle: settings.audioQuality.label,
                  onTap: () => _showAudioQualityPicker(settings),
                ),
                _SettingsSwitchRow(
                  icon: Icons.radio_rounded,
                  title: 'Autoplay Radio',
                  subtitle: 'Queue similar tracks automatically when queue ends',
                  value: settings.autoRadio,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setAutoRadio(v),
                ),
                _SettingsSwitchRow(
                  icon: Icons.skip_next_rounded,
                  title: 'Auto-skip on error',
                  subtitle: 'Automatically skip to next track if stream fails',
                  value: settings.autoSkipOnError,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setAutoSkipOnError(v),
                ),
                _SettingsSwitchRow(
                  icon: Icons.queue_music_rounded,
                  title: 'Persistent queue',
                  subtitle: 'Restore active queue and speed on restart',
                  value: settings.persistentQueue,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setPersistentQueue(v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, 'App language'),
            _SettingsGroupCard(
              children: [
                _SettingsTapRow(
                  icon: Icons.translate_rounded,
                  title: 'Application language',
                  subtitle: settings.appLanguage.label,
                  onTap: () => _showLanguagePicker(settings),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, 'Account & Sync'),
            _SettingsGroupCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
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
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, 'Storage & About'),
            _SettingsGroupCard(
              children: [
                _SettingsTapRow(
                  icon: Icons.folder_outlined,
                  title: 'Offline Storage',
                  subtitle: '$downloadsCount downloaded tracks saved locally',
                  onTap: () {},
                ),
                _SettingsTapRow(
                  icon: Icons.info_outline_rounded,
                  title: '${AppConfig.appName} v${AppConfig.appVersion}',
                  subtitle: 'Audio streaming & offline library',
                  onTap: _handleAboutTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsTapRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTapRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.7),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.7),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              activeColor: AppColors.brandGreenBright,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderStylePreviewPainter extends CustomPainter {
  final PlayerSliderStyle style;
  final Color activeColor;

  const _SliderStylePreviewPainter({
    required this.style,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final activeX = size.width * 0.56;

    final trackPaint = Paint()
      ..color = Colors.white.withAlpha(48)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style == PlayerSliderStyle.slim ? 4.0 : 5.0;

    final actPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style == PlayerSliderStyle.slim ? 4.4 : 3.6;

    canvas.drawLine(Offset(6, cy), Offset(size.width - 6, cy), trackPaint);

    if (style == PlayerSliderStyle.wavy || style == PlayerSliderStyle.squiggly) {
      final path = Path();
      final amp = style == PlayerSliderStyle.squiggly ? 4.0 : 3.2;
      final freq = style == PlayerSliderStyle.squiggly ? 0.28 : 0.2;
      for (var i = 0; i <= 40; i++) {
        final x = 6 + ((activeX - 6) * i / 40);
        final y = cy + math.sin((x - 6) * freq) * amp;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, actPaint);
    } else {
      canvas.drawLine(Offset(6, cy), Offset(activeX, cy), actPaint);
    }

    final thumbPaint = Paint()..color = activeColor;
    if (style == PlayerSliderStyle.standard || style == PlayerSliderStyle.squiggly) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(activeX, cy), width: 4.0, height: 18.0),
          const Radius.circular(2),
        ),
        thumbPaint,
      );
    } else if (style == PlayerSliderStyle.wavy) {
      canvas.drawCircle(Offset(activeX, cy), 6.0, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SliderStylePreviewPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.activeColor != activeColor;
  }
}
