import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/track_tile.dart';
import '../widgets/user_avatar_button.dart';
import 'detail_screens.dart';

enum _LibraryFilter { all, playlists, artists, albums, liked, downloads, history }

enum _TrackSort { added, title, artist }

class LibraryScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenDrawer;
  const LibraryScreen({super.key, required this.onOpenDrawer});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;
  _TrackSort _sort = _TrackSort.added;
  bool _gridPlaylists = false;
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MusicItem> _filterAndSort(List<MusicItem> source) {
    final q = _searchCtrl.text.trim().toLowerCase();
    var result = q.isEmpty
        ? List<MusicItem>.from(source)
        : source
            .where((t) =>
                t.title.toLowerCase().contains(q) ||
                t.artistDisplay.toLowerCase().contains(q))
            .toList();

    if (_sort == _TrackSort.title) {
      result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sort == _TrackSort.artist) {
      result.sort((a, b) => a.artistDisplay.toLowerCase().compareTo(b.artistDisplay.toLowerCase()));
    }
    return result;
  }

  String _sortLabel() {
    switch (_sort) {
      case _TrackSort.added:
        return 'Recents';
      case _TrackSort.title:
        return 'Title A–Z';
      case _TrackSort.artist:
        return 'Artist A–Z';
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    return LiquidGlassAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 16,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search in Your Library',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searching = false);
                    },
                  ),
                ),
              )
            : Row(
                children: [
                  UserAvatarButton(size: 34, onTap: widget.onOpenDrawer),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your Library',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: [
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search Library',
              onPressed: () => setState(() => _searching = true),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            tooltip: 'Create Playlist',
            onPressed: () => _showCreatePlaylistDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(_LibraryFilter.all, 'All'),
                const SizedBox(width: 8),
                _filterChip(_LibraryFilter.playlists, 'Playlists'),
                const SizedBox(width: 8),
                _filterChip(_LibraryFilter.artists, 'Artists'),
                const SizedBox(width: 8),
                _filterChip(_LibraryFilter.albums, 'Albums'),
                const SizedBox(width: 8),
                _filterChip(_LibraryFilter.liked, 'Liked Songs'),
                const SizedBox(width: 8),
                _filterChip(_LibraryFilter.downloads, 'Downloads'),
                const SizedBox(width: 8),
                _filterChip(_LibraryFilter.history, 'History'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
            child: Row(
              children: [
                PopupMenuButton<_TrackSort>(
                  initialValue: _sort,
                  onSelected: (val) => setState(() => _sort = val),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          _sortLabel(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _TrackSort.added, child: Text('Recents (Default)')),
                    PopupMenuItem(value: _TrackSort.title, child: Text('Title A–Z')),
                    PopupMenuItem(value: _TrackSort.artist, child: Text('Artist A–Z')),
                  ],
                ),
                const Spacer(),
                if (_filter == _LibraryFilter.all || _filter == _LibraryFilter.playlists)
                  IconButton(
                    icon: Icon(
                      _gridPlaylists ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: _gridPlaylists ? 'List View' : 'Grid View',
                    onPressed: () => setState(() => _gridPlaylists = !_gridPlaylists),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(context, library),
          ),
        ],
      ),
    ),
    );
  }

  Widget _filterChip(_LibraryFilter target, String label) {
    final selected = _filter == target;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = target),
    );
  }

  Widget _buildBody(BuildContext context, LibraryState library) {
    switch (_filter) {
      case _LibraryFilter.liked:
        return _TrackCollectionView(
          tracks: _filterAndSort(library.likedSongs),
          contextLabel: 'Liked Songs',
          emptyTitle: 'Songs you like will appear here',
          emptySub: 'Save songs by tapping the plus icon.',
        );
      case _LibraryFilter.downloads:
        return _TrackCollectionView(
          tracks: _filterAndSort(library.downloadedTracks),
          contextLabel: 'Offline Downloads',
          emptyTitle: 'No offline downloads yet',
          emptySub: 'Download tracks from the options menu to listen offline.',
        );
      case _LibraryFilter.history:
        return _TrackCollectionView(
          tracks: _filterAndSort(library.recentlyPlayed),
          contextLabel: 'Recently Played',
          emptyTitle: 'No listening history yet',
          emptySub: 'Tracks you play will show up here.',
          onClearHistory: library.recentlyPlayed.isNotEmpty
              ? () => _confirmClearHistory(context)
              : null,
        );
      case _LibraryFilter.artists:
        return _buildSavedItemsView(
          items: _filterAndSort(library.followedArtists),
          emptyIcon: Icons.person_outline_rounded,
          emptyTitle: 'Follow your favorite artists',
          emptySub: 'Artists you follow will appear here for quick access.',
        );
      case _LibraryFilter.albums:
        return _buildSavedItemsView(
          items: _filterAndSort(library.savedAlbums),
          emptyIcon: Icons.album_outlined,
          emptyTitle: 'No saved albums yet',
          emptySub: 'Tap the Save button on any album to collect it here.',
        );
      case _LibraryFilter.playlists:
        return _buildPlaylistsOnly(context, library.playlists, library.savedPlaylists);
      case _LibraryFilter.all:
        return _buildAllOverview(context, library);
    }
  }

  Widget _buildSavedItemsView({
    required List<MusicItem> items,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySub,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 42, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(emptyTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(emptySub, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 164),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final isArtist = item.type == 'artist';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: ArtworkImage(
            url: item.bestThumbUrl(size: 160),
            size: 56,
            radius: 6,
            isCircle: isArtist,
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            isArtist ? 'Artist' : item.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () {
            if (isArtist) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ArtistScreen(artistId: item.id)),
              );
            } else if (item.type == 'playlist') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlistId: item.id)),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => AlbumScreen(albumId: item.id)),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAllOverview(BuildContext context, LibraryState library) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filteredPlaylists = q.isEmpty
        ? library.playlists
        : library.playlists.where((p) => p.name.toLowerCase().contains(q)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 164),
      children: [
        _PinnedCollectionTile(
          title: 'Liked Songs',
          subtitle: 'Playlist · ${library.likedSongs.length} songs',
          icon: Icons.favorite_rounded,
          gradient: const [Color(0xFF450AF5), Color(0xFFC4EFD9)],
          onTap: () => setState(() => _filter = _LibraryFilter.liked),
        ),
        const SizedBox(height: 10),
        _PinnedCollectionTile(
          title: 'Offline Downloads',
          subtitle: 'Saved · ${library.downloadedTracks.length} songs',
          icon: Icons.arrow_circle_down_rounded,
          gradient: const [Color(0xFF006450), Color(0xFF1DB954)],
          onTap: () => setState(() => _filter = _LibraryFilter.downloads),
        ),
        if (filteredPlaylists.isNotEmpty || library.savedPlaylists.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildPlaylistCollection(context, filteredPlaylists, library.savedPlaylists),
        ],
        if (library.followedArtists.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...library.followedArtists.take(4).map(
                (artist) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: ArtworkImage(
                    url: artist.bestThumbUrl(size: 160),
                    size: 56,
                    isCircle: true,
                  ),
                  title: Text(artist.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Artist'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ArtistScreen(artistId: artist.id)),
                  ),
                ),
              ),
        ],
        if (library.savedAlbums.isNotEmpty) ...[
          ...library.savedAlbums.take(4).map(
                (album) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: ArtworkImage(
                    url: album.bestThumbUrl(size: 160),
                    size: 56,
                    radius: 6,
                  ),
                  title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Album · ${album.artistDisplay}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => AlbumScreen(albumId: album.id)),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 10),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.add_rounded, size: 28, color: AppColors.textSecondary),
          ),
          title: const Text('Create playlist', style: TextStyle(fontWeight: FontWeight.w600)),
          onTap: () => _showCreatePlaylistDialog(context),
        ),
        if (library.recentlyPlayed.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Recently played', style: Theme.of(context).textTheme.titleLarge),
              ),
              TextButton(
                onPressed: () => setState(() => _filter = _LibraryFilter.history),
                child: const Text('Show all'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...library.recentlyPlayed
              .take(6)
              .map((t) => TrackTile(track: t, queue: library.recentlyPlayed)),
        ],
      ],
    );
  }

  Widget _buildPlaylistsOnly(
    BuildContext context,
    List<UserPlaylist> playlists,
    List<MusicItem> savedPlaylists,
  ) {
    if (playlists.isEmpty && savedPlaylists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.queue_music_rounded, size: 42, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('Create your first playlist', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _showCreatePlaylistDialog(context),
                child: const Text('Create playlist'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 164),
      children: [_buildPlaylistCollection(context, playlists, savedPlaylists)],
    );
  }

  Widget _buildPlaylistCollection(
    BuildContext context,
    List<UserPlaylist> playlists,
    List<MusicItem> savedPlaylists,
  ) {
    if (_gridPlaylists) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: playlists.length + savedPlaylists.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          mainAxisExtent: 232,
        ),
        itemBuilder: (ctx, i) {
          if (i < playlists.length) {
            final pl = playlists[i];
            final coverUrl = pl.tracks.isNotEmpty ? pl.tracks.first.bestThumbUrl(size: 320) : null;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => LocalPlaylistScreen(playlistId: pl.id)),
                );
              },
              child: LayoutBuilder(
                builder: (_, box) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    coverUrl != null
                        ? ArtworkImage(url: coverUrl, size: box.maxWidth.clamp(110.0, 152.0), radius: 8)
                        : Container(
                            width: box.maxWidth.clamp(110.0, 152.0),
                            height: box.maxWidth.clamp(110.0, 152.0),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.queue_music_rounded, size: 40, color: AppColors.textSecondary),
                          ),
                    const SizedBox(height: 8),
                    Text(
                      pl.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Playlist · ${pl.tracks.length} songs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          final saved = savedPlaylists[i - playlists.length];
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlistId: saved.id)),
              );
            },
            child: LayoutBuilder(
              builder: (_, box) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArtworkImage(
                    url: saved.bestThumbUrl(size: 320),
                    size: box.maxWidth.clamp(110.0, 152.0),
                    radius: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    saved.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'Saved · ${saved.subtitle.isNotEmpty ? saved.subtitle : 'Playlist'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        ...playlists.map((pl) {
          final coverUrl = pl.tracks.isNotEmpty ? pl.tracks.first.bestThumbUrl(size: 160) : null;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: coverUrl != null
                ? ArtworkImage(url: coverUrl, size: 56, radius: 6)
                : Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.queue_music_rounded, color: AppColors.textSecondary),
                  ),
            title: Text(
              pl.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Playlist · ${pl.tracks.length} songs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
              onSelected: (action) {
                if (action == 'rename') {
                  _showRenameDialog(context, pl);
                } else if (action == 'delete') {
                  ref.read(libraryProvider.notifier).deletePlaylist(pl.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename Playlist')),
                PopupMenuItem(value: 'delete', child: Text('Delete Playlist')),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LocalPlaylistScreen(playlistId: pl.id),
                ),
              );
            },
          );
        }),
        ...savedPlaylists.map((saved) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: ArtworkImage(url: saved.bestThumbUrl(size: 160), size: 56, radius: 6),
            title: Text(
              saved.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Saved Playlist · ${saved.subtitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlaylistScreen(playlistId: saved.id),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Give your playlist a name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'My Playlist #1'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).createPlaylist(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, UserPlaylist pl) {
    final ctrl = TextEditingController(text: pl.name);
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
              ref.read(libraryProvider.notifier).renamePlaylist(pl.id, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Remove all recently played tracks from your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _PinnedCollectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _PinnedCollectionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: LiquidGlassSurface(
        borderRadius: 16,
        blurSigma: 18,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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

class _TrackCollectionView extends ConsumerWidget {
  final List<MusicItem> tracks;
  final String contextLabel;
  final String emptyTitle;
  final String emptySub;
  final VoidCallback? onClearHistory;

  const _TrackCollectionView({
    required this.tracks,
    required this.contextLabel,
    required this.emptyTitle,
    required this.emptySub,
    this.onClearHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off_rounded, size: 42, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(emptyTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(emptySub, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 164),
      itemCount: tracks.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Text(
                  '${tracks.length} songs',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (onClearHistory != null)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary),
                    tooltip: 'Clear History',
                    onPressed: onClearHistory,
                  ),
                IconButton(
                  icon: const Icon(Icons.shuffle_rounded, color: AppColors.brandGreen),
                  tooltip: 'Shuffle',
                  onPressed: () => ref
                      .read(playerProvider.notifier)
                      .playShuffled(tracks, contextName: contextLabel),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => ref
                      .read(playerProvider.notifier)
                      .playTrack(tracks.first, queue: tracks, contextName: contextLabel),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.brandGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                  ),
                ),
              ],
            ),
          );
        }
        final t = tracks[i - 1];
        return TrackTile(track: t, queue: tracks);
      },
    );
  }
}
