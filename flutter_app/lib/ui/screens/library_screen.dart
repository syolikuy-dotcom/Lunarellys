import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/media_card.dart';
import '../widgets/track_tile.dart';
import 'detail_screens.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  static const List<String> _mainTabs = [
    'Semua',
    'Playlist',
    'Lagu',
    'Album',
    'Artis',
    'Episode',
    'Saluran',
    'Diunduh',
  ];

  int _tabIndex = 0;
  int _songSubFilter = 0;
  int _artistSubFilter = 0;
  int _episodeSubFilter = 0;
  String _sortMode = 'Tanggal ditambahkan';
  bool _sortAscending = false;
  bool _gridMode = false;
  bool _showInlineSearch = false;
  final TextEditingController _filterCtrl = TextEditingController();

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final settings = ref.watch(settingsProvider);
    final hasTrack = ref.watch(playerProvider.select((s) => s.currentTrack != null));
    final T = AppStrings.of(settings.appLanguage);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final isDark = AppColors.isDark(context);

    final query = _filterCtrl.text.trim().toLowerCase();

    List<MusicItem> sortTracks(List<MusicItem> input) {
      var list = input
          .where((t) =>
              query.isEmpty || '${t.title} ${t.artistDisplay}'.toLowerCase().contains(query))
          .toList();
      if (_sortMode == 'Judul') {
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      } else if (_sortMode == 'Terbanyak diputar') {
        list.sort(
          (a, b) => (library.playCounts[b.id] ?? 0).compareTo(library.playCounts[a.id] ?? 0),
        );
      }
      if (_sortAscending) {
        list = list.reversed.toList();
      }
      return list;
    }

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Text(
                      T.yourLibrary,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const Spacer(),
                    if (_showInlineSearch)
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: ink),
                        onPressed: () {
                          _filterCtrl.clear();
                          setState(() => _showInlineSearch = false);
                        },
                      ),
                  ],
                ),
              ),

              if (_showInlineSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _filterCtrl,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Filter koleksi di pustaka...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),

              // Underline scrollable tabs
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _mainTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 20),
                  itemBuilder: (context, idx) {
                    final selected = _tabIndex == idx;
                    return GestureDetector(
                      onTap: () => setState(() => _tabIndex = idx),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _mainTabs[idx],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected ? ink : sub,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 2.5,
                            width: selected ? 26 : 0,
                            decoration: BoxDecoration(
                              color: ink,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: AppColors.borderOf(context)),

              if (_tabIndex == 2)
                _subChipBar(
                  labels: const ['Disukai', 'Pustaka', 'Diunggah', 'Diunduh'],
                  selectedIndex: _songSubFilter,
                  onSelected: (i) => setState(() => _songSubFilter = i),
                ),
              if (_tabIndex == 4)
                _subChipBar(
                  labels: const ['Disukai', 'Pustaka'],
                  selectedIndex: _artistSubFilter,
                  onSelected: (i) => setState(() => _artistSubFilter = i),
                ),
              if (_tabIndex == 5)
                _subChipBar(
                  labels: const ['Episode', 'Saluran', 'Diunduh'],
                  selectedIndex: _episodeSubFilter,
                  onSelected: (i) => setState(() => _episodeSubFilter = i),
                ),

              // Sort & view bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
                child: Row(
                  children: [
                    PopupMenuButton<String>(
                      initialValue: _sortMode,
                      onSelected: (v) => setState(() => _sortMode = v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'Tanggal ditambahkan', child: Text('Tanggal ditambahkan')),
                        PopupMenuItem(value: 'Judul', child: Text('Judul')),
                        PopupMenuItem(
                            value: 'Terbanyak diputar', child: Text('Terbanyak diputar')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.pillOf(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sortMode,
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: ink),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _sortAscending = !_sortAscending),
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 19,
                        color: ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _showInlineSearch = !_showInlineSearch),
                      icon: Icon(Icons.search_rounded, size: 22, color: ink),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _gridMode = !_gridMode),
                      icon: Icon(
                        _gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                        size: 21,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _buildTabContent(context, library, sortTracks, T),
              ),
            ],
          ),
        ),

        // Floating '+' circular FAB
        Positioned(
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + (hasTrack ? 156 : 92),
          child: LiquidGlassTap(
            onTap: () => _showCreatePlaylistDialog(context, ref),
            child: LiquidGlassSurface(
              borderRadius: BorderRadius.circular(999),
              blurSigma: 22,
              tintColor: isDark ? Colors.white : AppColors.cardOf(context),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: isDark ? Colors.black : ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _subChipBar({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ChoiceChip(
            label: Text(labels[index]),
            selected: selectedIndex == index,
            onSelected: (_) => onSelected(index),
          );
        },
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    LibraryState library,
    List<MusicItem> Function(List<MusicItem>) sortTracks,
    AppStrings T,
  ) {
    final allCached = <MusicItem>{
      ...library.recentlyPlayed,
      ...library.likedSongs,
      ...library.downloadedTracks,
    }.toList();

    switch (_tabIndex) {
      case 1:
        return _buildPlaylistsBody(context, library);
      case 2:
        final source = switch (_songSubFilter) {
          0 => library.likedSongs,
          1 => allCached,
          2 => const <MusicItem>[],
          _ => library.downloadedTracks,
        };
        return _buildTrackCollectionView(context, sortTracks(source));
      case 3:
        return _buildMediaList(
          context,
          library.savedAlbums,
          emptyMessage: 'Belum ada album tersimpan',
        );
      case 4:
        return _buildMediaList(
          context,
          library.followedArtists,
          emptyMessage: 'Belum ada artis diikuti',
        );
      case 5:
      case 6:
        return Center(
          child: Text(
            _tabIndex == 5 ? 'Belum ada episode tersimpan' : 'Belum ada saluran diikuti',
            style: TextStyle(color: AppColors.subOf(context)),
          ),
        );
      case 7:
        return _buildTrackCollectionView(
          context,
          sortTracks(library.downloadedTracks),
          emptyText: 'Belum ada lagu yang diunduh',
        );
      default: // 0: Semua (matches 16-23-33-52)
        final monthlyTracks = library.top50Tracks;
        final weeklyTracks = library.recentlyPlayed.take(20).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 170),
          children: [
            // Side-by-side large square mix cards: Terpopuler Bulanan & Terpopuler Mingguan
            Row(
              children: [
                Expanded(
                  child: _autoMixGridCard(
                    context,
                    title: 'Terpopuler Bulanan',
                    tracks: monthlyTracks,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _autoMixGridCard(
                    context,
                    title: 'Terpopuler Mingguan',
                    tracks: weeklyTracks,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            Text(
              T.collections,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            _collectionRow(
              context,
              icon: Icons.favorite_rounded,
              title: T.likedSongs,
              onTap: () => _openTracksSheet(context, T.likedSongs, library.likedSongs),
            ),
            _collectionRow(
              context,
              icon: Icons.cloud_off_rounded,
              title: T.downloaded,
              onTap: () =>
                  _openTracksSheet(context, T.downloaded, library.downloadedTracks),
            ),
            _collectionRow(
              context,
              icon: Icons.cloud_done_rounded,
              title: T.cached,
              onTap: () => _openTracksSheet(context, T.cached, allCached),
            ),
            _collectionRow(
              context,
              icon: Icons.format_list_bulleted_rounded,
              title: T.onDevice,
              onTap: () =>
                  _openTracksSheet(context, T.onDevice, library.downloadedTracks),
            ),
            _collectionRow(
              context,
              icon: Icons.trending_up_rounded,
              title: T.myTop50,
              onTap: () => _openTracksSheet(context, T.myTop50, library.top50Tracks),
            ),
            _collectionRow(
              context,
              icon: Icons.upload_rounded,
              title: T.uploaded,
              onTap: () => _openTracksSheet(context, T.uploaded, const []),
            ),

            if (library.playlists.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Playlist Kamu',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (_gridMode)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: library.playlists.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (_, i) => _playlistGridCard(context, library.playlists[i]),
                )
              else
                ...library.playlists.map((pl) => _playlistListTile(context, pl)),
            ],
            if (library.savedPlaylists.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Playlist Tersimpan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...library.savedPlaylists.map(
                (pl) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ArtworkImage(
                      url: pl.bestThumbUrl(size: 160), size: 50, radius: 10),
                  title: Text(pl.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(pl.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => PlaylistScreen(playlistId: pl.id)),
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }

  Widget _autoMixGridCard(
    BuildContext context, {
    required String title,
    required List<MusicItem> tracks,
  }) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final boxBg = isDark ? AppColors.darkSurface : Colors.white;
    final border = AppColors.borderOf(context);

    return LiquidGlassTap(
      onTap: () => _openTracksSheet(context, title, tracks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: boxBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border.withAlpha(isDark ? 120 : 180), width: 0.8),
              ),
              clipBehavior: Clip.antiAlias,
              child: tracks.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.format_list_bulleted_rounded,
                        size: 54,
                        color: sub.withAlpha(180),
                      ),
                    )
                  : tracks.length >= 4
                      ? GridView.count(
                          crossAxisCount: 2,
                          physics: const NeverScrollableScrollPhysics(),
                          children: tracks
                              .take(4)
                              .map(
                                (t) => ArtworkImage(
                                  url: t.bestThumbUrl(size: 200),
                                  size: 90,
                                  radius: 0,
                                ),
                              )
                              .toList(),
                        )
                      : ArtworkImage(
                          url: tracks.first.bestThumbUrl(size: 360),
                          size: 180,
                          radius: 0,
                        ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${tracks.length} lagu',
            style: TextStyle(fontSize: 13, color: sub),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsBody(BuildContext context, LibraryState library) {
    final playlists = library.playlists;
    if (playlists.isEmpty && library.savedPlaylists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.queue_music_rounded, size: 48, color: AppColors.subOf(context)),
              const SizedBox(height: 10),
              Text(
                'Belum ada playlist',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Ketuk tombol + untuk membuat playlist baru.',
                style: TextStyle(color: AppColors.subOf(context)),
              ),
            ],
          ),
        ),
      );
    }

    if (_gridMode) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 170),
        itemCount: playlists.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.84,
        ),
        itemBuilder: (_, i) => _playlistGridCard(context, playlists[i]),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 170),
      children: [
        ...playlists.map((pl) => _playlistListTile(context, pl)),
        ...library.savedPlaylists.map(
          (pl) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ArtworkImage(url: pl.bestThumbUrl(size: 160), size: 50, radius: 10),
            title: Text(pl.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(pl.subtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => PlaylistScreen(playlistId: pl.id)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackCollectionView(
    BuildContext context,
    List<MusicItem> tracks, {
    String emptyText = 'Belum ada lagu di koleksi ini',
  }) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(emptyText, style: TextStyle(color: AppColors.subOf(context))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 170),
      itemCount: tracks.length,
      itemBuilder: (_, i) => TrackTile(track: tracks[i], queue: tracks),
    );
  }

  Widget _buildMediaList(
    BuildContext context,
    List<MusicItem> items, {
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: TextStyle(color: AppColors.subOf(context))),
      );
    }
    if (_gridMode) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 170),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (_, i) => MediaCard(item: items[i], width: 160),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 170),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: ArtworkImage(
            url: item.bestThumbUrl(size: 160),
            size: 52,
            radius: 10,
            isCircle: item.type == 'artist',
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle:
              Text(item.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            if (item.type == 'artist') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => ArtistScreen(artistId: item.id)),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => AlbumScreen(albumId: item.id)),
              );
            }
          },
        );
      },
    );
  }

  Widget _collectionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      leading: Icon(icon, color: ink, size: 22),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5, color: ink),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: sub, size: 22),
      onTap: onTap,
    );
  }

  Widget _playlistListTile(BuildContext context, UserPlaylist pl) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      leading: ArtworkImage(
        url: pl.tracks.isNotEmpty ? pl.tracks.first.bestThumbUrl(size: 160) : null,
        size: 50,
        radius: 10,
      ),
      title: Text(
        pl.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      subtitle:
          Text('Playlist · ${pl.tracks.length} lagu', style: TextStyle(color: sub)),
      trailing: Icon(Icons.chevron_right_rounded, color: sub),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => LocalPlaylistScreen(playlistId: pl.id)),
      ),
    );
  }

  Widget _playlistGridCard(BuildContext context, UserPlaylist pl) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return LiquidGlassTap(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => LocalPlaylistScreen(playlistId: pl.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => ArtworkImage(
                url: pl.tracks.isNotEmpty ? pl.tracks.first.bestThumbUrl(size: 320) : null,
                size: c.maxWidth,
                radius: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pl.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
          Text(
            '${pl.tracks.length} lagu',
            style: TextStyle(fontSize: 12, color: sub),
          ),
        ],
      ),
    );
  }

  void _openTracksSheet(BuildContext context, String title, List<MusicItem> tracks) {
    final ink = AppColors.inkOf(context);
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
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
                  ),
                ),
                if (tracks.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(playerProvider.notifier).playTrack(
                            tracks.first,
                            queue: tracks,
                            contextName: title,
                          );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Putar'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Text('Belum ada lagu di koleksi ini.'),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
                itemCount: tracks.length,
                itemBuilder: (_, i) => TrackTile(track: tracks[i], queue: tracks),
              ),
            ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Masukkan nama playlist'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await ref.read(libraryProvider.notifier).createPlaylist(name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }
}
