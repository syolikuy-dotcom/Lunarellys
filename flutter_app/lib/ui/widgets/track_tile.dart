import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../screens/detail_screens.dart';
import 'animated_eq.dart';
import 'artwork_image.dart';
import 'liquid_glass.dart';

class TrackTile extends ConsumerWidget {
  final MusicItem track;
  final List<MusicItem>? queue;
  final VoidCallback? onTapOverride;
  final Widget? trailingExtra;
  final int? trackNumber;
  final bool showArtwork;
  final bool compact;

  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.onTapOverride,
    this.trailingExtra,
    this.trackNumber,
    this.showArtwork = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final libraryState = ref.watch(libraryProvider);
    final isPlayingThis = playerState.currentTrack?.id == track.id;
    final isDownloaded = libraryState.isDownloaded(track.id);
    final dlProgress = libraryState.downloadProgress[track.id];

    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final isDark = AppColors.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTapOverride ??
          () {
            HapticFeedback.selectionClick();
            ref.read(playerProvider.notifier).playTrack(track, queue: queue);
          },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showTrackOptionsSheet(context, ref, track);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isPlayingThis
              ? (isDark ? Colors.white.withAlpha(18) : AppColors.lightSurfaceMuted)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            if (trackNumber != null && !showArtwork)
              SizedBox(
                width: 32,
                child: Center(
                  child: isPlayingThis
                      ? AnimatedEqualizer(
                          color: ink,
                          isPlaying: playerState.isPlaying,
                          size: 16,
                        )
                      : Text(
                          trackNumber!.toString().padLeft(2, '0'),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: sub,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                ),
              )
            else
              Stack(
                alignment: Alignment.center,
                children: [
                  ArtworkImage(
                    url: track.bestThumbUrl(size: 160),
                    size: compact ? 48 : 50,
                    radius: 8,
                  ),
                  if (isPlayingThis)
                    Container(
                      width: compact ? 48 : 50,
                      height: compact ? 48 : 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: AnimatedEqualizer(
                          color: Colors.white,
                          isPlaying: playerState.isPlaying,
                          size: 17,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isPlayingThis
                          ? (isDark ? Colors.white : AppColors.horizonBlue)
                          : ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (isDownloaded) ...[
                        const Icon(
                          Icons.arrow_circle_down_rounded,
                          size: 13.5,
                          color: AppColors.horizonBlue,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (track.explicit) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: sub.withAlpha(42),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'E',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: sub,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          track.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: sub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (dlProgress != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ink,
                  ),
                ),
              ),
            if (trailingExtra != null) trailingExtra!,
            IconButton(
              constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.more_vert_rounded, size: 20, color: sub),
              onPressed: () => showTrackOptionsSheet(context, ref, track),
              tooltip: 'Opsi lainnya',
            ),
          ],
        ),
      ),
    );
  }
}

void showTrackOptionsSheet(BuildContext context, WidgetRef ref, MusicItem track) {
  final library = ref.read(libraryProvider);
  final isDownloaded = library.isDownloaded(track.id);
  final isLiked = library.isLiked(track.id);
  final isPinned = library.isPinnedSpeedDial(track.id);
  final ink = AppColors.inkOf(context);
  final sub = AppColors.subOf(context);
  final border = AppColors.borderOf(context);

  showLiquidGlassSheet<void>(
    context: context,
    builder: (sheetCtx) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ArtworkImage(url: track.bestThumbUrl(size: 160), size: 50, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          track.artistDisplay,
                          if (track.duration != null) track.duration!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: sub),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ref.read(libraryProvider.notifier).toggleLike(track);
                    Navigator.pop(sheetCtx);
                  },
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? const Color(0xFFE11D48) : ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _quickActionBox(
                  context,
                  icon: Icons.radio_rounded,
                  label: 'Mulai radio',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ref.read(playerProvider.notifier).startRadio(track);
                  },
                ),
                const SizedBox(width: 8),
                _quickActionBox(
                  context,
                  icon: Icons.playlist_add_rounded,
                  label: 'Tambah ke\nplaylist',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    showTrackPlaylistPicker(context, ref, track);
                  },
                ),
                const SizedBox(width: 8),
                _quickActionBox(
                  context,
                  icon: Icons.link_rounded,
                  label: 'Salin link',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: 'https://music.youtube.com/watch?v=${track.id}'),
                    );
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tautan lagu disalin')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _quickActionBox(
                  context,
                  icon: Icons.share_outlined,
                  label: 'Bagikan',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Share.share(
                      '${track.title} — ${track.artistDisplay}\nhttps://music.youtube.com/watch?v=${track.id}',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: border),
            if (track.artists.isNotEmpty && track.artists.first.id != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Lihat artis', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                subtitle: Text(track.artists.first.name, style: TextStyle(color: sub)),
                trailing: Icon(Icons.record_voice_over_outlined, color: ink),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistScreen(artistId: track.artists.first.id!),
                    ),
                  );
                },
              ),
            if (track.album?.id != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Lihat album', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                subtitle: Text(track.album!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: sub)),
                trailing: Icon(Icons.album_outlined, color: ink),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlbumScreen(albumId: track.album!.id!),
                    ),
                  );
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                isLiked ? 'Hapus dari pustaka Disukai' : 'Tambah ke pustaka',
                style: TextStyle(fontWeight: FontWeight.w600, color: ink),
              ),
              trailing: Icon(
                isLiked ? Icons.library_add_check_rounded : Icons.library_add_outlined,
                color: ink,
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                ref.read(libraryProvider.notifier).toggleLike(track);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                isPinned ? 'Lepas dari speed dial' : 'Sematkan ke speed dial',
                style: TextStyle(fontWeight: FontWeight.w600, color: ink),
              ),
              trailing: Icon(
                isPinned ? Icons.push_pin_rounded : Icons.add_rounded,
                color: isPinned ? AppColors.horizonBlue : ink,
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                ref.read(libraryProvider.notifier).togglePinSpeedDial(track);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Putar berikutnya', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
              trailing: Icon(Icons.queue_play_next_rounded, color: ink),
              onTap: () {
                Navigator.pop(sheetCtx);
                ref.read(playerProvider.notifier).playNextInQueue(track);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Tambahkan ke antrean', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
              trailing: Icon(Icons.queue_music_rounded, color: ink),
              onTap: () {
                Navigator.pop(sheetCtx);
                ref.read(playerProvider.notifier).addToQueue(track);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                isDownloaded ? 'Hapus unduhan offline' : 'Unduh',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDownloaded ? AppColors.error : ink,
                ),
              ),
              trailing: Icon(
                isDownloaded ? Icons.delete_outline_rounded : Icons.download_rounded,
                color: isDownloaded ? AppColors.error : ink,
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (isDownloaded) {
                  await ref.read(libraryProvider.notifier).removeDownload(track.id);
                } else {
                  try {
                    await ref.read(libraryProvider.notifier).downloadTrack(track);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unduhan belum tersedia saat ini.')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _quickActionBox(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  final ink = AppColors.inkOf(context);
  final pill = AppColors.pillOf(context);
  return Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: pill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: ink),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showTrackPlaylistPicker(BuildContext context, WidgetRef ref, MusicItem track) {
  final playlists = ref.read(libraryProvider).playlists;
  final ink = AppColors.inkOf(context);
  final sub = AppColors.subOf(context);
  final pill = AppColors.pillOf(context);

  showLiquidGlassSheet<void>(
    context: context,
    builder: (ctx) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tambah ke playlist', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_rounded, color: ink),
              ),
              title: Text('Playlist Baru', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              onTap: () {
                Navigator.pop(ctx);
                _showQuickCreatePlaylist(context, ref, track);
              },
            ),
            if (playlists.isNotEmpty) const Divider(height: 12),
            ...playlists.map(
              (pl) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.queue_music_rounded, color: sub),
                ),
                title: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink)),
                subtitle: Text('${pl.tracks.length} lagu', style: TextStyle(color: sub)),
                onTap: () {
                  ref.read(libraryProvider.notifier).addTrackToPlaylist(pl.id, track);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ditambahkan ke ${pl.name}')),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showQuickCreatePlaylist(BuildContext context, WidgetRef ref, MusicItem track) {
  final ctrl = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Playlist Baru'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Beri nama playlist kamu'),
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
            final updated = ref.read(libraryProvider).playlists;
            if (updated.isNotEmpty) {
              await ref.read(libraryProvider.notifier).addTrackToPlaylist(updated.last.id, track);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Buat & Tambah'),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}
