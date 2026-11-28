import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
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
    final track = ref.watch(playerProvider.select((s) => s.currentTrack));
    if (track == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final isBuffering = ref.watch(playerProvider.select((s) => s.isBuffering));
    final dynamicColor = ref.watch(playerProvider.select((s) => s.dynamicColor));
    final miniBgStyle = ref.watch(
      settingsProvider.select((s) => s.miniPlayerBackgroundStyle),
    );
    final isGlass = ref.watch(
      settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
    );
    final isLiked = ref.watch(
      libraryProvider.select((s) => s.isLiked(track.id)),
    );

    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final accent = dynamicColor ?? const Color(0xFF7FA3C7);
    final dynamicMix = switch (miniBgStyle) {
      MiniPlayerBackgroundStyle.blur => 0.0,
      MiniPlayerBackgroundStyle.dynamic => isDark ? 0.28 : 0.16,
      MiniPlayerBackgroundStyle.glowAnimated => isDark ? 0.36 : 0.22,
      MiniPlayerBackgroundStyle.liveMesh => isDark ? 0.42 : 0.26,
    };

    final pillTint = dynamicMix > 0 && dynamicColor != null
        ? Color.lerp(
            isDark
                ? (isGlass ? const Color(0xA6161B24) : const Color(0xE61A1F26))
                : (isGlass ? const Color(0xBAFFFFFF) : const Color(0xF5FFFFFF)),
            accent,
            dynamicMix,
          )
        : (isDark
            ? (isGlass ? const Color(0x9C151A23) : AppColors.darkSurface)
            : (isGlass ? const Color(0xB4FFFFFF) : AppColors.lightSurface));

    final chromaticColor = miniBgStyle == MiniPlayerBackgroundStyle.blur
        ? accent.withAlpha(isDark ? 90 : 75)
        : accent;

    if (compact) {
      return RepaintBoundary(
        child: LiquidGlassTap(
          onTap: onTap,
          pressedScale: 0.97,
          child: LiquidGlassSurface(
            borderRadius: BorderRadius.circular(999),
            blurSigma: 28,
            tintColor: pillTint,
            chromaticAccent: chromaticColor,
            interactiveFlex: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniPlayerProgressBar(color: ink.withAlpha(215)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 5, 5, 7),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        MiniSpinningVinyl(
                          artworkUrl: track.bestThumbUrl(size: 160),
                          size: 36,
                          isPlaying: isPlaying,
                          accentColor: accent,
                        ),
                        const SizedBox(width: 8),
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
                                  fontSize: 11.2,
                                  color: sub,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: () =>
                              ref.read(playerProvider.notifier).togglePlayPause(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: ink,
                              shape: BoxShape.circle,
                            ),
                            child: isBuffering
                                ? CupertinoActivityIndicator(
                                    radius: 8,
                                    color: isDark ? Colors.black : Colors.white,
                                  )
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 160),
                                    child: Icon(
                                      isPlaying
                                          ? CupertinoIcons.pause_fill
                                          : CupertinoIcons.play_fill,
                                      key: ValueKey('cplay_$isPlaying'),
                                      color: isDark ? Colors.black : Colors.white,
                                      size: 17,
                                    ),
                                  ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
                          onPressed: () =>
                              ref.read(playerProvider.notifier).skipNext(),
                          icon: Icon(CupertinoIcons.forward_fill, color: ink, size: 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: GestureDetector(
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
            chromaticAccent: chromaticColor,
            interactiveFlex: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniPlayerProgressBar(color: ink.withAlpha(220)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 10, 9),
                  child: Row(
                    children: [
                      MiniSpinningVinyl(
                        artworkUrl: track.bestThumbUrl(size: 180),
                        size: 44,
                        isPlaying: isPlaying,
                        accentColor: accent,
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
                        onPressed: () =>
                            ref.read(libraryProvider.notifier).toggleLike(track),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            isLiked
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            key: ValueKey('like_$isLiked'),
                            color: isLiked ? AppColors.iosPink : ink,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () =>
                            ref.read(playerProvider.notifier).togglePlayPause(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 39,
                          height: 39,
                          decoration: BoxDecoration(
                            color: ink,
                            shape: BoxShape.circle,
                          ),
                          child: isBuffering
                              ? CupertinoActivityIndicator(
                                  radius: 9,
                                  color: isDark ? Colors.black : Colors.white,
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: Icon(
                                    isPlaying
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    key: ValueKey('play_$isPlaying'),
                                    color: isDark ? Colors.black : Colors.white,
                                    size: 19,
                                  ),
                                ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            ref.read(playerProvider.notifier).skipNext(),
                        icon: Icon(CupertinoIcons.forward_fill, color: ink, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Isolated 5Hz progress bar leaf so the glass surface and artwork don't
/// repaint or rebuild every 200ms while a track is playing.
class _MiniPlayerProgressBar extends ConsumerWidget {
  final Color color;
  const _MiniPlayerProgressBar({required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      playerProvider.select((s) {
        final total = s.duration.inMilliseconds;
        if (total <= 0) return 0.0;
        return (s.position.inMilliseconds / total).clamp(0.0, 1.0);
      }),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 2,
          child: Stack(
            children: [
              const SizedBox.expand(),
              FractionallySizedBox(
                widthFactor: progress,
                child: ColoredBox(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
