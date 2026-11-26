import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
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
      body: _loading
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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 60),
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
      body: _loading
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
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
      body: _loading
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
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
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Ubah nama playlist'),
                  content: TextField(controller: ctrl, autofocus: true),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    FilledButton(
                      onPressed: () {
                        ref.read(libraryProvider.notifier).renamePlaylist(playlist.id, ctrl.text);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
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
      body: Column(
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
                    padding: const EdgeInsets.all(10),
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
      body: _loading
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
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
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus riwayat?'),
                    content: const Text('Semua daftar lagu baru diputar akan dibersihkan.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                      FilledButton(
                        onPressed: () {
                          ref.read(libraryProvider.notifier).clearHistory();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Hapus'),
            ),
        ],
      ),
      body: recent.isEmpty
          ? Center(
              child: Text('Belum ada riwayat pemutaran.', style: TextStyle(color: sub)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 48),
              itemCount: recent.length,
              itemBuilder: (_, i) => TrackTile(track: recent[i], queue: recent),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
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
                          builder: (_) => const AuthScreen(allowBack: true),
                        ),
                      ),
                      icon: const GoogleLogoIcon(size: 18),
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
    final card = isDark ? AppColors.darkSurface : Colors.white;
    final border = AppColors.borderOf(context);
    final pill = AppColors.pillOf(context);

    final q = _searchCtrl.text.trim().toLowerCase();
    final topTracks = library.top50Tracks
        .where(
          (t) =>
              q.isEmpty ||
              t.title.toLowerCase().contains(q) ||
              t.artistDisplay.toLowerCase().contains(q),
        )
        .toList();
    final totalMin = (library.totalListeningSeconds / 60).round();
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border.withAlpha(150), width: 0.8),
              ),
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
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border.withAlpha(150), width: 0.8),
            ),
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
                              '🔥 Percikan Lunarellys saya sudah $streak hari berturut-turut ($totalMin menit mendengarkan)!',
                            );
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.info_rounded, color: ink, size: 21),
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Tentang Percikan'),
                                content: const Text(
                                  'Putar lagu setiap hari untuk mempertahankan nyala Percikan. Kamu memiliki 5 Pemulihan otomatis jika terlewat satu hari.',
                                ),
                                actions: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Mengerti'),
                                  ),
                                ],
                              ),
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
                    Switch(
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
                  card: card,
                  border: border,
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
                  card: card,
                  border: border,
                  ink: ink,
                  sub: sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (topTracks.isNotEmpty) ...[
            Text('Teratas Saya 50', style: Theme.of(context).textTheme.titleLarge),
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
    required Color card,
    required Color border,
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
            child: Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border.withAlpha(140)),
              ),
              clipBehavior: Clip.antiAlias,
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recap kamu 2026'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total waktu dengar: $totalMin menit'),
            const SizedBox(height: 6),
            Text('Lagu teratas tercatat: ${library.top50Tracks.length} lagu'),
            const SizedBox(height: 6),
            Text('Lagu disukai: ${library.likedSongs.length} lagu'),
            const SizedBox(height: 6),
            Text('Percikan aktif: ${library.currentStreak} hari berturut-turut'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
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
    final card = AppColors.cardOf(context);
    final border = AppColors.borderOf(context);
    final connected = _room != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Dengar bersama')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
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
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
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
    'Vokal jernih': [-2.5, 1.5, 6.5, 4.5, 0.5],
    'Elektronik': [5.5, 3.0, -1.5, 4.0, 6.0],
    'Rock': [4.5, 2.0, -1.0, 3.5, 5.5],
  };

  final Map<String, List<double>> _presets = Map<String, List<double>>.from(_defaultPresets);
  static const List<String> _freqLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
  bool _showPerFreq = false;
  String _headphoneProfile = 'Default / Tanpa profil khusus';

  void _promptSaveCustomPreset(List<double> bands) {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan preset baru'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Contoh: Malam Tenang'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final label = nameCtrl.text.trim().isEmpty ? 'Kustom' : nameCtrl.text.trim();
              setState(() => _presets[label] = List<double>.from(bands));
              ref.read(settingsProvider.notifier).setEqPreset(label, bands);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Preset "$label" disimpan')),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ).whenComplete(nameCtrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bands = settings.eqBands;
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final card = isDark ? AppColors.darkSurface : Colors.white;
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 48),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border.withAlpha(150), width: 0.8),
            ),
            child: SwitchListTile(
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
          Container(
            height: 190,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border.withAlpha(150), width: 0.8),
            ),
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
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Preset',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sub),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final entry = _presets.entries.elementAt(idx);
                final selected = settings.eqPreset == entry.key;
                return ChoiceChip(
                  label: Text(entry.key),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(settingsProvider.notifier)
                      .setEqPreset(entry.key, entry.value),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border.withAlpha(150), width: 0.8),
            ),
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
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border.withAlpha(150), width: 0.8),
            ),
            child: ListTile(
              leading: Icon(Icons.headphones_rounded, color: ink),
              title: Text('Profil headphone', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              subtitle: Text(_headphoneProfile, style: TextStyle(color: sub, fontSize: 12.5)),
              trailing: Icon(Icons.chevron_right_rounded, color: sub),
              onTap: () => _pickHeadphoneProfile(context),
            ),
          ),
        ],
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
          child: Slider(
            min: -12.5,
            max: 12.5,
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

  void _pickHeadphoneProfile(BuildContext context) {
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
                trailing: _headphoneProfile == p
                    ? const Icon(Icons.check_rounded, color: AppColors.horizonBlue)
                    : null,
                onTap: () {
                  setState(() => _headphoneProfile = p);
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
    final leftPad = 36.0;
    final bottomPad = 20.0;
    final topPad = 6.0;
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

    canvas.drawPath(
      path,
      Paint()
        ..color = enabled ? lineColor : lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    if (enabled) {
      final dotPaint = Paint()..color = lineColor;
      for (final p in points) {
        canvas.drawCircle(p, 4.0, dotPaint);
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
    final auth = ref.watch(authProvider);
    final card = AppColors.cardOf(context);
    final border = AppColors.borderOf(context);
    final query = _searchCtrl.text.trim().toLowerCase();

    bool match(String s) => query.isEmpty || s.toLowerCase().contains(query);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari pengaturan...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),

          if (query.isEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _smallAccountBanner(
                    context,
                    bg: AppColors.isDark(context)
                        ? const Color(0xFF28171B)
                        : const Color(0xFFFDF1F2),
                    icon: const YouTubeMusicLogoIcon(size: 32),
                    title: 'YouTube Music',
                    subtitle: 'Sinkronkan pustaka dan playlist',
                    btnLabel: auth.isSignedInGoogle ? 'Tersambung' : 'Masuk',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => auth.isSignedInGoogle
                              ? const ProfileScreen()
                              : const AuthScreen(allowBack: true),
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
                        ? const Color(0xFF14271C)
                        : const Color(0xFFEEF9F2),
                    icon: const SpotifyLogoIcon(size: 32),
                    title: 'Spotify',
                    subtitle: 'Playlist tampil di Pustaka',
                    btnLabel: settings.spotifyConnected ? 'Kelola' : 'Hubungkan',
                    onTap: () {
                      ref.read(settingsProvider.notifier).setSpotifyConnection(
                            connected: !settings.spotifyConnected,
                            displayName: !settings.spotifyConnected ? 'Playlist Spotify' : '',
                          );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Card 1: Audio, Appearance, Language, Lyrics
          _settingsGroupCard(
            card: card,
            border: border,
            children: [
              if (match('Suara dan pemutaran kualitas audio radio antrean'))
                _navRow(
                  context,
                  icon: Icons.play_arrow_rounded,
                  title: 'Suara dan pemutaran',
                  onTap: () => _showPlaybackSettingsSheet(context),
                ),
              if (match('Tampilan kaca datar tema terang gelap warna album'))
                _navRow(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Tampilan',
                  onTap: () => _showAppearanceSheet(context),
                ),
              if (match('Bahasa dan konten indonesia inggris'))
                _navRow(
                  context,
                  icon: Icons.language_rounded,
                  title: 'Bahasa dan konten',
                  onTap: () => _showLanguageSheet(context),
                ),
              if (match('Lirik dan terjemahan ai romanisasi interval'))
                _navRow(
                  context,
                  icon: Icons.translate_rounded,
                  title: 'Lirik dan terjemahan',
                  onTap: () => _showLyricsSettingsSheet(context),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Card 2: Privacy, Storage, Backup
          _settingsGroupCard(
            card: card,
            border: border,
            children: [
              if (match('Privasi dan riwayat tontonan pencarian'))
                _navRow(
                  context,
                  icon: Icons.security_rounded,
                  title: 'Privasi dan riwayat',
                  onTap: () => _showPrivacySheet(context),
                ),
              if (match('Penyimpanan unduhan cache hapus'))
                _navRow(
                  context,
                  icon: Icons.storage_rounded,
                  title: 'Penyimpanan',
                  onTap: () => _showStorageSheet(context),
                ),
              if (match('Cadangan dan impor json ekspor pulihkan'))
                _navRow(
                  context,
                  icon: Icons.history_rounded,
                  title: 'Cadangan dan impor',
                  onTap: () => _showBackupImportSheet(context),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Card 3: Android Auto, Links, About (node setup disembunyikan: 7x ketuk di Tentang + passcode)
          _settingsGroupCard(
            card: card,
            border: border,
            children: [
              if (match('Android Auto mobil'))
                _navRow(
                  context,
                  icon: Icons.directions_car_filled_outlined,
                  title: 'Android Auto',
                  onTap: () {
                    final next = !settings.androidAutoEnabled;
                    ref.read(settingsProvider.notifier).setAndroidAutoEnabled(next);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          next ? 'Integrasi Android Auto diaktifkan' : 'Android Auto dinonaktifkan',
                        ),
                      ),
                    );
                  },
                ),
              if (match('Tautan link youtube music'))
                _navRow(
                  context,
                  icon: Icons.link_rounded,
                  title: 'Tautan',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tautan lunarellys:// & music.youtube.com aktif')),
                    );
                  },
                ),
              if (match('Tentang Lunarellys versi pengembang'))
                _navRow(
                  context,
                  icon: Icons.info_rounded,
                  title: 'Tentang ${AppConfig.appName}',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsGroupCard({
    required Color card,
    required Color border,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i + 1 < children.length) {
        spaced.add(Divider(height: 1, indent: 54, color: border));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Column(children: spaced),
    );
  }

  Widget _navRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: ink, size: 22),
      title: Text(
        title,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: ink),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: sub),
      onTap: onTap,
    );
  }

  Widget _smallAccountBanner(
    BuildContext context, {
    required Color bg,
    required Widget icon,
    required String title,
    required String subtitle,
    required String btnLabel,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderOf(context).withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 44, height: 44, child: FittedBox(child: icon)),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 16),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 34,
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, height: 1.3, color: sub),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF0F1115),
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onTap,
              child: Text(
                btnLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
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
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tampilan', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text('Gaya antarmuka', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AppAppearanceStyle.values.map((s) {
                    return ChoiceChip(
                      label: Text(s.label),
                      selected: st.appearanceStyle == s,
                      onSelected: (_) => n.setAppearanceStyle(s),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Tema warna', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AppThemePreference.values.map((t) {
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: st.themePreference == t,
                      onSelected: (_) => n.setThemePreference(t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Warna adaptif sampul album'),
                  value: st.dynamicAlbumColors,
                  onChanged: n.setDynamicColors,
                ),
                const SizedBox(height: 8),
                const Text('Gaya latar pemutar', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: PlayerBackgroundStyle.values.map((p) {
                    return ChoiceChip(
                      label: Text(p.label),
                      selected: st.playerBackgroundStyle == p,
                      onSelected: (_) => n.setPlayerBackgroundStyle(p),
                    );
                  }).toList(),
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
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Suara dan pemutaran', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text('Kualitas streaming', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AudioQuality.values.map((q) {
                    return ChoiceChip(
                      label: Text(q.label),
                      selected: st.audioQuality == q,
                      onSelected: (_) => n.setAudioQuality(q),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Radio otomatis saat antrean habis'),
                  value: st.autoRadio,
                  onChanged: n.setAutoRadio,
                ),
                SwitchListTile(
                  title: const Text('Lewati otomatis jika lagu gagal dimuat'),
                  value: st.autoSkipOnError,
                  onChanged: n.setAutoSkipOnError,
                ),
                SwitchListTile(
                  title: const Text('Simpan antrean terakhir'),
                  value: st.persistentQueue,
                  onChanged: n.setPersistentQueue,
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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguageOption.values
                .map(
                  (lang) => ListTile(
                    title: Text(lang.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(lang.subtitle),
                    trailing: current == lang
                        ? const Icon(Icons.check_rounded, color: AppColors.horizonBlue)
                        : null,
                    onTap: () {
                      modalRef.read(settingsProvider.notifier).setAppLanguage(lang);
                      Navigator.pop(ctx);
                    },
                  ),
                )
                .toList(),
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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Terjemahan lirik AI'),
                value: st.aiTranslateLyrics,
                onChanged: n.setAiTranslateLyrics,
              ),
              SwitchListTile(
                title: const Text('Romanisasi lirik'),
                value: st.romanizeLyrics,
                onChanged: n.setRomanizeLyrics,
              ),
              SwitchListTile(
                title: const Text('Indikator interval musik'),
                value: st.showIntervalIndicator,
                onChanged: n.setShowIntervalIndicator,
              ),
            ],
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
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Jeda riwayat pemutaran'),
                  value: st.pauseWatchHistory,
                  onChanged: n.setPauseWatchHistory,
                ),
                SwitchListTile(
                  title: const Text('Jeda riwayat pencarian'),
                  value: st.pauseSearchHistory,
                  onChanged: n.setPauseSearchHistory,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: const Text('Hapus riwayat pemutaran'),
                  onTap: () {
                    modalRef.read(libraryProvider.notifier).clearHistory();
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.error),
                  title: const Text('Hapus riwayat pencarian'),
                  onTap: () {
                    modalRef.read(libraryProvider.notifier).clearSearchHistory();
                    Navigator.pop(ctx);
                  },
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Penyimpanan', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lagu terunduh offline'),
              subtitle: Text('${downloads.length} lagu tersimpan di perangkat'),
              trailing: TextButton(
                onPressed: downloads.isEmpty
                    ? null
                    : () async {
                        for (final t in downloads) {
                          await ref.read(libraryProvider.notifier).removeDownload(t.id);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: const Text('Hapus semua'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupImportSheet(BuildContext context) {
    final importCtrl = TextEditingController();
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
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
                hintText: 'Tempel JSON cadangan di sini untuk memulihkan...',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  try {
                    final count = await ref
                        .read(libraryProvider.notifier)
                        .importBackupJson(importCtrl.text.trim());
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Berhasil memulihkan $count item pustaka')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal impor: $e')),
                      );
                    }
                  }
                },
                child: const Text('Impor & Gabungkan'),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(importCtrl.dispose);
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
    final card = isDark ? AppColors.darkSurface : Colors.white;
    final border = AppColors.borderOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
        children: [
          // Top Brand Version Card
          LiquidGlassTap(
            onTap: _handleVersionTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border.withAlpha(150), width: 0.8),
              ),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border.withAlpha(150), width: 0.8),
              ),
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
                stops: const [0.0, 0.56, 1.0],
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
                const Positioned(
                  top: 52,
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
                        'Pengembang',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF4B515B),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: Container(
                    width: 92,
                    height: 92,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(48),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2D333B), Color(0xFF111315)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.terminal_rounded, color: Colors.white, size: 36),
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
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border.withAlpha(150), width: 0.8),
            ),
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
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border.withAlpha(150), width: 0.8),
              ),
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
                          '${AppConfig.appName} dikembangkan dengan inspirasi dari Metrolist, pemutar YouTube Music gratis & open-source dengan sentuhan Liquid Glass.',
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
    );
  }
}
