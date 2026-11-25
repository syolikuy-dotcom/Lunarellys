import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../screens/detail_screens.dart';
import 'animated_eq.dart';
import 'artwork_image.dart';

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
            contextName: widget.contextLabel ?? item.album?.name ?? 'Home',
          );
    }
  }

  void _handleLongPress() {
    final item = widget.item;
    if (!item.isPlayable) return;
    HapticFeedback.mediumImpact();
    final isLiked = ref.read(libraryProvider).isLiked(item.id);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
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
                leading: ArtworkImage(url: item.bestThumbUrl(size: 160), size: 46, radius: 6),
                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(item.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded, color: AppColors.brandGreenBright),
                title: const Text('Play Now'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleTap();
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_play_next_rounded),
                title: const Text('Play Next'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(playerProvider.notifier).playNextInQueue(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Add to Queue'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(playerProvider.notifier).addToQueue(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.radio_rounded),
                title: const Text('Start Song Radio'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(playerProvider.notifier).startRadio(item);
                },
              ),
              ListTile(
                leading: Icon(
                  isLiked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  color: isLiked ? AppColors.brandGreenBright : null,
                ),
                title: Text(isLiked ? 'Remove from Liked Songs' : 'Save to Liked Songs'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(libraryProvider.notifier).toggleLike(item);
                },
              ),
            ],
          ),
        ),
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

    final fallbackType = item.type.isNotEmpty
        ? '${item.type[0].toUpperCase()}${item.type.substring(1)}'
        : 'Music';
    final sub = item.isPlayable
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
                    radius: 8,
                    isCircle: isArtist,
                  ),
                  if (item.isPlayable)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.brandGreenBright : Colors.black.withAlpha(190),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: isCurrent
                            ? Center(
                                child: AnimatedEqualizer(
                                  color: Colors.black,
                                  isPlaying: isPlaying,
                                  size: 16,
                                ),
                              )
                            : const Icon(
                                Icons.play_arrow_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: isArtist ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: isCurrent ? AppColors.brandGreenBright : AppColors.textPrimary,
                ),
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isArtist ? TextAlign.center : TextAlign.start,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
