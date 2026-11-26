import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import 'artwork_image.dart';
import 'liquid_glass.dart';
import 'marquee_text.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback onTap;
  final bool compact;

  const MiniPlayer({
    super.key,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final settings = ref.watch(settingsProvider);
    final library = ref.watch(libraryProvider);
    final isLiked = library.isLiked(track.id);
    final isDark = AppColors.isDark(context);

    final totalMs = player.duration.inMilliseconds;
    final posMs = player.position.inMilliseconds;
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final accent = player.dynamicColor ?? const Color(0xFF7FA3C7);
    final useDynamicBg =
        settings.miniPlayerBackgroundStyle != MiniPlayerBackgroundStyle.blur &&
            player.dynamicColor != null;

    final pillTint = useDynamicBg
        ? Color.lerp(
            isDark ? const Color(0xD81A1F26) : const Color(0xECFFFFFF),
            accent,
            isDark ? 0.24 : 0.12,
          )
        : (isDark ? const Color(0xD4171B22) : const Color(0xE2FFFFFF));

    if (compact) {
      return LiquidGlassTap(
        onTap: onTap,
        pressedScale: 0.97,
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(999),
          blurSigma: 28,
          tintColor: pillTint,
          chromaticAccent: accent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2px progress indicator hugging the top edge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 2,
                    child: Stack(
                      children: [
                        Container(color: Colors.transparent),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(color: ink.withAlpha(210)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 6, 8, 8),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      ArtworkImage(
                        url: track.bestThumbUrl(size: 160),
                        size: 38,
                        radius: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarqueeText(
                              text: track.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              track.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                        onPressed: () => ref.read(libraryProvider.notifier).toggleLike(track),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            key: ValueKey('clike_$isLiked'),
                            color: isLiked ? const Color(0xFFE11D48) : ink,
                            size: 19,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: ink,
                            shape: BoxShape.circle,
                          ),
                          child: player.isBuffering
                              ? Padding(
                                  padding: const EdgeInsets.all(9),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: Icon(
                                    player.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    key: ValueKey('cplay_${player.isPlaying}'),
                                    color: isDark ? Colors.black : Colors.white,
                                    size: 21,
                                  ),
                                ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                        onPressed: () => ref.read(playerProvider.notifier).skipNext(),
                        icon: Icon(Icons.skip_next_rounded, color: ink, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -180) {
          onTap();
        }
      },
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -300) {
          ref.read(playerProvider.notifier).skipNext();
        } else if (v > 300) {
          ref.read(playerProvider.notifier).skipPrevious();
        }
      },
      child: LiquidGlassTap(
        onTap: onTap,
        pressedScale: 0.98,
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(32),
          blurSigma: 28,
          tintColor: pillTint,
          chromaticAccent: accent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2px crisp dark progress bar hugging the top edge like screenshot
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 2,
                    child: Stack(
                      children: [
                        Container(color: Colors.transparent),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(color: ink.withAlpha(220)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 10, 9),
                child: Row(
                  children: [
                    ArtworkImage(
                      url: track.bestThumbUrl(size: 180),
                      size: 44,
                      radius: 22,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarqueeText(
                            text: track.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: ink,
                              letterSpacing: -0.25,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            track.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(libraryProvider.notifier).toggleLike(track),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          key: ValueKey('like_$isLiked'),
                          color: isLiked ? const Color(0xFFE11D48) : ink,
                          size: 21,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ink,
                          shape: BoxShape.circle,
                        ),
                        child: player.isBuffering
                            ? Padding(
                                padding: const EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: Icon(
                                  player.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey('play_${player.isPlaying}'),
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 23,
                                ),
                              ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(playerProvider.notifier).skipNext(),
                      icon: Icon(Icons.skip_next_rounded, color: ink, size: 24),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
