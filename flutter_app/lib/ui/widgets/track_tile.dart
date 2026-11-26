import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
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

  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.onTapOverride,
    this.trailingExtra,
    this.trackNumber,
    this.showArtwork = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final libraryState = ref.watch(libraryProvider);
    final isPlayingThis = playerState.currentTrack?.id == track.id;
    final isLiked = libraryState.isLiked(track.id);
    final isDownloaded = libraryState.isDownloaded(track.id);
    final dlProgress = libraryState.downloadProgress[track.id];

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTapOverride ??
          () {
            HapticFeedback.selectionClick();
            ref.read(playerProvider.notifier).playTrack(track, queue: queue);
          },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showTrackOptions(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isPlayingThis ? Colors.white.withAlpha(22) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isPlayingThis
              ? Border.all(color: AppColors.brandGreenBright.withAlpha(75), width: 0.9)
              : null,
        ),
        child: Row(
          children: [
            if (trackNumber != null && !showArtwork)
              SizedBox(
                width: 32,
                child: Center(
                  child: isPlayingThis
                      ? AnimatedEqualizer(
                          color: AppColors.brandGreenBright,
                          isPlaying: playerState.isPlaying,
                          size: 16,
                        )
                      : Text(
                          '$trackNumber',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
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
                    size: 48,
                    radius: 6,
                  ),
                  if (isPlayingThis)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(165),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: AnimatedEqualizer(
                          color: AppColors.brandGreenBright,
                          isPlaying: playerState.isPlaying,
                          size: 18,
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
                      fontWeight: FontWeight.w600,
                      color: isPlayingThis
                          ? AppColors.brandGreenBright
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (isDownloaded) ...[
                        const Icon(
                          Icons.arrow_circle_down_rounded,
                          size: 14,
                          color: AppColors.brandGreen,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (track.explicit) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withAlpha(48),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'E',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          track.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (dlProgress != null)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandGreen,
                  ),
                ),
              ),
            if (trailingExtra != null) trailingExtra!,
            IconButton(
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isLiked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                size: 20,
                color: isLiked ? AppColors.brandGreen : AppColors.textSecondary,
              ),
              onPressed: () => ref.read(libraryProvider.notifier).toggleLike(track),
              tooltip: isLiked ? 'Remove from Liked Songs' : 'Save to Liked Songs',
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 38),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
              onPressed: () => _showTrackOptions(context, ref),
              tooltip: 'More options',
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, WidgetRef ref) {
    final library = ref.read(libraryProvider);
    final isDownloaded = library.isDownloaded(track.id);
    final isLiked = library.isLiked(track.id);

    showLiquidGlassSheet<void>(
      context: context,
      builder: (sheetCtx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                ListTile(
                  leading: ArtworkImage(url: track.bestThumbUrl(size: 160), size: 48, radius: 6),
                  title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      track.artistDisplay,
                      if (track.duration != null) track.duration!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    isLiked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                    color: isLiked ? AppColors.brandGreen : null,
                  ),
                  title: Text(isLiked ? 'Remove from Liked Songs' : 'Save to Liked Songs'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ref.read(libraryProvider.notifier).toggleLike(track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: const Text('Add to Playlist'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showPlaylistPicker(context, ref);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_play_next_rounded),
                  title: const Text('Play Next'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ref.read(playerProvider.notifier).playNextInQueue(track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Add to Queue'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ref.read(playerProvider.notifier).addToQueue(track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.radio_rounded),
                  title: const Text('Go to Song Radio'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ref.read(playerProvider.notifier).startRadio(track);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isDownloaded ? Icons.delete_outline_rounded : Icons.arrow_circle_down_rounded,
                    color: isDownloaded ? AppColors.error : null,
                  ),
                  title: Text(isDownloaded ? 'Remove Offline Download' : 'Download Offline'),
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
                            const SnackBar(
                              content: Text('Download unavailable right now. Please try again.'),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                if (track.artists.isNotEmpty && track.artists.first.id != null)
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text('View ${track.artists.first.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    leading: const Icon(Icons.album_outlined),
                    title: Text('View ${track.album!.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Share.share(
                      '${track.title} — ${track.artistDisplay}\nhttps://music.youtube.com/watch?v=${track.id}',
                    );
                  },
                ),
              ],
            ),
        );
      },
    );
  }

  void _showPlaylistPicker(BuildContext context, WidgetRef ref) {
    showTrackPlaylistPicker(context, ref, track);
  }
}

void showTrackPlaylistPicker(BuildContext context, WidgetRef ref, MusicItem track) {
  final playlists = ref.read(libraryProvider).playlists;
  showLiquidGlassSheet<void>(
    context: context,
    builder: (ctx) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to playlist', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.brandGreenBright),
                ),
                title: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.queue_music_rounded, color: AppColors.textSecondary),
                  ),
                  title: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${pl.tracks.length} songs'),
                  onTap: () {
                    ref.read(libraryProvider.notifier).addTrackToPlaylist(pl.id, track);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to ${pl.name}')),
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
      title: const Text('New Playlist'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Give your playlist a name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
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
          child: const Text('Create & Add'),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}
