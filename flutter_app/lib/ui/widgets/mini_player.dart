import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'artwork_image.dart';
import 'marquee_text.dart';

class WithMiniPlayer extends ConsumerWidget {
  final Widget child;
  const WithMiniPlayer({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(playerProvider.select((s) => s.currentTrack != null));
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: IgnorePointer(
              ignoring: !hasTrack,
              child: AnimatedSlide(
                offset: hasTrack ? Offset.zero : const Offset(0, 1.25),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: hasTrack ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: const MiniPlayer(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  void _openNowPlaying(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const NowPlayingScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final isLiked = ref.watch(libraryProvider.select((l) => l.isLiked(track.id)));
    final accent = playerState.dynamicColor ?? AppColors.brandGreen;
    final totalMs = playerState.duration.inMilliseconds;
    final posMs = playerState.position.inMilliseconds;
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () => _openNowPlaying(context),
      onHorizontalDragEnd: (details) {
        final vx = details.primaryVelocity ?? 0;
        if (vx < -220) {
          HapticFeedback.lightImpact();
          ref.read(playerProvider.notifier).skipNext();
        } else if (vx > 220) {
          HapticFeedback.lightImpact();
          ref.read(playerProvider.notifier).skipPrevious();
        }
      },
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -220) {
          _openNowPlaying(context);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.lerp(const Color(0xFF282828), accent, 0.46)!,
              Color.lerp(const Color(0xFF1A1A1A), accent, 0.26)!,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 6, 7),
                child: Row(
                  children: [
                    Hero(
                      tag: 'now_playing_art_${track.id}',
                      child: ArtworkImage(
                        url: track.bestThumbUrl(size: 160),
                        size: 44,
                        radius: 6,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Align(
                          key: ValueKey(track.id),
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MarqueeText(
                                text: track.title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.graphic_eq_rounded,
                                    size: 12,
                                    color: AppColors.brandGreenBright,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      track.artistDisplay,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withAlpha(205),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isLiked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                        size: 22,
                        color: isLiked ? AppColors.brandGreenBright : Colors.white.withAlpha(225),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(libraryProvider.notifier).toggleLike(track);
                      },
                    ),
                    if (playerState.isBuffering)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(playerProvider.notifier).togglePlayPause();
                        },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.2,
                    backgroundColor: Colors.white.withAlpha(42),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
