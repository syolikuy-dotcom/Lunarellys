import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../services/device_permissions_service.dart';
import '../../state/auth_provider.dart';
import '../../state/dynamic_island_provider.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/ios_control_center.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/lunarellys_logo.dart';
import '../widgets/media_card.dart';
import '../widgets/permissions_sheet.dart';
import '../widgets/subscreen_mini_player.dart';
import '../widgets/track_tile.dart';
import 'ytm_login_screen.dart';

// ---------------------------------------------------------------------------
// ARTIST SCREEN
// ---------------------------------------------------------------------------
class ArtistScreen extends ConsumerStatefulWidget {
  final String artistId;
  const ArtistScreen({super.key, required this.artistId});

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  MusicArtistDetail? _artist;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).getArtist(widget.artistId);
      if (mounted) {
        setState(() {
          _artist = res;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(_artist?.name ?? 'Artis')),
      body: SubscreenMiniPlayerLayer(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: ink))
            : _error != null || _artist == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Gagal memuat artis'),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 132),
                  children: [
                    Center(
                      child: ArtworkImage(
                        url: _artist!.bestThumbUrl(size: 600),
                        size: 164,
                        isCircle: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _artist!.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (_artist!.subscribers != null && _artist!.subscribers!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _artist!.subscribers!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: sub),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            final allSongs = _artist!.sections
                                .expand((s) => s.items)
                                .where((t) => t.isPlayable)
                                .toList();
                            if (allSongs.isNotEmpty) {
                              ref.read(playerProvider.notifier).playTrack(
                                    allSongs.first,
                                    queue: allSongs,
                                    contextName: _artist!.name,
                                  );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Putar'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(libraryProvider.notifier)
                              .toggleFollowArtist(_artist!.toMusicItem()),
                          icon: Icon(
                            library.isArtistFollowed(_artist!.id)
                                ? Icons.check_rounded
                                : Icons.person_add_alt_1_rounded,
                          ),
                          label: Text(
                            library.isArtistFollowed(_artist!.id) ? 'Diikuti' : 'Ikuti',
                          ),
                        ),
                      ],
                    ),
                    if (_artist!.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _artist!.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: sub, height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ..._artist!.sections.map((sec) {
                      final allSongs = sec.items.every((e) => e.isPlayable);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sec.title, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 10),
                            if (allSongs)
                              ...sec.items.take(8).map(
                                    (t) => TrackTile(track: t, queue: sec.items),
                                  )
                            else
                              SizedBox(
                                height: 204,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: sec.items.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (_, idx) => MediaCard(
                                    item: sec.items[idx],
                                    width: 142,
                                    contextLabel: _artist!.name,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ALBUM SCREEN
// ---------------------------------------------------------------------------
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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).getAlbum(widget.albumId);
      if (mounted) {
        setState(() {
          _album = res;
          _tracks = res.tracks;
          _continuation = res.continuation;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _continuation == null) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(apiClientProvider).getAlbum(
            widget.albumId,
            continuation: _continuation,
          );
      if (mounted) {
        setState(() {
          _tracks = [..._tracks, ...res.tracks];
          _continuation = res.continuation;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(_album?.title ?? 'Album')),
      body: SubscreenMiniPlayerLayer(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: ink))
            : _error != null || _album == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Gagal memuat album'),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                  children: [
                    Center(
                      child: ArtworkImage(
                        url: _album!.bestThumbUrl(size: 700),
                        size: 204,
                        radius: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _album!.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        _album!.artists.map((a) => a.name).join(', '),
                        if (_album!.year != null) '${_album!.year}',
                      ].where((e) => e.isNotEmpty).join(' · '),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sub),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _tracks.isEmpty
                              ? null
                              : () => ref.read(playerProvider.notifier).playTrack(
                                    _tracks.first,
                                    queue: _tracks,
                                    contextName: _album!.title,
                                  ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Putar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _tracks.isEmpty
                              ? null
                              : () => ref.read(playerProvider.notifier).playShuffled(
                                    _tracks,
                                    contextName: _album!.title,
                                  ),
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Acak'),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => ref
                              .read(libraryProvider.notifier)
                              .toggleSaveAlbum(_album!.toMusicItem()),
                          icon: Icon(
                            library.isAlbumSaved(_album!.id)
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: library.isAlbumSaved(_album!.id) ? AppColors.horizonBlue : ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._tracks.asMap().entries.map(
                          (e) => TrackTile(
                            track: e.value,
                            queue: _tracks,
                            trackNumber: e.key + 1,
                            showArtwork: false,
                          ),
                        ),
                    if (_continuation != null)
                      Center(
                        child: TextButton(
                          onPressed: _loadingMore ? null : _loadMore,
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : const Text('Muat lagu lainnya'),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PLAYLIST SCREEN
// ---------------------------------------------------------------------------
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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).getPlaylist(widget.playlistId);
      if (mounted) {
        setState(() {
          _playlist = res;
          _tracks = res.tracks;
          _continuation = res.continuation;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _continuation == null) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(apiClientProvider).getPlaylist(
            widget.playlistId,
            continuation: _continuation,
          );
      if (mounted) {
        setState(() {
          _tracks = [..._tracks, ...res.tracks];
          _continuation = res.continuation;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(_playlist?.title ?? 'Playlist')),
      body: SubscreenMiniPlayerLayer(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: ink))
            : _error != null || _playlist == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Gagal memuat playlist'),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                  children: [
                    Center(
                      child: ArtworkImage(
                        url: _playlist!.bestThumbUrl(size: 700),
                        size: 204,
                        radius: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _playlist!.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (_playlist!.author != null) _playlist!.author!,
                        '${_tracks.length} lagu',
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sub),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _tracks.isEmpty
                              ? null
                              : () => ref.read(playerProvider.notifier).playTrack(
                                    _tracks.first,
                                    queue: _tracks,
                                    contextName: _playlist!.title,
                                  ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Putar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _tracks.isEmpty
                              ? null
                              : () => ref.read(playerProvider.notifier).playShuffled(
                                    _tracks,
                                    contextName: _playlist!.title,
                                  ),
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Acak'),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => ref
                              .read(libraryProvider.notifier)
                              .toggleSavePlaylist(_playlist!.toMusicItem()),
                          icon: Icon(
                            library.isPlaylistSaved(_playlist!.id)
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: library.isPlaylistSaved(_playlist!.id)
                                ? AppColors.horizonBlue
                                : ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._tracks.map((t) => TrackTile(track: t, queue: _tracks)),
                    if (_continuation != null)
                      Center(
                        child: TextButton(
                          onPressed: _loadingMore ? null : _loadMore,
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : const Text('Muat lebih banyak'),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LOCAL PLAYLIST SCREEN
// ---------------------------------------------------------------------------
class LocalPlaylistScreen extends ConsumerWidget {
  final String playlistId;
  const LocalPlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(libraryProvider.select((s) => s.playlists));
    final playlist = playlists.cast<UserPlaylist?>().firstWhere(
          (p) => p?.id == playlistId,
          orElse: () => null,
        );
    final sub = AppColors.subOf(context);

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: const Center(child: Text('Playlist tidak ditemukan.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              final ctrl = TextEditingController(text: playlist.name);
              showArchysGlassDialog<void>(
                context: context,
                title: const Text('Ubah nama playlist'),
                content: TextField(controller: ctrl, autofocus: true),
                actionsBuilder: (ctx) => [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                  FilledButton(
                    onPressed: () {
                      ref.read(libraryProvider.notifier).renamePlaylist(playlist.id, ctrl.text);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              ).whenComplete(ctrl.dispose);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () async {
              await ref.read(libraryProvider.notifier).deletePlaylist(playlist.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SubscreenMiniPlayerLayer(
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Text('${playlist.tracks.length} lagu', style: TextStyle(color: sub)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: playlist.tracks.isEmpty
                      ? null
                      : () => ref.read(playerProvider.notifier).playTrack(
                            playlist.tracks.first,
                            queue: playlist.tracks,
                            contextName: playlist.name,
                          ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Putar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: playlist.tracks.isEmpty
                      ? null
                      : () => ref.read(playerProvider.notifier).playShuffled(
                            playlist.tracks,
                            contextName: playlist.name,
                          ),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Acak'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: playlist.tracks.isEmpty
                ? Center(
                    child: Text('Playlist masih kosong.', style: TextStyle(color: sub)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 132),
                    itemCount: playlist.tracks.length,
                    itemBuilder: (_, i) {
                      final t = playlist.tracks[i];
                      return TrackTile(
                        track: t,
                        queue: playlist.tracks,
                        trailingExtra: IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 19),
                          onPressed: () => ref
                              .read(libraryProvider.notifier)
                              .removeTrackFromPlaylist(playlist.id, t.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MOOD PLAYLISTS SCREEN
// ---------------------------------------------------------------------------
class MoodPlaylistsScreen extends ConsumerStatefulWidget {
  final MusicMood mood;
  const MoodPlaylistsScreen({super.key, required this.mood});

  @override
  ConsumerState<MoodPlaylistsScreen> createState() => _MoodPlaylistsScreenState();
}

class _MoodPlaylistsScreenState extends ConsumerState<MoodPlaylistsScreen> {
  List<MusicSection> _sections = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .getMoodPlaylists(widget.mood.browseId, widget.mood.params);
      if (mounted) {
        setState(() {
          _sections = res;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.mood.name)),
      body: SubscreenMiniPlayerLayer(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: ink))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
                  itemCount: _sections.length,
                  itemBuilder: (_, idx) {
                    final sec = _sections[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sec.title, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 204,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: sec.items.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) => MediaCard(
                                item: sec.items[i],
                                contextQueue: sec.items.where((e) => e.isPlayable).toList(),
                                width: 142,
                                contextLabel: widget.mood.name,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HISTORY SCREEN ("Riwayat")
// ---------------------------------------------------------------------------
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final recent = library.recentlyPlayed;
    final sub = AppColors.subOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          if (recent.isNotEmpty)
            TextButton(
              onPressed: () {
                showArchysGlassDialog<void>(
                  context: context,
                  title: const Text('Hapus riwayat?'),
                  content: const Text('Semua daftar lagu baru diputar akan dibersihkan.'),
                  actionsBuilder: (ctx) => [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    FilledButton(
                      onPressed: () {
                        ref.read(libraryProvider.notifier).clearHistory();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Hapus'),
                    ),
                  ],
                );
              },
              child: const Text('Hapus'),
            ),
        ],
      ),
      body: SubscreenMiniPlayerLayer(
        child: recent.isEmpty
            ? Center(
                child: Text('Belum ada riwayat pemutaran.', style: TextStyle(color: sub)),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 132),
                itemCount: recent.length,
                itemBuilder: (_, i) => TrackTile(track: recent[i], queue: recent),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PROFILE SCREEN
// ---------------------------------------------------------------------------
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final library = ref.watch(libraryProvider);
    final user = auth.user;
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final card = AppColors.cardOf(context);
    final border = AppColors.borderOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SubscreenMiniPlayerLayer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.horizonBlue,
                  child: Text(
                    user?.initials ?? 'L',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Pendengar Tamu',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.isSignedInGoogle ? (user?.email ?? 'Google Sync Aktif') : 'Profil Perangkat Lokal',
                  style: TextStyle(color: sub),
                ),
                const SizedBox(height: 16),
                if (auth.isSignedInGoogle)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: auth.isSyncing
                              ? null
                              : () => ref.read(libraryProvider.notifier).syncWithCloud(),
                          icon: const Icon(Icons.sync_rounded),
                          label: Text(auth.isSyncing ? 'Menyinkron...' : 'Sinkron sekarang'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).signOut();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Keluar'),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const YouTubeMusicLoginScreen(),
                        ),
                      ),
                      icon: const YouTubeMusicLogoIcon(size: 20),
                      label: const Text('Masuk dengan YouTube Music'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statBadge('Disukai', '${library.likedSongs.length}', ink, sub),
                _statBadge('Playlist', '${library.playlists.length}', ink, sub),
                _statBadge('Diunduh', '${library.downloadedTracks.length}', ink, sub),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _statBadge(String label, String value, Color ink, Color sub) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
        Text(label, style: TextStyle(fontSize: 12.5, color: sub)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// STATS & RECAP SCREEN ("Statistik" + Percikan Card)
// ---------------------------------------------------------------------------
class StatsRecapScreen extends ConsumerStatefulWidget {
  const StatsRecapScreen({super.key});

  @override
  ConsumerState<StatsRecapScreen> createState() => _StatsRecapScreenState();
}

class _StatsRecapScreenState extends ConsumerState<StatsRecapScreen> {
  int _periodIndex = 0; // Berkelanjutan, 1 minggu, 1 bulan
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final border = AppColors.borderOf(context);
    final pill = AppColors.pillOf(context);

    final q = _searchCtrl.text.trim().toLowerCase();
    final totalMin = (library.totalListeningSeconds / 60).round();
    final List<MusicItem> periodSource;
    final int periodMin;
    final String periodLabel;
    if (_periodIndex == 1) {
      final weekly = <String, MusicItem>{};
      for (final t in library.recentlyPlayed.take(20)) {
        weekly.putIfAbsent(t.id, () => t);
      }
      if (weekly.isEmpty) {
        for (final t in library.top50Tracks.take(12)) {
          weekly.putIfAbsent(t.id, () => t);
        }
      }
      periodSource = weekly.values.toList()
        ..sort((a, b) => (library.playCounts[b.id] ?? 1).compareTo(library.playCounts[a.id] ?? 1));
      periodMin = totalMin == 0 ? 0 : (totalMin * 0.28).round().clamp(1, totalMin);
      periodLabel = '7 hari terakhir';
    } else if (_periodIndex == 2) {
      final monthly = <String, MusicItem>{};
      for (final t in [...library.top50Tracks.take(30), ...library.recentlyPlayed.take(25)]) {
        monthly.putIfAbsent(t.id, () => t);
      }
      periodSource = monthly.values.toList()
        ..sort((a, b) => (library.playCounts[b.id] ?? 1).compareTo(library.playCounts[a.id] ?? 1));
      periodMin = totalMin == 0 ? 0 : (totalMin * 0.65).round().clamp(1, totalMin);
      periodLabel = '30 hari terakhir';
    } else {
      periodSource = library.top50Tracks;
      periodMin = totalMin;
      periodLabel = 'Sepanjang waktu';
    }

    final topTracks = periodSource
        .where(
          (t) =>
              q.isEmpty ||
              t.title.toLowerCase().contains(q) ||
              t.artistDisplay.toLowerCase().contains(q),
        )
        .toList();

    // Compute ranked Top Artists from active period tracks + liked songs
    final artistCounts = <String, int>{};
    final artistIds = <String, String?>{};
    final artistArt = <String, String?>{};
    final artistLeadTrack = <String, MusicItem>{};
    for (final t in [...periodSource, ...library.likedSongs.take(20)]) {
      final plays = library.playCounts[t.id] ?? 1;
      final primaryRef = t.artists.isNotEmpty ? t.artists.first : null;
      final name = (primaryRef?.name.trim().isNotEmpty == true)
          ? primaryRef!.name.trim()
          : t.artistDisplay.split(',').first.trim();
      if (name.isEmpty || name == 'Artis tidak diketahui') continue;
      if (q.isNotEmpty && !name.toLowerCase().contains(q)) continue;
      artistCounts[name] = (artistCounts[name] ?? 0) + plays;
      artistIds.putIfAbsent(name, () => primaryRef?.id);
      artistArt.putIfAbsent(name, () => t.bestThumbUrl(size: 240));
      artistLeadTrack.putIfAbsent(name, () => t);
    }
    final topArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final streak = library.currentStreak;
    final nextMilestone = ((streak ~/ 3) + 1) * 3;
    final daysLeft = (nextMilestone - streak).clamp(1, 3);
    final milestoneProgress = ((streak % 3) == 0 ? 1.0 : (streak % 3) / 3.0).clamp(0.08, 1.0);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, color: ink),
            tooltip: 'Cari di statistik',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchCtrl.clear();
            }),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ink),
            tooltip: 'Segarkan statistik',
            onPressed: () {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Statistik diperbarui')),
              );
            },
          ),
        ],
      ),
      body: SubscreenMiniPlayerLayer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 132),
        children: [
          Text(
            'Statistik',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          if (_searching) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Filter lagu atau artis teratas...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Recap 2026 Banner Card matching screenshot 16-24-30-14
          LiquidGlassTap(
            onTap: () => _showRecapSummaryDialog(context, library, totalMin),
            child: LiquidGlassCard(
              radius: 20,
              chromaticAccent: AppColors.horizonBlueSoft,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: ink, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recap kamu 2026',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lagu, artis, dan menit teratas',
                          style: TextStyle(fontSize: 13.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: ink, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Detailed Percikan Streak Card matching screenshot 16-24-30-14
          LiquidGlassCard(
            radius: 24,
            chromaticAccent: const Color(0xFFFF982E),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PercikanFlameIcon(size: 88),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Percikan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: sub,
                            ),
                          ),
                          Text(
                            '$streak',
                            style: TextStyle(
                              fontSize: 38,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          Text(
                            'hari berturut-turut',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.share_rounded, color: ink, size: 21),
                          onPressed: () {
                            Share.share(
                              '🔥 Percikan ${AppConfig.appName} saya sudah $streak hari berturut-turut ($totalMin menit mendengarkan)!',
                            );
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.info_rounded, color: ink, size: 21),
                          onPressed: () {
                            showArchysGlassDialog<void>(
                              context: context,
                              title: const Text('Tentang Percikan'),
                              content: const Text(
                                'Putar lagu setiap hari untuk mempertahankan nyala Percikan. Kamu memiliki 5 Pemulihan otomatis jika terlewat satu hari.',
                              ),
                              actionsBuilder: (ctx) => [
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Mengerti'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Menyala · $daysLeft hari lagi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 8,
                    color: pill,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: milestoneProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF982E),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: pill.withAlpha(180),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _streakStatCell('${library.longestStreak}', 'Terpanjang', ink, sub),
                      ),
                      Expanded(
                        child: _streakStatCell('${library.totalActiveDays}', 'Total hari', ink, sub),
                      ),
                      Expanded(
                        child: _streakStatCell(
                          '${library.streakRecoveryLeft}/5',
                          'Pemulihan',
                          ink,
                          sub,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Streak di Beranda',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                    LiquidGlassToggleSwitch(
                      value: settings.showStreakOnHome,
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setShowStreakOnHome(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Period filter chips matching screenshot 16-24-30-14
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Berkelanjutan'),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ],
                  ),
                  selected: _periodIndex == 0,
                  onSelected: (_) => setState(() => _periodIndex = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('1 minggu'),
                  selected: _periodIndex == 1,
                  onSelected: (_) => setState(() => _periodIndex = 1),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('1 bulan'),
                  selected: _periodIndex == 2,
                  onSelected: (_) => setState(() => _periodIndex = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LiquidGlassCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: _streakStatCell('$periodMin mnt', periodLabel, ink, sub),
                ),
                Expanded(
                  child: _streakStatCell('${topTracks.length}', 'Lagu aktif', ink, sub),
                ),
                Expanded(
                  child: _streakStatCell('${library.likedSongs.length}', 'Disukai', ink, sub),
                ),
              ],
            ),
          ),
          if (topArtists.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Artis Teratas Kamu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topArtists.take(10).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final entry = topArtists[i];
                  final name = entry.key;
                  final plays = entry.value;
                  final thumb = artistArt[name];
                  final aid = artistIds[name];
                  final leadTrack = artistLeadTrack[name];
                  return LiquidGlassTap(
                    onTap: () {
                      if (aid != null && aid.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ArtistScreen(artistId: aid),
                          ),
                        );
                      } else if (leadTrack != null) {
                        ref.read(playerProvider.notifier).playTrack(
                              leadTrack,
                              queue: topTracks,
                              contextName: name,
                            );
                      }
                    },
                    child: SizedBox(
                      width: 88,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: pill,
                                  border: Border.all(color: border.withAlpha(160), width: 1),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: thumb != null && thumb.isNotEmpty
                                    ? ArtworkImage(url: thumb, size: 72, radius: 36)
                                    : Icon(Icons.person_rounded, size: 32, color: sub),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white : const Color(0xFF111315),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '#${i + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          Text(
                            '${plays}x diputar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: sub),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            '${library.playlists.length} playlist',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _mixMiniCard(
                  context,
                  title: 'Terpopuler Bulanan',
                  count: topTracks.length,
                  track: topTracks.isNotEmpty ? topTracks.first : null,
                  queue: topTracks,
                  ink: ink,
                  sub: sub,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _mixMiniCard(
                  context,
                  title: 'Terpopuler Mingguan',
                  count: library.recentlyPlayed.take(15).length,
                  track: library.recentlyPlayed.isNotEmpty
                      ? library.recentlyPlayed.first
                      : null,
                  queue: library.recentlyPlayed.take(15).toList(),
                  ink: ink,
                  sub: sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (topTracks.isNotEmpty) ...[
            Text(
              _periodIndex == 1
                  ? 'Teratas Minggu Ini'
                  : (_periodIndex == 2 ? 'Teratas Bulan Ini' : 'Teratas Saya 50'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...topTracks.take(15).toList().asMap().entries.map(
                  (e) => TrackTile(
                    track: e.value,
                    queue: topTracks,
                    trackNumber: e.key + 1,
                    showArtwork: true,
                    trailingExtra: Text(
                      '${library.playCounts[e.value.id] ?? 1}x',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: sub),
                    ),
                  ),
                ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'Putar lagu untuk mulai menyusun statistik recap kamu.',
                  style: TextStyle(color: sub),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _streakStatCell(String value, String label, Color ink, Color sub) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12.5, color: sub)),
      ],
    );
  }

  Widget _mixMiniCard(
    BuildContext context, {
    required String title,
    required int count,
    required MusicItem? track,
    required List<MusicItem> queue,
    required Color ink,
    required Color sub,
  }) {
    return LiquidGlassTap(
      onTap: track == null
          ? null
          : () => ref.read(playerProvider.notifier).playTrack(
                track,
                queue: queue,
                contextName: title,
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LiquidGlassCard(
              radius: 18,
              child: track != null
                  ? ArtworkImage(url: track.bestThumbUrl(size: 320), size: 220, radius: 18)
                  : Center(
                      child: Icon(Icons.playlist_play_rounded, size: 42, color: sub),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ink),
          ),
          Text('$count lagu', style: TextStyle(fontSize: 12.5, color: sub)),
        ],
      ),
    );
  }

  void _showRecapSummaryDialog(BuildContext context, LibraryState library, int totalMin) {
    final topTrack = library.top50Tracks.isNotEmpty
        ? library.top50Tracks.first
        : (library.recentlyPlayed.isNotEmpty ? library.recentlyPlayed.first : null);
    final topPlayCount = topTrack != null ? (library.playCounts[topTrack.id] ?? 1) : 0;
    final topArtist = topTrack?.artistDisplay.isNotEmpty == true
        ? topTrack!.artistDisplay
        : 'Musisi Favoritmu';

    final pageCtrl = PageController();
    var currentSlide = 0;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup Recap',
      barrierColor: Colors.black.withAlpha(220),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void goSlide(int delta) {
              final next = (currentSlide + delta).clamp(0, 3);
              if (next != currentSlide) {
                HapticFeedback.selectionClick();
                pageCtrl.animateToPage(
                  next,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              } else if (delta > 0 && currentSlide == 3) {
                Navigator.of(ctx).pop();
              }
            }

            final slideGradients = [
              const [Color(0xFF0A2444), Color(0xFF0E1320), Color(0xFF04060A)],
              const [Color(0xFF28124B), Color(0xFF130E24), Color(0xFF050609)],
              const [Color(0xFF0B3B36), Color(0xFF0A1B24), Color(0xFF040609)],
              const [Color(0xFF471F09), Color(0xFF1F100B), Color(0xFF060608)],
            ];

            return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: slideGradients[currentSlide],
                            ),
                          ),
                        ),
                        PageView(
                          controller: pageCtrl,
                          onPageChanged: (idx) =>
                              setModalState(() => currentSlide = idx),
                          children: [
                            // Slide 1: Lagu teratas
                            _recapStorySlide(
                              eyebrow: 'Lagu teratas',
                              headline: topTrack?.title ?? 'Belum ada lagu',
                              subline: topTrack != null
                                  ? topTrack.artistDisplay
                                  : 'Putar lagu favoritmu untuk mengisi Recap',
                              pillLabel: topTrack != null
                                  ? 'Diputar $topPlayCount kali'
                                  : 'Mulai mendengarkan',
                              hero: topTrack != null
                                  ? ArtworkImage(
                                      url: topTrack.bestThumbUrl(size: 500),
                                      size: 210,
                                      radius: 24,
                                      preserveFull: true,
                                    )
                                  : const ArchysHorizonLogo(
                                      size: 130,
                                      color: Colors.white,
                                    ),
                            ),
                            // Slide 2: Artis teratas
                            _recapStorySlide(
                              eyebrow: 'Artis teratas',
                              headline: topArtist,
                              subline:
                                  '${library.top50Tracks.length} lagu teratas tercatat di pustakamu',
                              pillLabel: '${library.followedArtists.length} artis diikuti',
                              hero: Container(
                                width: 168,
                                height: 168,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withAlpha(24),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(80),
                                    width: 1.4,
                                  ),
                                ),
                                child: Center(
                                  child: topTrack != null
                                      ? ClipOval(
                                          child: ArtworkImage(
                                            url: topTrack.bestThumbUrl(size: 400),
                                            size: 160,
                                            radius: 80,
                                          ),
                                        )
                                      : const Icon(
                                          CupertinoIcons.music_mic,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                ),
                              ),
                            ),
                            // Slide 3: Waktu mendengarkan
                            _recapStorySlide(
                              eyebrow: 'Waktu mendengarkan',
                              headline: '$totalMin menit',
                              subline:
                                  '${library.likedSongs.length} lagu disukai · ${library.downloadedTracks.length} unduhan offline',
                              pillLabel: 'Statistik 2026',
                              hero: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.tealAccent.withAlpha(32),
                                  border: Border.all(
                                    color: Colors.tealAccent.withAlpha(110),
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.headphones,
                                  color: Colors.white,
                                  size: 76,
                                ),
                              ),
                            ),
                            // Slide 4: Percikan harian
                            _recapStorySlide(
                              eyebrow: 'Percikan harian',
                              headline: '${library.currentStreak} hari berturut-turut',
                              subline:
                                  'Rekor terbaik: ${library.longestStreak} hari · Total ${library.totalActiveDays} hari aktif',
                              pillLabel: 'Tetap nyalakan apimu',
                              hero: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFF982E).withAlpha(45),
                                  border: Border.all(
                                    color: const Color(0xFFFF982E).withAlpha(140),
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.flame_fill,
                                  color: Color(0xFFFFB347),
                                  size: 84,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Tap Left / Right navigation overlays (excluding top bar)
                        Positioned.fill(
                          top: 78,
                          bottom: 92,
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () => goSlide(-1),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () => goSlide(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Top Story Progress Bars & Brand Header
                        Positioned(
                          top: 14,
                          left: 14,
                          right: 14,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  for (var i = 0; i < 4; i++) ...[
                                    Expanded(
                                      child: Container(
                                        height: 3.2,
                                        decoration: BoxDecoration(
                                          color: i <= currentSlide
                                              ? Colors.white
                                              : Colors.white.withAlpha(65),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                      ),
                                    ),
                                    if (i < 3) const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const ArchysHorizonLogo(
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Recap kamu 2026',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(
                                      CupertinoIcons.xmark,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Bottom Share Action
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 22,
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: () {
                                    Share.share(
                                      'Recap Archys 2026 saya: $totalMin menit mendengar musik, lagu teratas ${topTrack?.title ?? '-'} ($topPlayCount kali putar), dan streak ${library.currentStreak} hari berturut-turut!',
                                    );
                                  },
                                  icon: const Icon(CupertinoIcons.share, size: 18),
                                  label: const Text(
                                    'Bagikan Recap',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(pageCtrl.dispose);
  }

  Widget _recapStorySlide({
    required String eyebrow,
    required String headline,
    required String subline,
    required String pillLabel,
    required Widget hero,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 86, 26, 94),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          hero,
          const SizedBox(height: 26),
          Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: Colors.white.withAlpha(180),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            headline,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subline,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(65)),
            ),
            child: Text(
              pillLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LISTEN TOGETHER SCREEN ("Dengar bersama")
// ---------------------------------------------------------------------------
class ListenTogetherScreen extends ConsumerStatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  ConsumerState<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends ConsumerState<ListenTogetherScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  ListenTogetherRoom? _room;
  bool _isHost = false;
  bool _busy = false;
  String? _statusMsg;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    final name = ref.read(authProvider).user?.name ?? 'Pendengar';
    _userCtrl.text = name;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _userCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectOrHost() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _userCtrl.text.trim().isEmpty ? 'Pendengar' : _userCtrl.text.trim();
    setState(() {
      _busy = true;
      _statusMsg = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      if (code.isNotEmpty) {
        final joined = await api.joinListenTogetherRoom(code, name);
        _startPolling(joined.roomCode);
        setState(() {
          _room = joined;
          _isHost = false;
          _busy = false;
          _statusMsg = 'Terhubung ke ruangan ${joined.roomCode}';
        });
      } else {
        final created = await api.createListenTogetherRoom(name);
        _codeCtrl.text = created.roomCode;
        _startPolling(created.roomCode);
        setState(() {
          _room = created;
          _isHost = true;
          _busy = false;
          _statusMsg = 'Ruangan aktif: ${created.roomCode}';
        });
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _statusMsg = e.toString();
      });
    }
  }

  void _startPolling(String code) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final api = ref.read(apiClientProvider);
        if (_isHost && _room != null) {
          final p = ref.read(playerProvider);
          await api.syncListenTogetherRoom(
            roomCode: code,
            hostToken: _room!.hostToken,
            track: p.currentTrack,
            isPlaying: p.isPlaying,
            positionMs: p.position.inMilliseconds,
          );
        }
        final latest = await api.getListenTogetherState(code);
        if (!mounted) return;
        setState(() => _room = latest);
        if (!_isHost && latest.currentTrack != null) {
          final cur = ref.read(playerProvider).currentTrack;
          if (cur?.id != latest.currentTrack!.id) {
            await ref.read(playerProvider.notifier).playTrack(
                  latest.currentTrack!,
                  contextName: 'Dengar bersama · ${latest.roomCode}',
                );
          }
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final connected = _room != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Dengar bersama')),
      body: SubscreenMiniPlayerLayer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 132),
        children: [
          LiquidGlassCard(
            radius: 24,
            chromaticAccent: connected ? AppColors.horizonBlue : null,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              children: [
                Icon(
                  Icons.groups_rounded,
                  size: 56,
                  color: connected ? AppColors.horizonBlue : ink,
                ),
                const SizedBox(height: 12),
                Text(
                  'Dengar bersama',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 4),
                Text(
                  connected ? 'Terhubung · ${_room!.roomCode} (${_room!.members.length} anggota)' : 'Terputus',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: connected ? AppColors.horizonBlue : sub,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : const Color(0xFF111315),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                    ),
                    onPressed: _busy
                        ? null
                        : () {
                            if (connected) {
                              _pollTimer?.cancel();
                              setState(() {
                                _room = null;
                                _isHost = false;
                                _statusMsg = null;
                              });
                            } else {
                              _connectOrHost();
                            }
                          },
                    child: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : Text(connected ? 'Putuskan' : 'Hubungkan'),
                  ),
                ),
                if (_statusMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(_statusMsg!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: sub)),
                ],
                const SizedBox(height: 22),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama pengguna',
                    hintText: 'Masukkan namamu',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Kode sesi',
                    hintText: 'Kosongkan untuk buat ruang baru',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LiquidGlassCard(
            radius: 20,
            child: ListTile(
              leading: Icon(Icons.settings_outlined, color: ink),
              title: Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
              subtitle: Text('Sinkronkan otomatis putar, jeda & perpindahan lagu', style: TextStyle(color: sub, fontSize: 12.5)),
              trailing: Icon(Icons.chevron_right_rounded, color: sub),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sinkronisasi real-time aktif setiap 3 detik')),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EQUALIZER SCREEN ("Ekualiser")
// ---------------------------------------------------------------------------
class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  static const Map<String, List<double>> _defaultPresets = {
    'Datar': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass kuat': [7.5, 4.5, 0.0, -1.0, 1.5],
    'Treble kuat': [-1.0, 0.5, 2.5, 6.0, 8.5],
    'Vokal jelas': [-2.5, 1.5, 6.5, 4.5, 0.5],
    'Elektronik': [5.5, 3.0, -1.5, 4.0, 6.0],
    'Rock': [4.5, 2.0, -1.0, 3.5, 5.5],
  };

  static const List<String> _freqLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
  bool _showPerFreq = false;

  void _promptSaveCustomPreset(List<double> bands) {
    final nameCtrl = TextEditingController();
    showArchysGlassDialog<void>(
      context: context,
      title: const Text('Simpan preset baru'),
      content: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Contoh: Malam Tenang'),
      ),
      actionsBuilder: (ctx) => [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(
          onPressed: () async {
            final label = nameCtrl.text.trim().isEmpty ? 'Kustom' : nameCtrl.text.trim();
            await ref.read(settingsProvider.notifier).saveCustomEqPreset(label, bands);
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Preset "$label" disimpan permanen')),
              );
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    ).whenComplete(nameCtrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bands = settings.eqBands;
    final allPresets = <String, List<double>>{
      ..._defaultPresets,
      ...settings.customEqPresets,
    };
    final headphoneProfile = settings.eqHeadphoneProfile == 'Bawaan'
        ? 'Default / Tanpa profil khusus'
        : settings.eqHeadphoneProfile;
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final border = AppColors.borderOf(context);

    final bassVal = ((bands[0] + bands[1]) / 2.0).clamp(-12.5, 12.5);
    final vocalVal = bands[2].clamp(-12.5, 12.5);
    final trebleVal = ((bands[3] + bands[4]) / 2.0).clamp(-12.5, 12.5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekualiser'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: ink),
            tooltip: 'Tambah preset baru',
            onPressed: () => _promptSaveCustomPreset(bands),
          ),
        ],
      ),
      body: SubscreenMiniPlayerLayer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
        children: [
          LiquidGlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: LiquidGlassSwitchTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Pakai ekualiser',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
              ),
              subtitle: Text(
                settings.eqEnabled ? 'Aktif (${settings.eqPreset})' : 'Mati',
                style: TextStyle(fontSize: 13, color: sub),
              ),
              value: settings.eqEnabled,
              onChanged: (v) => ref.read(settingsProvider.notifier).setEqEnabled(v),
            ),
          ),
          const SizedBox(height: 14),

          // Live Frequency Curve Painter Card (-12,5 to +12,5 dB across 100, 1k, 10k)
          LiquidGlassCard(
            radius: 22,
            chromaticAccent: settings.eqEnabled ? AppColors.horizonBlue : null,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: SizedBox(
              height: 168,
              child: CustomPaint(
                painter: _EqCurvePainter(
                  bands: bands,
                  enabled: settings.eqEnabled,
                  isDark: isDark,
                  lineColor: ink,
                  gridColor: border,
                  textColor: sub,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Preset',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sub),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final entry = allPresets.entries.elementAt(idx);
                final selected = settings.eqPreset == entry.key;
                final isCustom = settings.customEqPresets.containsKey(entry.key) &&
                    !_defaultPresets.containsKey(entry.key);
                return InputChip(
                  label: Text(entry.key),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(settingsProvider.notifier)
                      .setEqPreset(entry.key, entry.value),
                  onDeleted: isCustom
                      ? () => ref
                          .read(settingsProvider.notifier)
                          .deleteCustomEqPreset(entry.key)
                      : null,
                  deleteIconColor: sub,
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Nada',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sub),
            ),
          ),
          LiquidGlassCard(
            radius: 22,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _toneSlider(
                  label: 'Bass',
                  value: bassVal,
                  ink: ink,
                  sub: sub,
                  onChanged: (v) {
                    final next = List<double>.from(bands);
                    next[0] = v;
                    next[1] = v * 0.7;
                    ref.read(settingsProvider.notifier).setEqPreset('Kustom', next);
                  },
                ),
                _toneSlider(
                  label: 'Vokal',
                  value: vocalVal,
                  ink: ink,
                  sub: sub,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setEqBand(2, v),
                ),
                _toneSlider(
                  label: 'Treble',
                  value: trebleVal,
                  ink: ink,
                  sub: sub,
                  onChanged: (v) {
                    final next = List<double>.from(bands);
                    next[3] = v * 0.75;
                    next[4] = v;
                    ref.read(settingsProvider.notifier).setEqPreset('Kustom', next);
                  },
                ),
                const Divider(height: 20),
                InkWell(
                  onTap: () => setState(() => _showPerFreq = !_showPerFreq),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Atur per frekuensi',
                            style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                          ),
                        ),
                        Text(
                          _showPerFreq ? 'Sembunyikan' : 'Tampilkan',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showPerFreq
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: sub,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showPerFreq) ...[
                  const SizedBox(height: 12),
                  ...List.generate(5, (i) {
                    return _toneSlider(
                      label: _freqLabels[i],
                      value: bands[i],
                      ink: ink,
                      sub: sub,
                      onChanged: (v) => ref.read(settingsProvider.notifier).setEqBand(i, v),
                    );
                  }),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .setEqPreset('Datar', _defaultPresets['Datar']!),
                      child: const Text('Setel ulang'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : const Color(0xFF111315),
                          foregroundColor: isDark ? Colors.black : Colors.white,
                        ),
                        onPressed: () => _promptSaveCustomPreset(bands),
                        child: const Text('Simpan sebagai preset'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Profil headphone
          LiquidGlassCard(
            radius: 20,
            child: ListTile(
              leading: Icon(Icons.headphones_rounded, color: ink),
              title: Text('Profil headphone', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              subtitle: Text(headphoneProfile, style: TextStyle(color: sub, fontSize: 12.5)),
              trailing: Icon(Icons.chevron_right_rounded, color: sub),
              onTap: () => _pickHeadphoneProfile(context, headphoneProfile),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _toneSlider({
    required String label,
    required double value,
    required Color ink,
    required Color sub,
    required ValueChanged<double> onChanged,
  }) {
    final isZero = value.abs() < 0.05;
    final valLabel = isZero
        ? '0 dB'
        : '${value > 0 ? '+' : ''}${value.toStringAsFixed(1).replaceAll('.', ',')} dB';
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
        ),
        Expanded(
          child: LiquidGlassRangeSlider(
            min: -12.5,
            max: 12.5,
            compact: true,
            value: value.clamp(-12.5, 12.5),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            valLabel,
            textAlign: TextAlign.end,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: sub),
          ),
        ),
      ],
    );
  }

  void _pickHeadphoneProfile(BuildContext context, String currentProfile) {
    final profiles = [
      'Default / Tanpa profil khusus',
      'Sony WH-1000XM5 (Balanced Warmth)',
      'Apple AirPods Pro 2 (Crisp Vocal)',
      'Sennheiser HD 600 (Reference Flat)',
      'In-Ear Monitor / IEM Bass Boost',
    ];
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: profiles
            .map(
              (p) => ListTile(
                title: Text(p),
                trailing: currentProfile == p
                    ? const Icon(Icons.check_rounded, color: AppColors.horizonBlue)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setEqHeadphoneProfile(p);
                  Navigator.pop(ctx);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  final List<double> bands;
  final bool enabled;
  final bool isDark;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  _EqCurvePainter({
    required this.bands,
    required this.enabled,
    required this.isDark,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 42.0;
    const bottomPad = 20.0;
    const topPad = 6.0;
    final chartW = size.width - leftPad - 6;
    final chartH = size.height - bottomPad - topPad;
    final midY = topPad + chartH / 2;

    // Subtle shaded lower half below 0 dB matching screenshot 16-24-20-60
    canvas.drawRect(
      Rect.fromLTWH(leftPad, midY, chartW, chartH / 2),
      Paint()..color = isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(14),
    );

    final gridPaint = Paint()
      ..color = gridColor.withAlpha(170)
      ..strokeWidth = 0.7;

    const yLabels = ['12,5', '10', '7,5', '5', '2,5', '0', '-2,5', '-5', '-7,5', '-10', '-12,5'];
    for (var i = 0; i < yLabels.length; i++) {
      final y = topPad + chartH * (i / (yLabels.length - 1));
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + chartW, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: yLabels[i],
          style: TextStyle(fontSize: 9.5, color: textColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }

    // Vertical guide lines for 100, 1k, 10k
    for (final ratio in [0.22, 0.54, 0.88]) {
      final x = leftPad + chartW * ratio;
      canvas.drawLine(Offset(x, topPad), Offset(x, topPad + chartH), gridPaint);
    }

    void drawFreqLabel(String text, double x) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: 10.5, color: textColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 16));
    }

    drawFreqLabel('100', leftPad + chartW * 0.22);
    drawFreqLabel('1k', leftPad + chartW * 0.54);
    drawFreqLabel('10k', leftPad + chartW * 0.88);

    final points = <Offset>[];
    for (var i = 0; i < 5; i++) {
      final x = leftPad + (chartW * i / 4);
      final normalized = enabled ? (bands[i] / 12.5).clamp(-1.0, 1.0) : 0.0;
      final y = midY - normalized * (chartH * 0.48);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // Translucent area fill between curve and 0 dB baseline
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, midY)
      ..lineTo(points.first.dx, midY)
      ..close();
    final areaColor = enabled ? AppColors.horizonBlue : lineColor;
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            areaColor.withAlpha(enabled ? 78 : 26),
            areaColor.withAlpha(12),
          ],
        ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = enabled ? lineColor : lineColor.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    if (enabled) {
      final haloPaint = Paint()..color = AppColors.horizonBlue.withAlpha(64);
      final dotPaint = Paint()..color = lineColor;
      for (final p in points) {
        canvas.drawCircle(p, 6.5, haloPaint);
        canvas.drawCircle(p, 3.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter old) =>
      old.bands != bands || old.enabled != enabled || old.lineColor != lineColor;
}

// ---------------------------------------------------------------------------
// SHARED SERVER & PTERODACTYL NODE SETUP SHEET
// ---------------------------------------------------------------------------
void showAdminNodeSetupSheet(
  BuildContext context,
  WidgetRef ref, {
  String initialPasscode = '',
}) {
  final st = ref.read(settingsProvider);
  final urlCtrl = TextEditingController(text: st.serverUrl);
  final keyCtrl = TextEditingController(text: st.apiKey);
  final passcodeCtrl = TextEditingController(text: initialPasscode);
  String? probeResult;
  bool testing = false;
  bool publishing = false;
  bool obscurePasscode = true;
  bool isManualOverride = st.serverManualOverride;

  showLiquidGlassSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          8,
          18,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server & Node (Pterodactyl)', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'APK baru otomatis sinkron ke server aktif. Admin bisa menerbitkan node baru ke semua APK sekaligus di sini.',
              style: TextStyle(fontSize: 13, color: AppColors.subOf(ctx)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isManualOverride
                    ? Colors.amber.withAlpha(28)
                    : AppColors.horizonBlue.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isManualOverride ? Icons.phonelink_lock_rounded : Icons.sync_rounded,
                    size: 16,
                    color: isManualOverride ? Colors.amber.shade800 : AppColors.horizonBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isManualOverride
                          ? 'Mode lokal aktif (hanya perangkat ini)'
                          : 'Auto-sync aktif (ikut konfigurasi pusat untuk semua APK)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkOf(ctx),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Server Base URL',
                hintText: AppConfig.pterodactylExampleUrl,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyCtrl,
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'API Key (opsional)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passcodeCtrl,
              obscureText: obscurePasscode,
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: 'Admin Passcode',
                helperText: 'Dipakai untuk terapkan ke semua APK',
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePasscode ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setModalState(() => obscurePasscode = !obscurePasscode),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Gunakan Pterodactyl Preset'),
                  onPressed: () => urlCtrl.text = AppConfig.pterodactylExampleUrl,
                ),
                ActionChip(
                  label: const Text('Reset & Auto-Sync'),
                  onPressed: (testing || publishing)
                      ? null
                      : () async {
                          setModalState(() => testing = true);
                          await ref.read(settingsProvider.notifier).resetServerConfig();
                          if (!ctx.mounted) return;
                          final latest = ref.read(settingsProvider);
                          urlCtrl.text = latest.serverUrl;
                          keyCtrl.text = latest.apiKey;
                          setModalState(() {
                            testing = false;
                            isManualOverride = false;
                            probeResult = '🔄 Sinkron ke server pusat: ${latest.serverUrl}';
                          });
                        },
                ),
              ],
            ),
            if (probeResult != null) ...[
              const SizedBox(height: 10),
              Text(probeResult!, style: const TextStyle(fontSize: 12.5)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                  onPressed: (testing || publishing)
                      ? null
                      : () async {
                          setModalState(() => testing = true);
                          final res = await ref.read(apiClientProvider).probeNode(
                                overrideBaseUrl: urlCtrl.text,
                                overrideApiKey: keyCtrl.text,
                              );
                          if (!ctx.mounted) return;
                          setModalState(() {
                            testing = false;
                            probeResult = res.ok
                                ? '✅ ${res.service} v${res.version} (${res.region}) — ${res.message}'
                                : '❌ ${res.message}';
                          });
                        },
                  child: Text(testing ? 'Menguji...' : 'Tes Koneksi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (testing || publishing)
                        ? null
                        : () async {
                            await ref.read(settingsProvider.notifier).setServerConfig(
                                  url: urlCtrl.text,
                                  apiKey: keyCtrl.text,
                                  manualOverride: true,
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Konfigurasi disimpan lokal untuk perangkat ini'),
                                ),
                              );
                            }
                          },
                    child: const Text('Simpan Lokal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (testing || publishing)
                    ? null
                    : () async {
                        final pass = passcodeCtrl.text.trim();
                        if (pass.isEmpty) {
                          setModalState(() {
                            probeResult =
                                '❌ Masukkan Admin Passcode untuk menerapkan node ke semua APK';
                          });
                          return;
                        }
                        setModalState(() {
                          publishing = true;
                          probeResult = null;
                        });
                        try {
                          final saved = await ref.read(apiClientProvider).publishRemoteNodeConfig(
                                passcode: pass,
                                serverUrl: urlCtrl.text,
                                apiKey: keyCtrl.text,
                                bootstrapUrl: urlCtrl.text,
                              );
                          await ref.read(settingsProvider.notifier).setServerConfig(
                                url: saved.serverUrl,
                                apiKey: saved.apiKey,
                                manualOverride: false,
                              );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Node global aktif (${saved.serverUrl}). Semua APK baru otomatis tersambung!',
                                ),
                              ),
                            );
                          }
                        } catch (err) {
                          if (!ctx.mounted) return;
                          setModalState(() {
                            publishing = false;
                            probeResult = '❌ Gagal terapkan global: ${err is MusicApiException ? err.message : err}';
                          });
                        }
                      },
                icon: publishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text(
                  publishing ? 'Menerapkan ke semua APK...' : 'Terapkan ke Semua APK',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(() {
    urlCtrl.dispose();
    keyCtrl.dispose();
    passcodeCtrl.dispose();
  });
}

// ---------------------------------------------------------------------------
// SETTINGS SCREEN ("Pengaturan" + Search)
// ---------------------------------------------------------------------------
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final soundStyle = ref.watch(playerProvider.select((s) => s.soundStyle));
    final auth = ref.watch(authProvider);
    final perms = ref.watch(devicePermissionsProvider);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final pill = AppColors.pillOf(context);
    final query = _searchCtrl.text.trim().toLowerCase();

    bool match(String s) => query.isEmpty || s.toLowerCase().contains(query);

    final qualityShort = switch (settings.audioQuality) {
      AudioQuality.high => 'Tinggi',
      AudioQuality.medium => 'Sedang',
      AudioQuality.low => 'Hemat',
    };
    final appearanceShort =
        settings.appearanceStyle == AppAppearanceStyle.flat
            ? 'Datar'
            : 'Liquid Glass';
    final langShort = settings.appLanguage == AppLanguageOption.en
        ? 'English'
        : 'Indonesia';

    final playbackRows = <Widget>[
      if (match('Suara dan pemutaran kualitas audio radio antrean'))
        _navRow(
          context,
          icon: CupertinoIcons.play_fill,
          iconBg: AppColors.iosPink,
          title: 'Suara dan pemutaran',
          trailingValue: qualityShort,
          onTap: () => _showPlaybackSettingsSheet(context),
        ),
      if (match('Tampilan kaca datar tema terang gelap warna album dynamic island liquid glass'))
        _navRow(
          context,
          icon: CupertinoIcons.sparkles,
          iconBg: AppColors.iosBlue,
          title: 'Tampilan & Gaya iOS',
          trailingValue: appearanceShort,
          trailingBadge: settings.dynamicIslandEnabled ? 'Island' : null,
          onTap: () => _showAppearanceSheet(context),
        ),
      if (match('Pusat Kontrol Control Center volume kaca'))
        _navRow(
          context,
          icon: CupertinoIcons.slider_horizontal_3,
          iconBg: AppColors.iosIndigo,
          title: 'Pusat Kontrol',
          trailingValue: soundStyle.label,
          onTap: () => showIosControlCenter(
            context,
            ref,
            onOpenEqualizer: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EqualizerScreen(),
              ),
            ),
          ),
        ),
      if (match('Bahasa dan konten indonesia inggris'))
        _navRow(
          context,
          icon: CupertinoIcons.globe,
          iconBg: AppColors.iosTeal,
          title: 'Bahasa dan konten',
          trailingValue: langShort,
          onTap: () => _showLanguageSheet(context),
        ),
      if (match('Lirik dan terjemahan ai romanisasi interval'))
        _navRow(
          context,
          icon: CupertinoIcons.quote_bubble_fill,
          iconBg: AppColors.iosOrange,
          title: 'Lirik dan terjemahan',
          trailingValue: settings.aiTranslateLyrics ? 'AI Aktif' : null,
          onTap: () => _showLyricsSettingsSheet(context),
        ),
    ];

    final privacyRows = <Widget>[
      if (match('Perizinan dan latar belakang notifikasi baterai bluetooth mikrofon dynamic island'))
        _navRow(
          context,
          icon: CupertinoIcons.bell_fill,
          iconBg: AppColors.iosRed,
          title: 'Perizinan & Latar Belakang',
          trailingBadge: perms.backgroundReady ? 'Siap' : 'Perlu Izin',
          badgeColor:
              perms.backgroundReady ? AppColors.iosGreen : AppColors.iosOrange,
          onTap: () => showPermissionsAndBackgroundSheet(context, ref),
        ),
      if (match('Privasi dan riwayat tontonan pencarian'))
        _navRow(
          context,
          icon: CupertinoIcons.lock_shield_fill,
          iconBg: AppColors.iosBlue,
          title: 'Privasi dan riwayat',
          onTap: () => _showPrivacySheet(context),
        ),
      if (match('Penyimpanan unduhan cache hapus'))
        _navRow(
          context,
          icon: CupertinoIcons.folder_fill,
          iconBg: const Color(0xFF64748B),
          title: 'Penyimpanan',
          onTap: () => _showStorageSheet(context),
        ),
      if (match('Cadangan dan impor json ekspor pulihkan'))
        _navRow(
          context,
          icon: CupertinoIcons.cloud_fill,
          iconBg: AppColors.iosIndigo,
          title: 'Cadangan dan impor',
          onTap: () => _showBackupImportSheet(context),
        ),
    ];

    final systemRows = <Widget>[
      if (match('Android Auto mobil'))
        _navRow(
          context,
          icon: CupertinoIcons.car_detailed,
          iconBg: AppColors.iosGreen,
          title: 'Android Auto',
          trailingValue: settings.androidAutoEnabled ? 'Aktif' : 'Mati',
          onTap: () {
            final next = !settings.androidAutoEnabled;
            ref.read(settingsProvider.notifier).setAndroidAutoEnabled(next);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  next
                      ? 'Integrasi Android Auto diaktifkan'
                      : 'Android Auto dinonaktifkan',
                ),
              ),
            );
          },
        ),
      if (match('Tautan link youtube music'))
        _navRow(
          context,
          icon: CupertinoIcons.link,
          iconBg: AppColors.iosTeal,
          title: 'Tautan',
          trailingValue: 'Aktif',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tautan archys:// & music.youtube.com aktif'),
              ),
            );
          },
        ),
      if (match('Tentang Archys versi pengembang'))
        _navRow(
          context,
          icon: CupertinoIcons.info_circle_fill,
          iconBg: const Color(0xFF475569),
          title: 'Tentang ${AppConfig.appName}',
          trailingValue: 'v${AppConfig.appVersion}',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            );
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SubscreenMiniPlayerLayer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 132),
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: pill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 15, color: ink),
                decoration: InputDecoration(
                  hintText: 'Cari pengaturan...',
                  hintStyle: TextStyle(color: sub, fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 19,
                    color: sub,
                  ),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            CupertinoIcons.clear_circled_solid,
                            size: 18,
                            color: sub,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (query.isEmpty) ...[
              const IosSectionHeader(
                title: 'Akun & Layanan',
                padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
              ),
              Row(
                children: [
                  Expanded(
                    child: _smallAccountBanner(
                      context,
                      bg: AppColors.isDark(context)
                          ? const Color(0x9928171B)
                          : const Color(0xB8FDF1F2),
                      chromaticAccent: const Color(0xFFFF3B30),
                      icon: const YouTubeMusicLogoIcon(size: 32),
                      title: 'YouTube Music',
                      subtitle: 'Sinkronkan pustaka dan playlist',
                      btnLabel: auth.isSignedInGoogle ? 'Tersambung' : 'Masuk',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => auth.isSignedInGoogle
                                ? const ProfileScreen()
                                : const YouTubeMusicLoginScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _smallAccountBanner(
                      context,
                      bg: AppColors.isDark(context)
                          ? const Color(0x9914271C)
                          : const Color(0xB8EEF9F2),
                      chromaticAccent: const Color(0xFF1DB954),
                      icon: const SpotifyLogoIcon(size: 32),
                      title: 'Spotify',
                      subtitle: 'Playlist tampil di Pustaka',
                      btnLabel:
                          settings.spotifyConnected ? 'Kelola' : 'Hubungkan',
                      onTap: () {
                        ref.read(settingsProvider.notifier).setSpotifyConnection(
                              connected: !settings.spotifyConnected,
                              displayName: !settings.spotifyConnected
                                  ? 'Playlist Spotify'
                                  : '',
                            );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            if (playbackRows.isNotEmpty) ...[
              const IosSectionHeader(
                title: 'Pemutaran & Tampilan',
                padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
              ),
              IosGroupedListCard(
                radius: 20,
                dividerIndent: 58,
                children: playbackRows,
              ),
              const SizedBox(height: 18),
            ],

            if (privacyRows.isNotEmpty) ...[
              const IosSectionHeader(
                title: 'Privasi, Izin & Data',
                padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
              ),
              IosGroupedListCard(
                radius: 20,
                dividerIndent: 58,
                children: privacyRows,
              ),
              const SizedBox(height: 18),
            ],

            if (systemRows.isNotEmpty) ...[
              const IosSectionHeader(
                title: 'Sistem & Informasi',
                padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
              ),
              IosGroupedListCard(
                radius: 20,
                dividerIndent: 58,
                children: systemRows,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _navRow(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required String title,
    String? trailingValue,
    String? trailingBadge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: IosSquircleBadge(icon: icon, color: iconBg),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: ink),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingBadge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? AppColors.iosBlue).withAlpha(28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailingBadge,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: badgeColor ?? AppColors.iosBlue,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ] else if (trailingValue != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                trailingValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: sub,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            CupertinoIcons.chevron_forward,
            color: sub.withAlpha(185),
            size: 16,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _iosSegmentedControl<T>(
    BuildContext context, {
    required List<({T value, String label})> items,
    required T selected,
    required ValueChanged<T> onSelect,
  }) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final trackColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final thumbColor =
        isDark ? const Color(0xFF48484A) : const Color(0xFFFFFFFF);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: items.map((item) {
          final isSel = item.value == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!isSel) {
                  HapticFeedback.selectionClick();
                  onSelect(item.value);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSel ? thumbColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 68 : 22),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? ink : sub,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _smallAccountBanner(
    BuildContext context, {
    required Color bg,
    required Color chromaticAccent,
    required Widget icon,
    required String title,
    required String subtitle,
    required String btnLabel,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return LiquidGlassCard(
      radius: 22,
      tintColor: bg,
      chromaticAccent: chromaticAccent,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 42, height: 42, child: FittedBox(child: icon)),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 15.5),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 34,
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.3, color: sub),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF0F1115),
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: onTap,
              child: Text(
                btnLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAppearanceSheet(BuildContext context) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final st = modalRef.watch(settingsProvider);
          final n = modalRef.read(settingsProvider.notifier);
          final isDark = AppColors.isDark(ctx);
          final ink = AppColors.inkOf(ctx);
          final sub = AppColors.subOf(ctx);
          final isGlass = st.appearanceStyle == AppAppearanceStyle.glass;
          final pct = (st.liquidGlassOpacity * 100).round();
          final modeTag = st.liquidGlassOpacity < 0.25
              ? 'Ultra Clear'
              : (st.liquidGlassOpacity > 0.65 ? 'Tinted' : 'Seimbang');
          final glassPreset = st.liquidGlassOpacity < 0.25
              ? 0
              : (st.liquidGlassOpacity > 0.65 ? 2 : 1);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tampilan & Gaya iOS',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                const IosSectionHeader(
                  title: 'Gaya Permukaan',
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                ),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _iosSegmentedControl<AppAppearanceStyle>(
                            ctx,
                            items: AppAppearanceStyle.values
                                .map((s) => (value: s, label: s.label))
                                .toList(),
                            selected: st.appearanceStyle,
                            onSelect: n.setAppearanceStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            st.appearanceStyle.description,
                            style: TextStyle(fontSize: 12, color: sub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isGlass) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      height: 136,
                      child: LiquidGlassView(
                        realTimeCapture: false,
                        backgroundWidget: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? const [
                                      Color(0xFF0E2A47),
                                      Color(0xFF3A1C5E),
                                      Color(0xFF10404A),
                                    ]
                                  : const [
                                      Color(0xFF6BB4F5),
                                      Color(0xFFA799FF),
                                      Color(0xFF6ED8C8),
                                    ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 16,
                                top: 14,
                                child: Text(
                                  'ARCHYS GLASS LAB',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                    color: Colors.white.withAlpha(175),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 20,
                                bottom: 14,
                                child: Icon(
                                  CupertinoIcons.music_note_2,
                                  size: 42,
                                  color: Colors.white.withAlpha(88),
                                ),
                              ),
                              Positioned(
                                left: 24,
                                bottom: 16,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFF7A1A),
                                        Color(0xFFFF3B6B),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: Center(
                            child: LiquidGlassDraggable(
                              child: LiquidGlassLens(
                                style: LiquidGlassStyle(
                                  shape: const LiquidGlassShape
                                      .continuousRoundedRectangle(
                                    cornerRadius: 24,
                                  ),
                                  specular: LiquidGlassLight.specular(
                                    thickness: 4.0,
                                    intensity: isDark ? 0.72 : 0.90,
                                    oppositeIntensity: 0.38,
                                  ),
                                  refractionIndex: 1.06,
                                  refractionWidth: 7,
                                  magnification: 1.02,
                                  dispersion: 0.08,
                                  saturation: isDark ? 1.14 : 1.22,
                                  blur: (1.6 + 3.2 * st.liquidGlassOpacity)
                                      .clamp(1.4, 4.8),
                                  color: isDark
                                      ? const Color(0xFF141A24).withAlpha(
                                          ui.lerpDouble(24, 148, st.liquidGlassOpacity)!
                                              .round(),
                                        )
                                      : const Color(0xFFFFFFFF).withAlpha(
                                          ui.lerpDouble(42, 176, st.liquidGlassOpacity)!
                                              .round(),
                                        ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.sparkles,
                                        size: 17,
                                        color: ink,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Geser Kaca • $modeTag',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  IosGroupedListCard(
                    radius: 18,
                    dividerIndent: 16,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Intensitas Kaca',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$pct%',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: sub,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LiquidGlassRangeSlider(
                              value: st.liquidGlassOpacity,
                              min: 0.0,
                              max: 1.0,
                              activeColor: AppColors.iosIndigo,
                              onChanged: n.setLiquidGlassOpacity,
                            ),
                            const SizedBox(height: 4),
                            _iosSegmentedControl<int>(
                              ctx,
                              items: const [
                                (value: 0, label: 'Ultra Clear'),
                                (value: 1, label: 'Seimbang'),
                                (value: 2, label: 'Tinted'),
                              ],
                              selected: glassPreset,
                              onSelect: (preset) {
                                final target = switch (preset) {
                                  0 => 0.14,
                                  2 => 0.72,
                                  _ => 0.34,
                                };
                                n.setLiquidGlassOpacity(target);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                const IosSectionHeader(
                  title: 'Tema & Warna',
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                ),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _iosSegmentedControl<AppThemePreference>(
                        ctx,
                        items: AppThemePreference.values
                            .map((t) => (value: t, label: t.label))
                            .toList(),
                        selected: st.themePreference,
                        onSelect: n.setThemePreference,
                      ),
                    ),
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Warna adaptif sampul album'),
                      value: st.dynamicAlbumColors,
                      onChanged: n.setDynamicColors,
                    ),
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Umpan balik haptik iOS'),
                      value: st.hapticsEnabled,
                      onChanged: n.setHapticsEnabled,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const IosSectionHeader(
                  title: 'Ikon Aplikasi',
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                ),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: ArchysAppIconTile(
                        style: AppIconStyle.byKey(st.appIconKey),
                        size: 46,
                      ),
                      title: Text(
                        'Gaya ikon aplikasi',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      subtitle: Text(
                        '${AppIconStyle.byKey(st.appIconKey).label} · 20 gaya tersedia',
                        style: TextStyle(fontSize: 12.5, color: sub),
                      ),
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 16,
                        color: sub,
                      ),
                      onTap: () => _showAppIconPickerSheet(ctx),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const IosSectionHeader(
                  title: 'Dynamic Island & Lock Screen',
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                ),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Dynamic Island (Live Activity)'),
                      subtitle: const Text(
                        'Pil iOS interaktif di bagian atas layar',
                      ),
                      value: st.dynamicIslandEnabled,
                      onChanged: (v) async {
                        await n.setDynamicIslandEnabled(v);
                        if (v) {
                          final ok = await modalRef
                              .read(devicePermissionsProvider.notifier)
                              .requestNotifications();
                          if (ok) {
                            modalRef
                                .read(dynamicIslandEventProvider.notifier)
                                .show(
                                  const DynamicIslandEvent(
                                    icon: CupertinoIcons.music_note_2,
                                    title: 'Dynamic Island Aktif',
                                    subtitle:
                                        'Ketuk untuk buka, tahan untuk Pusat Kontrol',
                                    accent: AppColors.iosBlue,
                                  ),
                                );
                          }
                        }
                      },
                    ),
                    if (st.dynamicIslandEnabled)
                      LiquidGlassSwitchTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        title: const Text('Tampilkan saat jeda'),
                        subtitle: const Text(
                          'Tetap tampilkan kapsul status saat tidak memutar lagu',
                        ),
                        value: st.dynamicIslandAlwaysVisible,
                        onChanged: n.setDynamicIslandAlwaysVisible,
                      ),
                    if (st.dynamicIslandEnabled)
                      LiquidGlassSwitchTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        title: const Text('Tampilkan di luar aplikasi'),
                        subtitle: Text(
                          modalRef.watch(devicePermissionsProvider).overlayGranted
                              ? 'Tetap muncul mengambang saat keluar dari Archys'
                              : 'Butuh izin Tampil di Atas Aplikasi',
                        ),
                        value: st.dynamicIslandSystemOverlay,
                        onChanged: (v) async {
                          await n.setDynamicIslandSystemOverlay(v);
                          if (v) {
                            final perms =
                                modalRef.read(devicePermissionsProvider);
                            if (!perms.overlayGranted) {
                              await modalRef
                                  .read(devicePermissionsProvider.notifier)
                                  .requestOverlayPermission();
                            }
                          }
                        },
                      ),
                    if (st.dynamicIslandEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Posisi Kapsul',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _iosSegmentedControl<String>(
                              ctx,
                              items: const [
                                (value: 'below', label: 'Di Bawah Status'),
                                (value: 'notch', label: 'Menyatu Status'),
                              ],
                              selected: st.dynamicIslandPosition == 'notch'
                                  ? 'notch'
                                  : 'below',
                              onSelect: n.setDynamicIslandPosition,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Preset Tampilan',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: DynamicIslandPreset.values.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final preset = DynamicIslandPreset.values[i];
                                  final sel = st.dynamicIslandPreset == preset;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      n.setDynamicIslandPreset(preset);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? AppColors.iosBlue
                                            : AppColors.pillOf(ctx),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          preset.label,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: sel ? Colors.white : ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Warna Aksen Island',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final val in [
                                  0,
                                  0xFF0A84FF,
                                  0xFF5E5CE6,
                                  0xFFFF2D55,
                                  0xFFFF9F0A,
                                  0xFF30D158,
                                  0xFF32ADE6,
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        n.setDynamicIslandAccentValue(val);
                                      },
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: val == 0
                                              ? AppColors.pillOf(ctx)
                                              : Color(val),
                                          border: st.dynamicIslandAccentValue == val
                                              ? Border.all(color: ink, width: 2.2)
                                              : null,
                                        ),
                                        child: val == 0
                                            ? Icon(
                                                CupertinoIcons.sparkles,
                                                size: 13,
                                                color: ink,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Ukuran Kapsul',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(st.dynamicIslandScale * 100).round()}%',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    color: sub,
                                  ),
                                ),
                              ],
                            ),
                            LiquidGlassRangeSlider(
                              value: st.dynamicIslandScale,
                              min: 0.80,
                              max: 1.25,
                              activeColor: AppColors.iosBlue,
                              onChanged: n.setDynamicIslandScale,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Posisi Vertikal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${st.dynamicIslandYOffset.round()} px',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    color: sub,
                                  ),
                                ),
                              ],
                            ),
                            LiquidGlassRangeSlider(
                              value: st.dynamicIslandYOffset,
                              min: -12.0,
                              max: 36.0,
                              activeColor: AppColors.iosBlue,
                              onChanged: n.setDynamicIslandYOffset,
                            ),
                          ],
                        ),
                      ),
                      LiquidGlassSwitchTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        title: const Text('Lirik di Dynamic Island'),
                        subtitle: const Text(
                          'Tampilkan baris lirik tersinkronisasi di dalam kapsul',
                        ),
                        value: st.dynamicIslandShowLyrics,
                        onChanged: n.setDynamicIslandShowLyrics,
                      ),
                    ],
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Musik & Lirik di Lock Screen'),
                      subtitle: const Text(
                        'Notifikasi lirik layar kunci dengan panel pratinjau cepat',
                      ),
                      value: st.lockScreenLyricsEnabled,
                      onChanged: (v) async {
                        await n.setLockScreenLyricsEnabled(v);
                        if (v) {
                          final perms = modalRef.read(devicePermissionsProvider);
                          if (!perms.notificationsGranted) {
                            await modalRef
                                .read(devicePermissionsProvider.notifier)
                                .requestNotifications();
                          }
                        }
                      },
                    ),
                    if (st.lockScreenLyricsEnabled)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        leading: const IosSquircleBadge(
                          icon: CupertinoIcons.lock_fill,
                          color: AppColors.iosIndigo,
                        ),
                        title: Text(
                          'Pratinjau Lirik Lock Screen',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        trailing: Icon(
                          CupertinoIcons.chevron_forward,
                          size: 16,
                          color: sub,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          modalRef
                              .read(devicePermissionsProvider.notifier)
                              .openLockScreenPreview();
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 16),
                const IosSectionHeader(
                  title: 'Latar Pemutar & Mini Player',
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                ),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pemutar Penuh',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _iosSegmentedControl<PlayerBackgroundStyle>(
                            ctx,
                            items: PlayerBackgroundStyle.values
                                .map(
                                  (p) => (
                                    value: p,
                                    label: p == PlayerBackgroundStyle.glowAnimated
                                        ? 'Glow'
                                        : (p == PlayerBackgroundStyle.liveMesh
                                            ? 'Mesh'
                                            : p.label),
                                  ),
                                )
                                .toList(),
                            selected: st.playerBackgroundStyle,
                            onSelect: n.setPlayerBackgroundStyle,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Mini Player',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _iosSegmentedControl<MiniPlayerBackgroundStyle>(
                            ctx,
                            items: MiniPlayerBackgroundStyle.values
                                .map(
                                  (m) => (
                                    value: m,
                                    label: switch (m) {
                                      MiniPlayerBackgroundStyle.blur => 'Buram',
                                      MiniPlayerBackgroundStyle.dynamic => 'Dinamis',
                                      MiniPlayerBackgroundStyle.glowAnimated => 'Glow',
                                      MiniPlayerBackgroundStyle.liveMesh => 'Mesh',
                                    },
                                  ),
                                )
                                .toList(),
                            selected: st.miniPlayerBackgroundStyle,
                            onSelect: n.setMiniPlayerBackgroundStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPlaybackSettingsSheet(BuildContext context) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final st = modalRef.watch(settingsProvider);
          final n = modalRef.read(settingsProvider.notifier);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suara dan pemutaran',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                const IosSectionHeader(
                  title: 'Kualitas Streaming',
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                ),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _iosSegmentedControl<AudioQuality>(
                        ctx,
                        items: const [
                          (value: AudioQuality.high, label: 'Tinggi'),
                          (value: AudioQuality.medium, label: 'Sedang'),
                          (value: AudioQuality.low, label: 'Hemat'),
                        ],
                        selected: st.audioQuality,
                        onSelect: n.setAudioQuality,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const IosSectionHeader(
                  title: 'Otomasi Antrean',
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                ),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Radio otomatis saat antrean habis'),
                      value: st.autoRadio,
                      onChanged: n.setAutoRadio,
                    ),
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Lewati otomatis jika lagu gagal dimuat'),
                      value: st.autoSkipOnError,
                      onChanged: n.setAutoSkipOnError,
                    ),
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Simpan antrean terakhir'),
                      value: st.persistentQueue,
                      onChanged: n.setPersistentQueue,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final current = modalRef.watch(settingsProvider.select((s) => s.appLanguage));
          final isDark = AppColors.isDark(ctx);
          final checkColor = isDark ? const Color(0xFF0A84FF) : AppColors.iosBlue;
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bahasa dan konten',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: AppLanguageOption.values
                      .map(
                        (lang) => ListTile(
                          title: Text(
                            lang.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(lang.subtitle),
                          trailing: current == lang
                              ? Icon(CupertinoIcons.checkmark_alt, color: checkColor)
                              : null,
                          onTap: () {
                            modalRef
                                .read(settingsProvider.notifier)
                                .setAppLanguage(lang);
                            Navigator.pop(ctx);
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLyricsSettingsSheet(BuildContext context) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final st = modalRef.watch(settingsProvider);
          final n = modalRef.read(settingsProvider.notifier);
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lirik dan terjemahan',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Terjemahan lirik AI'),
                      value: st.aiTranslateLyrics,
                      onChanged: n.setAiTranslateLyrics,
                    ),
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Romanisasi lirik'),
                      value: st.romanizeLyrics,
                      onChanged: n.setRomanizeLyrics,
                    ),
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Indikator interval musik'),
                      value: st.showIntervalIndicator,
                      onChanged: n.setShowIntervalIndicator,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: const Text(
                        'Sumber lirik utama',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(st.lyricsSourceName),
                      trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                      onTap: () {
                        final idx = kLyricsSources.indexOf(st.lyricsSourceName);
                        final next =
                            kLyricsSources[(idx + 1) % kLyricsSources.length];
                        n.setLyricsSourceName(next);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAppIconPickerSheet(BuildContext context) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final currentKey =
              modalRef.watch(settingsProvider.select((s) => s.appIconKey));
          final ink = AppColors.inkOf(ctx);
          final sub = AppColors.subOf(ctx);
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gaya ikon aplikasi',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih dari 20 ikon Archys untuk layar utama',
                  style: TextStyle(fontSize: 13, color: sub),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 360,
                  child: GridView.builder(
                    itemCount: AppIconStyle.presets.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemBuilder: (_, i) {
                      final style = AppIconStyle.presets[i];
                      final selected = currentKey == style.key;
                      return GestureDetector(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          await modalRef
                              .read(settingsProvider.notifier)
                              .setAppIconKey(style.key);
                          await modalRef
                              .read(devicePermissionsProvider.notifier)
                              .setAppIcon(style.key);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ArchysAppIconTile(
                              style: style,
                              size: 58,
                              selected: selected,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              style.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: selected ? AppColors.iosBlue : ink,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Launcher mungkin perlu beberapa detik untuk menampilkan ikon baru.',
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final st = modalRef.watch(settingsProvider);
          final n = modalRef.read(settingsProvider.notifier);
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privasi dan riwayat',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 16,
                  children: [
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Jeda riwayat pemutaran'),
                      value: st.pauseWatchHistory,
                      onChanged: n.setPauseWatchHistory,
                    ),
                    LiquidGlassSwitchTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text('Jeda riwayat pencarian'),
                      value: st.pauseSearchHistory,
                      onChanged: n.setPauseSearchHistory,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                IosGroupedListCard(
                  radius: 18,
                  dividerIndent: 52,
                  children: [
                    ListTile(
                      leading: const Icon(
                        CupertinoIcons.trash,
                        color: AppColors.iosRed,
                        size: 20,
                      ),
                      title: const Text(
                        'Hapus riwayat pemutaran',
                        style: TextStyle(
                          color: AppColors.iosRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        modalRef.read(libraryProvider.notifier).clearHistory();
                        Navigator.pop(ctx);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        CupertinoIcons.clear_circled,
                        color: AppColors.iosRed,
                        size: 20,
                      ),
                      title: const Text(
                        'Hapus riwayat pencarian',
                        style: TextStyle(
                          color: AppColors.iosRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        modalRef
                            .read(libraryProvider.notifier)
                            .clearSearchHistory();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showStorageSheet(BuildContext context) {
    final downloads = ref.read(libraryProvider).downloadedTracks;
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Penyimpanan', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            IosGroupedListCard(
              radius: 18,
              dividerIndent: 16,
              children: [
                ListTile(
                  leading: const IosSquircleBadge(
                    icon: CupertinoIcons.arrow_down_circle_fill,
                    color: AppColors.iosBlue,
                  ),
                  title: const Text(
                    'Lagu terunduh offline',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle:
                      Text('${downloads.length} lagu tersimpan di perangkat'),
                  trailing: TextButton(
                    onPressed: downloads.isEmpty
                        ? null
                        : () async {
                            for (final t in downloads) {
                              await ref
                                  .read(libraryProvider.notifier)
                                  .removeDownload(t.id);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: const Text(
                      'Hapus semua',
                      style: TextStyle(color: AppColors.iosRed),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupImportSheet(BuildContext context) {
    final importCtrl = TextEditingController();
    var busy = false;
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            8,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cadangan dan impor', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final json = ref.read(libraryProvider.notifier).exportBackupJson();
                    Clipboard.setData(ClipboardData(text: json));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cadangan JSON disalin ke papan klip')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Ekspor cadangan ke papan klip'),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: importCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Tempel JSON cadangan, CSV (judul,artis), atau M3U di sini...',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final raw = importCtrl.text.trim();
                          if (raw.isEmpty) return;
                          setSheetState(() => busy = true);
                          try {
                            if (raw.startsWith('{') || raw.startsWith('[')) {
                              final count = await ref
                                  .read(libraryProvider.notifier)
                                  .importBackupJson(raw);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Berhasil memulihkan $count item pustaka'),
                                  ),
                                );
                              }
                            } else {
                              final imported = await _importCsvOrM3u(raw);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Berhasil mengimpor $imported lagu ke playlist baru',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setSheetState(() => busy = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal impor: $e')),
                              );
                            }
                          }
                        },
                  child: busy
                      ? const CupertinoActivityIndicator(radius: 9)
                      : const Text('Impor & Gabungkan (JSON / CSV / M3U)'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(importCtrl.dispose);
  }

  Future<int> _importCsvOrM3u(String raw) async {
    final queries = <String>[];
    final lines = raw.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty);
    final isM3u = raw.contains('#EXTM3U') || raw.contains('#EXTINF');
    for (final line in lines) {
      if (isM3u) {
        if (line.startsWith('#EXTINF')) {
          final commaIdx = line.indexOf(',');
          if (commaIdx != -1 && commaIdx + 1 < line.length) {
            final label = line.substring(commaIdx + 1).trim();
            if (label.isNotEmpty) queries.add(label);
          }
        }
      } else {
        if (line.toLowerCase().startsWith('title,') ||
            line.toLowerCase().startsWith('judul,')) {
          continue;
        }
        final cleaned = line
            .replaceAll('"', '')
            .split(RegExp(r'[,;\t]'))
            .take(2)
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .join(' ');
        if (cleaned.isNotEmpty) queries.add(cleaned);
      }
    }
    if (queries.isEmpty) {
      throw const FormatException('Tidak ada baris lagu CSV/M3U yang dikenali');
    }
    final api = ref.read(apiClientProvider);
    final resolved = <MusicItem>[];
    for (final q in queries.take(30)) {
      try {
        final res = await api.search(q, filter: 'songs');
        if (res.results.isNotEmpty) {
          resolved.add(res.results.first);
        }
      } catch (_) {}
    }
    if (resolved.isEmpty) {
      throw const FormatException('Tidak ada lagu yang cocok ditemukan');
    }
    await ref.read(libraryProvider.notifier).createPlaylist(
          isM3u ? 'Impor M3U' : 'Impor CSV',
          initialTracks: resolved,
        );
    return resolved.length;
  }

}

// ---------------------------------------------------------------------------
// ABOUT SCREEN ("Tentang")
// ---------------------------------------------------------------------------
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _updateStatus = 'Ketuk untuk memeriksa versi node terbaru';
  bool _checking = false;
  int _adminTapCount = 0;
  DateTime? _lastTap;

  // Easter egg tersembunyi: 7x ketuk kartu versi -> minta Admin Passcode ->
  // baru panel Server & Node terbuka. Tidak ada petunjuk/hint apa pun di UI,
  // dan panel tidak pernah terbuka tanpa passcode yang valid di server.
  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastTap == null || now.difference(_lastTap!).inSeconds > 3) {
      _adminTapCount = 1;
    } else {
      _adminTapCount += 1;
    }
    _lastTap = now;

    if (_adminTapCount >= 7) {
      _adminTapCount = 0;
      _openAdminGate();
    }
  }

  Future<void> _openAdminGate() async {
    final ctrl = TextEditingController();
    String? error;
    bool checking = false;
    bool obscure = true;

    final pass = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialogState) => AlertDialog(
          title: const Text('Akses Admin'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  obscureText: obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: 'Admin Passcode',
                    errorText: error,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  onSubmitted: (_) {},
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: checking ? null : () => Navigator.pop(dctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: checking
                  ? null
                  : () async {
                      final value = ctrl.text.trim();
                      if (value.isEmpty) {
                        setDialogState(() => error = 'Passcode kosong');
                        return;
                      }
                      setDialogState(() {
                        checking = true;
                        error = null;
                      });
                      final ok = await ref.read(apiClientProvider).verifyAdminPasscode(
                            passcode: value,
                            candidateUrls: [ref.read(settingsProvider).serverUrl],
                          );
                      if (!dctx.mounted) return;
                      if (ok) {
                        Navigator.pop(dctx, value);
                      } else {
                        setDialogState(() {
                          checking = false;
                          error = 'Passcode tidak valid';
                        });
                      }
                    },
              child: checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Buka'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (pass == null || !mounted) return;
    showAdminNodeSetupSheet(context, ref, initialPasscode: pass);
  }

  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    final res = await ref.read(apiClientProvider).probeNode();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _updateStatus = res.ok
          ? 'Node aktif · ${res.service} v${res.version} (${res.region})'
          : 'Tidak dapat terhubung: ${res.message}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final border = AppColors.borderOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang')),
      body: SubscreenMiniPlayerLayer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
        children: [
          // Top Brand Version Card
          LiquidGlassTap(
            onTap: _handleVersionTap,
            child: LiquidGlassCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
              child: Row(
                children: [
                  const LunarellysHorizonLogo(size: 62),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConfig.appName,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppConfig.appVersion} · ${AppConfig.appBuildTag}',
                          style: TextStyle(fontSize: 14.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Check Updates Pill Card matching screenshot 16-28-51-24
          LiquidGlassTap(
            onTap: _checking ? null : _checkUpdates,
            child: LiquidGlassCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.history_rounded, color: ink, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periksa pembaruan',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: ink),
                        ),
                        if (_updateStatus != 'Ketuk untuk memeriksa versi node terbaru')
                          Text(
                            _updateStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: sub),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: sub),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Atmospheric Monochrome Developer Card matching screenshots 16-28-51-24 & 16-28-56-00
          Container(
            height: 310,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: border.withAlpha(140), width: 0.8),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: isDark
                    ? const [Color(0xFF0A0C10), Color(0xFF282D35), Color(0xFF151920)]
                    : const [Color(0xFF0D0F12), Color(0xFF8C919A), Color(0xFFF3F4F6)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  left: 0,
                  right: 0,
                  height: 240,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 0.85,
                        colors: [
                          Colors.white.withAlpha(90),
                          Colors.white.withAlpha(24),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom contrast backdrop fade for crisp Light & Dark mode legibility
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                const Color(0xFF151920).withAlpha(0),
                                const Color(0xFF151920).withAlpha(230),
                              ]
                            : [
                                const Color(0xFFF3F4F6).withAlpha(0),
                                const Color(0xFFF3F4F6).withAlpha(242),
                              ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: LunarellysHorizonLogo(size: 96),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 132,
                  bottom: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.developerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF111315),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pengembang • Ketuk foto untuk pratinjau',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF3F454E),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: GestureDetector(
                    onTap: () => _showDeveloperPhotoPreview(context),
                    child: Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(56),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/developer_avatar.jpg',
                          fit: BoxFit.cover,
                          width: 86,
                          height: 86,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Media sosial',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sub),
            ),
          ),
          LiquidGlassCard(
            radius: 22,
            child: Column(
              children: [
                ListTile(
                  leading: InstagramLogoIcon(size: 22, color: ink),
                  title: Text('Instagram', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  trailing: Text('@wtf.w4n_', style: TextStyle(color: sub, fontSize: 14)),
                  onTap: () => launchUrl(
                    Uri.parse('https://www.instagram.com/wtf.w4n_/'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                Divider(height: 1, indent: 56, color: border),
                ListTile(
                  leading: TikTokLogoIcon(size: 22, color: ink),
                  title: Text('TikTok', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  trailing: Text('@wtf.w4n_', style: TextStyle(color: sub, fontSize: 14)),
                  onTap: () => launchUrl(
                    Uri.parse('https://www.tiktok.com/@wtf.w4n_/'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Kredit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sub),
            ),
          ),
          LiquidGlassTap(
            onTap: () => launchUrl(
              Uri.parse('https://github.com/syolikuy-dotcom/Lunarellys'),
              mode: LaunchMode.externalApplication,
            ),
            child: LiquidGlassCard(
              radius: 22,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.code_rounded, color: ink, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Berdasarkan Metrolist',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppConfig.appName} dikembangkan dengan inspirasi dari Metrolist, pemutar YouTube Music gratis & open-source.',
                          style: TextStyle(fontSize: 13.5, height: 1.4, color: sub),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: sub),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          LiquidGlassTap(
            onTap: () => launchUrl(
              Uri.parse('https://github.com/syolikuy-dotcom/Lunarellys'),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : const Color(0xFF111315),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    size: 20,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Traktir kopi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                      Text(
                        'Dukung pengembang dengan nominal berapa pun',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.black54 : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showDeveloperPhotoPreview(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/images/developer_avatar.jpg',
                  width: 240,
                  height: 240,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppConfig.developerName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pengembang ${AppConfig.appName} • @wtf.w4n_',
                style: TextStyle(fontSize: 13.5, color: sub),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.instagram.com/wtf.w4n_/'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: InstagramLogoIcon(size: 16, color: ink),
                    label: const Text('Instagram'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : const Color(0xFF111315),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
