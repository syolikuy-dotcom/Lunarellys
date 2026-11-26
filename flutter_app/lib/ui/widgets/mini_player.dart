import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
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
    final useDynamicMini = ref.watch(settingsProvider.select((s) => s.miniPlayerDynamicBg));
    final accent = playerState.dynamicColor ?? AppColors.brandGreen;
    final totalMs = playerState.duration.inMilliseconds;
    final posMs = playerState.position.inMilliseconds;
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    final leftTint = useDynamicMini
        ? Color.lerp(const Color(0xFF161E26), accent, 0.36)!
        : const Color(0xFF161E26);
    final rightTint = useDynamicMini
        ? Color.lerp(const Color(0xFF10161D), accent, 0.18)!
        : const Color(0xFF10161D);

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
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(110),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(18),
                    leftTint.withAlpha(182),
                    rightTint.withAlpha(206),
                  ],
                  stops: const [0.0, 0.34, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withAlpha(24),
                  width: 0.9,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 7),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'now_playing_art_${track.id}',
                          child: ArtworkImage(
                            url: track.bestThumbUrl(size: 160),
                            size: 44,
                            radius: 10,
                          ),
                        ),
                        const SizedBox(width: 11),
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
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isLiked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                            size: 21,
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
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(28),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withAlpha(48)),
                            ),
                            child: IconButton(
                              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                ref.read(playerProvider.notifier).togglePlayPause();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.4,
                        backgroundColor: Colors.white.withAlpha(36),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandGreenBright),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
