import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../screens/detail_screens.dart';
import 'animated_eq.dart';
import 'artwork_image.dart';
import 'liquid_glass.dart';

class MediaCard extends ConsumerStatefulWidget {
  final MusicItem item;
  final List<MusicItem>? contextQueue;
  final double width;
  final String? contextLabel;

  const MediaCard({
    super.key,
    required this.item,
    this.contextQueue,
    this.width = 148,
    this.contextLabel,
  });

  @override
  ConsumerState<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends ConsumerState<MediaCard> {
  bool _pressed = false;

  void _handleTap() {
    final item = widget.item;
    HapticFeedback.selectionClick();
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
      final queue = widget.contextQueue?.where((e) => e.isPlayable).toList();
      ref.read(playerProvider.notifier).playTrack(
            item,
            queue: queue,
            contextName: widget.contextLabel ?? item.album?.name ?? 'Beranda',
          );
    }
  }

  void _handleLongPress() {
    final item = widget.item;
    HapticFeedback.mediumImpact();
    final isLiked = ref.read(libraryProvider).isLiked(item.id);
    final isPinned = ref.read(libraryProvider).isPinnedSpeedDial(item.id);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: ArtworkImage(url: item.bestThumbUrl(size: 160), size: 46, radius: 8),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: ink),
            ),
            subtitle: Text(
              item.artistDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: sub),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.play_arrow_rounded, color: ink),
            title: Text('Putar sekarang', style: TextStyle(color: ink)),
            onTap: () {
              Navigator.pop(ctx);
              _handleTap();
            },
          ),
          if (item.isPlayable) ...[
            ListTile(
              leading: Icon(Icons.queue_play_next_rounded, color: ink),
              title: Text('Putar berikutnya', style: TextStyle(color: ink)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(playerProvider.notifier).playNextInQueue(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.queue_music_rounded, color: ink),
              title: Text('Tambahkan ke antrean', style: TextStyle(color: ink)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(playerProvider.notifier).addToQueue(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.radio_rounded, color: ink),
              title: Text('Mulai radio', style: TextStyle(color: ink)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(playerProvider.notifier).startRadio(item);
              },
            ),
            ListTile(
              leading: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? const Color(0xFFE11D48) : ink,
              ),
              title: Text(isLiked ? 'Hapus dari Disukai' : 'Tambahkan ke Disukai', style: TextStyle(color: ink)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(libraryProvider.notifier).toggleLike(item);
              },
            ),
          ],
          ListTile(
            leading: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.add_rounded,
              color: isPinned ? AppColors.horizonBlue : ink,
            ),
            title: Text(
              isPinned ? 'Lepas dari andalan' : 'Sematkan ke speed dial',
              style: TextStyle(color: ink),
            ),
            onTap: () {
              Navigator.pop(ctx);
              ref.read(libraryProvider.notifier).togglePinSpeedDial(item);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isArtist = item.type == 'artist';
    final isCurrent = ref.watch(
      playerProvider.select((s) => s.currentTrack?.id == item.id),
    );
    final isPlaying = ref.watch(
      playerProvider.select((s) => s.currentTrack?.id == item.id && s.isPlaying),
    );
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    final fallbackType = item.type.isNotEmpty
        ? '${item.type[0].toUpperCase()}${item.type.substring(1)}'
        : 'Musik';
    final subText = item.isPlayable
        ? item.artistDisplay
        : (item.subtitle.isNotEmpty ? item.subtitle : fallbackType);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: widget.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isArtist ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ArtworkImage(
                    url: item.bestThumbUrl(size: 400),
                    size: widget.width,
                    radius: 14,
                    isCircle: isArtist,
                  ),
                  if (isCurrent)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: isPlaying
                          ? MiniSpinningVinyl(
                              artworkUrl: item.bestThumbUrl(size: 140),
                              size: 36,
                              isPlaying: true,
                              accentColor: AppColors.horizonBlue,
                            )
                          : Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(190),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AnimatedEqualizer(
                                  color: Colors.white,
                                  isPlaying: false,
                                  size: 15,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: isArtist ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.24,
                  color: isCurrent ? AppColors.horizonBlue : ink,
                ),
              ),
              if (subText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isArtist ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    fontSize: 12,
                    color: sub,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
