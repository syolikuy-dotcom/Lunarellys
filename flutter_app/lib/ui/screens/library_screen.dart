import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'main_shell.dart';

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
                padding: EdgeInsets.fromLTRB(16, 16 + islandClearance, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        T.yourLibrary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    if (_showInlineSearch)
                      IconButton(
                        icon: Icon(CupertinoIcons.xmark_circle_fill, color: sub),
                        onPressed: () {
                          _filterCtrl.clear();
                          setState(() => _showInlineSearch = false);
                        },
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
                      child: LiquidGlassCapsule(
                        blurSigma: 0,
                        padding: const EdgeInsets.all(9),
                        child: Icon(CupertinoIcons.slider_horizontal_3, size: 19, color: ink),
                      ),
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
                      prefixIcon: Icon(CupertinoIcons.search),
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
                      icon: Icon(CupertinoIcons.search, size: 21, color: ink),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _gridMode = !_gridMode),
                      icon: Icon(
                        _gridMode
                            ? CupertinoIcons.list_bullet
                            : CupertinoIcons.square_grid_2x2_fill,
                        size: 20,
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

        // Floating '+' circular FAB synced with nav capsule collapse
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom +
              (navCollapsed ? (hasTrack ? 84 : 82) : (hasTrack ? 156 : 92)),
          child: LiquidGlassTap(
            onTap: () => _showCreatePlaylistDialog(context, ref),
            child: LiquidGlassSurface(
              borderRadius: BorderRadius.circular(999),
              blurSigma: 28,
              tintColor: isDark ? Colors.white : AppColors.cardOf(context),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Icon(
                  CupertinoIcons.plus,
                  size: 26,
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
            const SizedBox(height: 10),
            LiquidGlassCard(
              radius: 22,
              child: Column(
                children: [
                  _collectionRow(
                    context,
                    icon: CupertinoIcons.heart_fill,
                    badgeColor: AppColors.iosPink,
                    title: T.likedSongs,
                    onTap: () => _openTracksSheet(context, T.likedSongs, library.likedSongs),
                  ),
                  Divider(height: 1, indent: 60, color: AppColors.borderOf(context)),
                  _collectionRow(
                    context,
                    icon: CupertinoIcons.arrow_down_circle_fill,
                    badgeColor: AppColors.iosBlue,
                    title: T.downloaded,
                    onTap: () =>
                        _openTracksSheet(context, T.downloaded, library.downloadedTracks),
                  ),
                  Divider(height: 1, indent: 60, color: AppColors.borderOf(context)),
                  _collectionRow(
                    context,
                    icon: CupertinoIcons.cloud_fill,
                    badgeColor: AppColors.iosIndigo,
                    title: T.cached,
                    onTap: () => _openTracksSheet(context, T.cached, allCached),
                  ),
                  Divider(height: 1, indent: 60, color: AppColors.borderOf(context)),
                  _collectionRow(
                    context,
                    icon: CupertinoIcons.music_note_list,
                    badgeColor: AppColors.iosTeal,
                    title: T.onDevice,
                    onTap: () =>
                        _openTracksSheet(context, T.onDevice, library.downloadedTracks),
                  ),
                  Divider(height: 1, indent: 60, color: AppColors.borderOf(context)),
                  _collectionRow(
                    context,
                    icon: CupertinoIcons.chart_bar_fill,
                    badgeColor: AppColors.iosOrange,
                    title: T.myTop50,
                    onTap: () => _openTracksSheet(context, T.myTop50, library.top50Tracks),
                  ),
                  Divider(height: 1, indent: 60, color: AppColors.borderOf(context)),
                  _collectionRow(
                    context,
                    icon: CupertinoIcons.folder_fill,
                    badgeColor: AppColors.iosGreen,
                    title: T.uploaded,
                    onTap: () => _openTracksSheet(context, T.uploaded, const []),
                  ),
                ],
              ),
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
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return LiquidGlassTap(
      onTap: () => _openTracksSheet(context, title, tracks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: LiquidGlassCard(
              radius: 18,
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
    required Color badgeColor,
    required String title,
    required VoidCallback onTap,
  }) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: IosSquircleBadge(icon: icon, color: badgeColor),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: ink),
      ),
      trailing: Icon(CupertinoIcons.chevron_forward, color: sub, size: 18),
      onTap: onTap,
    );
  }

  Widget _playlistArtworkThumb(BuildContext context, UserPlaylist pl, {required double size, required double radius}) {
    if (pl.tracks.length >= 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: pl.tracks
                .take(4)
                .map(
                  (t) => ArtworkImage(
                    url: t.bestThumbUrl(size: 180),
                    size: size / 2,
                    radius: 0,
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    return ArtworkImage(
      url: pl.tracks.isNotEmpty ? pl.tracks.first.bestThumbUrl(size: 260) : null,
      size: size,
      radius: radius,
    );
  }

  Widget _playlistListTile(BuildContext context, UserPlaylist pl) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      leading: _playlistArtworkThumb(context, pl, size: 50, radius: 10),
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
              builder: (_, c) => _playlistArtworkThumb(
                context,
                pl,
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
    final lib = ref.read(libraryProvider);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    showLiquidGlassSheet<void>(
      context: context,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tambah ke Pustaka',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.pillOf(sheetCtx),
                child: Icon(Icons.playlist_add_rounded, color: ink),
              ),
              title: Text('Buat Playlist Kosong',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              subtitle: Text('Beri nama lalu tambahkan lagu pilihanmu',
                  style: TextStyle(color: sub, fontSize: 12.5)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showPlainNameDialog(context, ref);
              },
            ),
            const Divider(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Smart Mix Otomatis',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sub,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.horizonBlue.withAlpha(35),
                child: const Icon(Icons.trending_up_rounded, color: AppColors.horizonBlue),
              ),
              title: Text('Smart Mix: Top 25 Terbanyak Diputar',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              subtitle: Text('${lib.top50Tracks.take(25).length} lagu paling sering kamu dengar',
                  style: TextStyle(color: sub, fontSize: 12.5)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _generateSmartMixPlaylist(
                  context,
                  ref,
                  title: 'Top 25 Mix',
                  tracks: lib.top50Tracks.take(25).toList(),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE11D48).withAlpha(30),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFFE11D48)),
              ),
              title: Text('Smart Mix: Favorit Acak',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              subtitle: Text('${lib.likedSongs.length} lagu disukai diacak rapi',
                  style: TextStyle(color: sub, fontSize: 12.5)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final shuffled = List<MusicItem>.from(lib.likedSongs)..shuffle();
                await _generateSmartMixPlaylist(
                  context,
                  ref,
                  title: 'Favorit Mix',
                  tracks: shuffled.take(30).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlainNameDialog(BuildContext context, WidgetRef ref) {
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

  Future<void> _generateSmartMixPlaylist(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<MusicItem> tracks,
  }) async {
    if (tracks.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Putar atau sukai beberapa lagu dulu untuk membuat Smart Mix.')),
        );
      }
      return;
    }
    final notifier = ref.read(libraryProvider.notifier);
    final pl = await notifier.createPlaylist(title, initialTracks: tracks);
    if (pl != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Smart Mix "$title" (${pl.tracks.length} lagu) berhasil dibuat')),
      );
    }
  }
}
