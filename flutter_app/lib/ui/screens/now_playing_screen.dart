import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/media_card.dart';
import '../widgets/track_tile.dart';
import 'detail_screens.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  int _panelMode = 0; // 0 = Track, 1 = Lyrics, 2 = Queue
  final ScrollController _lyricsScroll = ScrollController();
  final GlobalKey _activeLyricKey = GlobalKey();
  int _lastScrolledLyricIdx = -1;
  late final AnimationController _ambientCtrl;

  static const _speeds = [0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
  }

  void _syncAmbientAnimation(
    PlayerBackgroundStyle bgStyle,
    PlayerSliderStyle sliderStyle,
    bool isPlaying,
  ) {
    final needsBgTick = bgStyle == PlayerBackgroundStyle.liveMesh ||
        bgStyle == PlayerBackgroundStyle.glowAnimated;
    final needsWaveTick = isPlaying &&
        (sliderStyle == PlayerSliderStyle.wavy ||
            sliderStyle == PlayerSliderStyle.squiggly);
    final shouldRun = needsBgTick || needsWaveTick;
    if (shouldRun && !_ambientCtrl.isAnimating) {
      _ambientCtrl.repeat();
    } else if (!shouldRun && _ambientCtrl.isAnimating) {
      _ambientCtrl.stop();
    }
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final total = d.inSeconds.clamp(0, 86400);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _cycleSpeed(double current) {
    var nextIdx = 0;
    for (var i = 0; i < _speeds.length; i++) {
      if ((current - _speeds[i]).abs() < 0.05) {
        nextIdx = (i + 1) % _speeds.length;
        break;
      }
    }
    ref.read(playerProvider.notifier).setPlaybackSpeed(_speeds[nextIdx]);
  }

  void _scheduleLyricScroll(int activeIdx) {
    if (activeIdx < 0 || activeIdx == _lastScrolledLyricIdx || _panelMode != 1) return;
    _lastScrolledLyricIdx = activeIdx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeLyricKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.38,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final library = ref.watch(libraryProvider);
    final settings = ref.watch(settingsProvider);
    final track = player.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    _syncAmbientAnimation(
      settings.playerBackgroundStyle,
      settings.sliderStyle,
      player.isPlaying,
    );

    final accent = player.dynamicColor ?? AppColors.brandGreen;
    final isLiked = library.isLiked(track.id);
    final isDownloaded = library.isDownloaded(track.id);
    final dlProgress = library.downloadProgress[track.id];

    final topInset = math.max(
      MediaQuery.paddingOf(context).top,
      MediaQuery.viewPaddingOf(context).top,
    );
    final bottomInset = math.max(
      MediaQuery.paddingOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackdrop(track, accent, settings.playerBackgroundStyle),
            Padding(
              padding: EdgeInsets.only(top: topInset + 6, bottom: bottomInset),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(64),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PLAYING FROM ${player.playingContext.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withAlpha(185),
                                ),
                              ),
                              if (track.album?.name.isNotEmpty == true)
                                Text(
                                  track.album!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded),
                          onPressed: () => _showMoreSheet(context, track, player, accent),
                        ),
                      ],
                    ),
                  ),
                  _buildModeTabs(player),
                  if (player.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(42),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        player.errorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.025),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_panelMode),
                        child: _panelMode == 0
                            ? _buildPlayerView(
                                context,
                                player,
                                track,
                                accent,
                                settings.sliderStyle,
                                isLiked,
                                isDownloaded,
                                dlProgress,
                              )
                            : _panelMode == 1
                                ? _buildLyricsView(player, accent)
                                : _buildQueueView(context, player, track, accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackdrop(
    MusicItem track,
    Color accent,
    PlayerBackgroundStyle style,
  ) {
    final thumbUrl = track.bestThumbUrl(size: 320);
    if (style == PlayerBackgroundStyle.blur && thumbUrl != null) {
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: thumbUrl,
              fit: BoxFit.cover,
              memCacheWidth: 160,
              memCacheHeight: 160,
              filterQuality: FilterQuality.low,
              errorWidget: (_, __, ___) => Container(color: AppColors.backgroundDeep),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(115),
                      Colors.black.withAlpha(185),
                      AppColors.backgroundDeep.withAlpha(242),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (style == PlayerBackgroundStyle.liveMesh) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ambientCtrl,
          builder: (_, __) {
            final phase = _ambientCtrl.value * math.pi * 2;
            return Container(
              color: AppColors.backgroundDeep,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          -0.45 + 0.25 * math.cos(phase),
                          -0.6 + 0.2 * math.sin(phase),
                        ),
                        radius: 1.05,
                        colors: [accent.withAlpha(125), Colors.transparent],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          0.55 + 0.25 * math.sin(phase),
                          0.3 + 0.25 * math.cos(phase),
                        ),
                        radius: 1.1,
                        colors: [
                          AppColors.brandGreen.withAlpha(78),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(color: Colors.black.withAlpha(70)),
                ],
              ),
            );
          },
        ),
      );
    }

    if (style == PlayerBackgroundStyle.glowAnimated) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ambientCtrl,
          builder: (_, __) {
            final pulse = 0.5 + 0.5 * math.sin(_ambientCtrl.value * math.pi * 2);
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(const Color(0xFF1A1E1C), accent, 0.50 + 0.14 * pulse)!,
                    Color.lerp(AppColors.background, accent, 0.20 + 0.06 * pulse)!,
                    AppColors.backgroundDeep,
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            );
          },
        ),
      );
    }

    // Classic
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFF1E1E1E), accent, 0.56)!,
              Color.lerp(AppColors.background, accent, 0.20)!,
              AppColors.backgroundDeep,
            ],
            stops: const [0.0, 0.52, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs(PlayerState player) {
    final labels = ['Track', 'Lyrics', 'Queue (${player.queue.length})'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: LiquidGlassCapsule(
        blurSigma: 13,
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 36,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / labels.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: tabWidth * _panelMode,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(32),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withAlpha(28),
                          width: 0.7,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(labels.length, (idx) {
                      final active = _panelMode == idx;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _panelMode = idx;
                              _lastScrolledLyricIdx = -1;
                            });
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? Colors.white : Colors.white70,
                              ),
                              child: Text(
                                labels[idx],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerView(
    BuildContext context,
    PlayerState player,
    MusicItem track,
    Color accent,
    PlayerSliderStyle sliderStyle,
    bool isLiked,
    bool isDownloaded,
    double? dlProgress,
  ) {
    final totalMs = player.duration.inMilliseconds > 0 ? player.duration.inMilliseconds : 1;
    final currentMs = player.position.inMilliseconds.clamp(0, totalMs);
    final bufferedMs = player.bufferedPosition.inMilliseconds.clamp(0, totalMs);
    final speedLabel = '${player.playbackSpeed == 1.0 ? "1.0" : player.playbackSpeed}x';
    final related = player.songDetail?.related ?? const <MusicItem>[];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final artSize = math
            .min(constraints.maxWidth - 48, constraints.maxHeight * 0.42)
            .clamp(150.0, 340.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
          child: Column(
            children: [
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  final vx = details.primaryVelocity ?? 0;
                  if (vx < -240) {
                    ref.read(playerProvider.notifier).skipNext();
                  } else if (vx > 240) {
                    ref.read(playerProvider.notifier).skipPrevious();
                  }
                },
                child: AnimatedScale(
                  scale: player.isPlaying ? 1.0 : 0.93,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: Hero(
                    tag: 'now_playing_art_${track.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(125),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ArtworkImage(
                        url: track.bestThumbUrl(size: 720),
                        size: artSize,
                        radius: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: track.artists.isNotEmpty && track.artists.first.id != null
                              ? () {
                                  Navigator.pop(context);
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ArtistScreen(artistId: track.artists.first.id!),
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            track.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dlProgress != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.brandGreen,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        isDownloaded
                            ? Icons.arrow_circle_down_rounded
                            : Icons.download_for_offline_outlined,
                        color: isDownloaded ? AppColors.brandGreen : AppColors.textSecondary,
                        size: 25,
                      ),
                      onPressed: () async {
                        if (isDownloaded) {
                          await ref.read(libraryProvider.notifier).removeDownload(track.id);
                        } else {
                          await ref.read(libraryProvider.notifier).downloadTrack(track);
                        }
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                      color: isLiked ? AppColors.brandGreenBright : Colors.white,
                      size: 28,
                    ),
                    onPressed: () => ref.read(libraryProvider.notifier).toggleLike(track),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (player.isPlaying &&
                  (sliderStyle == PlayerSliderStyle.wavy ||
                      sliderStyle == PlayerSliderStyle.squiggly))
                AnimatedBuilder(
                  animation: _ambientCtrl,
                  builder: (_, __) => _LunarellysProgressSlider(
                    value: (currentMs / totalMs).clamp(0.0, 1.0),
                    buffered: (bufferedMs / totalMs).clamp(0.0, 1.0),
                    style: sliderStyle,
                    isPlaying: true,
                    phase: _ambientCtrl.value * math.pi * 2,
                    activeColor: Colors.white,
                    onSeekFraction: (frac) {
                      ref
                          .read(playerProvider.notifier)
                          .seek(Duration(milliseconds: (frac * totalMs).round()));
                    },
                  ),
                )
              else
                _LunarellysProgressSlider(
                  value: (currentMs / totalMs).clamp(0.0, 1.0),
                  buffered: (bufferedMs / totalMs).clamp(0.0, 1.0),
                  style: sliderStyle,
                  isPlaying: player.isPlaying,
                  phase: 0.0,
                  activeColor: Colors.white,
                  onSeekFraction: (frac) {
                    ref
                        .read(playerProvider.notifier)
                        .seek(Duration(milliseconds: (frac * totalMs).round()));
                  },
                ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmtDuration(player.position),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (player.sleepTimerRemaining != null)
                      Text(
                        'Sleep ${_fmtDuration(player.sleepTimerRemaining!)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          color: AppColors.brandGreenBright,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    Text(
                      _fmtDuration(player.duration),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PlayerToggleIcon(
                    icon: Icons.shuffle_rounded,
                    active: player.shuffle,
                    onTap: () => ref.read(playerProvider.notifier).toggleShuffle(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 38, color: Colors.white),
                    onPressed: () => ref.read(playerProvider.notifier).skipPrevious(),
                  ),
                  Container(
                    width: 66,
                    height: 66,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: player.isBuffering
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                color: Colors.black,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 38,
                              color: Colors.black,
                            ),
                            onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 38, color: Colors.white),
                    onPressed: () => ref.read(playerProvider.notifier).skipNext(),
                  ),
                  _PlayerToggleIcon(
                    icon: player.repeat == RepeatSetting.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    active: player.repeat != RepeatSetting.off,
                    onTap: () => ref.read(playerProvider.notifier).cycleRepeat(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _cycleSpeed(player.playbackSpeed),
                    icon: const Icon(Icons.speed_rounded, size: 17, color: AppColors.textSecondary),
                    label: Text(
                      speedLabel,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: player.isLoadingRadio
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.brandGreen,
                                ),
                              )
                            : const Icon(Icons.radio_rounded, size: 21, color: AppColors.textSecondary),
                        tooltip: 'Song Radio',
                        onPressed: player.isLoadingRadio
                            ? null
                            : () => ref.read(playerProvider.notifier).startRadio(track),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.playlist_add_rounded,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Add to Playlist',
                        onPressed: () => showTrackPlaylistPicker(context, ref, track),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Share',
                        onPressed: () => Share.share(
                          '${track.title} — ${track.artistDisplay}\nhttps://music.youtube.com/watch?v=${track.id}',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.queue_music_rounded, size: 22, color: AppColors.textSecondary),
                        tooltip: 'Queue',
                        onPressed: () => setState(() => _panelMode = 2),
                      ),
                    ],
                  ),
                ],
              ),
              if (player.lyrics != null && player.lyrics!.lines.isNotEmpty) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => setState(() => _panelMode = 1),
                  child: LiquidGlassSurface(
                    borderRadius: 20,
                    blurSigma: 24,
                    tintColor: accent,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Lyrics',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(22),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: Colors.white.withAlpha(24)),
                              ),
                              child: const Text(
                                'Expand',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _previewLyricText(player),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (related.isNotEmpty) ...[
                const SizedBox(height: 18),
                LiquidGlassSurface(
                  borderRadius: 20,
                  blurSigma: 22,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Related tracks & mixes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 215,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: related.take(10).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => MediaCard(
                            item: related[i],
                            contextQueue: related,
                            width: 130,
                            contextLabel: 'Related',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _previewLyricText(PlayerState player) {
    final lyrics = player.lyrics;
    if (lyrics == null || lyrics.lines.isEmpty) return '';
    if (!lyrics.synced) {
      return lyrics.lines.take(3).map((l) => l.text).join('\n');
    }
    final ms = player.position.inMilliseconds;
    var active = 0;
    for (var i = 0; i < lyrics.lines.length; i++) {
      final t = lyrics.lines[i].timeMs;
      if (t != null && ms >= t) active = i;
    }
    return lyrics.lines.skip(active).take(3).map((l) => l.text).join('\n');
  }

  Widget _buildLyricsView(PlayerState player, Color accent) {
    if (player.loadingLyrics) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandGreen),
      );
    }
    final lyrics = player.lyrics;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const Center(
        child: Text(
          'No lyrics available for this track',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final currentMs = player.position.inMilliseconds;
    int activeIdx = -1;
    if (lyrics.synced) {
      for (var i = 0; i < lyrics.lines.length; i++) {
        final t = lyrics.lines[i].timeMs;
        if (t != null && currentMs >= t) {
          activeIdx = i;
        } else {
          break;
        }
      }
      _scheduleLyricScroll(activeIdx);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: LiquidGlassSurface(
        borderRadius: 24,
        blurSigma: 24,
        tintColor: accent,
        child: Column(
        children: [
          if (lyrics.source != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                lyrics.source!,
                style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(180)),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _lyricsScroll,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 44),
              itemCount: lyrics.lines.length,
              itemBuilder: (ctx, i) {
                final line = lyrics.lines[i];
                final active = i == activeIdx;
                return InkWell(
                  key: active ? _activeLyricKey : null,
                  borderRadius: BorderRadius.circular(10),
                  onTap: line.timeMs != null
                      ? () => ref.read(playerProvider.notifier).seek(Duration(milliseconds: line.timeMs!))
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: active ? 22 : 18,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : Colors.white.withAlpha(140),
                        height: 1.38,
                      ),
                      child: Text(line.text),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildQueueView(
    BuildContext context,
    PlayerState player,
    MusicItem track,
    Color accent,
  ) {
    if (player.queue.isEmpty) {
      return const Center(child: Text('Queue is empty'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Next in queue (${player.queue.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: player.isLoadingRadio
                    ? null
                    : () => ref.read(playerProvider.notifier).startRadio(track),
                icon: const Icon(Icons.radio_rounded, size: 17, color: AppColors.brandGreen),
                label: const Text('Add Radio'),
              ),
              if (player.queue.length > 1)
                TextButton(
                  onPressed: () => ref.read(playerProvider.notifier).clearUpcomingQueue(),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 32),
            itemCount: player.queue.length,
            onReorder: (oldIdx, newIdx) =>
                ref.read(playerProvider.notifier).reorderQueue(oldIdx, newIdx),
            itemBuilder: (ctx, i) {
              final item = player.queue[i];
              return Row(
                key: ValueKey('${item.id}_$i'),
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                      child: Icon(Icons.drag_handle_rounded, size: 20, color: AppColors.textMuted),
                    ),
                  ),
                  Expanded(
                    child: TrackTile(
                      track: item,
                      queue: player.queue,
                      trailingExtra: i != player.currentIndex
                          ? IconButton(
                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                              onPressed: () => ref.read(playerProvider.notifier).removeFromQueue(i),
                            )
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMoreSheet(
    BuildContext context,
    MusicItem track,
    PlayerState player,
    Color accent,
  ) {
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ArtworkImage(url: track.bestThumbUrl(size: 160), size: 46, radius: 6),
                title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(track.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(ctx);
                  showTrackPlaylistPicker(context, ref, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Sleep timer'),
                subtitle: player.sleepTimerRemaining != null
                    ? Text('Remaining: ${_fmtDuration(player.sleepTimerRemaining!)}')
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSleepTimerSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.radio_rounded),
                title: const Text('Go to song radio'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(playerProvider.notifier).startRadio(track);
                },
              ),
              if (track.artists.isNotEmpty && track.artists.first.id != null)
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text('View ${track.artists.first.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
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
                    Navigator.pop(ctx);
                    Navigator.pop(context);
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
                  Navigator.pop(ctx);
                  Share.share(
                    '${track.title} — ${track.artistDisplay}\nhttps://music.youtube.com/watch?v=${track.id}',
                  );
                },
              ),
            ],
          ),
        ),
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    final options = [
      (null, 'Turn off timer'),
      (const Duration(minutes: 15), '15 minutes'),
      (const Duration(minutes: 30), '30 minutes'),
      (const Duration(minutes: 45), '45 minutes'),
      (const Duration(minutes: 60), '1 hour'),
    ];
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sleep timer', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...options.map(
                (opt) => ListTile(
                  title: Text(opt.$2),
                  onTap: () {
                    ref.read(playerProvider.notifier).setSleepTimer(opt.$1);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _LunarellysProgressSlider extends StatelessWidget {
  final double value;
  final double buffered;
  final PlayerSliderStyle style;
  final bool isPlaying;
  final double phase;
  final Color activeColor;
  final ValueChanged<double> onSeekFraction;

  const _LunarellysProgressSlider({
    required this.value,
    required this.buffered,
    required this.style,
    required this.isPlaying,
    required this.phase,
    required this.activeColor,
    required this.onSeekFraction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final w = box.maxWidth > 0 ? box.maxWidth : 1.0;
        void emitSeek(Offset localPos) {
          final frac = (localPos.dx / w).clamp(0.0, 1.0);
          onSeekFraction(frac);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            HapticFeedback.selectionClick();
            emitSeek(d.localPosition);
          },
          onHorizontalDragStart: (d) => emitSeek(d.localPosition),
          onHorizontalDragUpdate: (d) => emitSeek(d.localPosition),
          child: SizedBox(
            height: 30,
            width: double.infinity,
            child: CustomPaint(
              painter: _SliderStylePainter(
                value: value,
                buffered: buffered,
                style: style,
                phase: isPlaying ? phase : 0.0,
                activeColor: activeColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SliderStylePainter extends CustomPainter {
  final double value;
  final double buffered;
  final PlayerSliderStyle style;
  final double phase;
  final Color activeColor;

  const _SliderStylePainter({
    required this.value,
    required this.buffered,
    required this.style,
    required this.phase,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const pad = 7.0;
    final usableW = (size.width - pad * 2).clamp(1.0, double.infinity);
    final activeX = pad + usableW * value.clamp(0.0, 1.0);
    final bufferedX = pad + usableW * buffered.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = Colors.white.withAlpha(48)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style == PlayerSliderStyle.slim ? 3.5 : 4.0;

    final bufPaint = Paint()
      ..color = Colors.white.withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style == PlayerSliderStyle.slim ? 3.5 : 4.0;

    final actPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style == PlayerSliderStyle.slim ? 4.2 : 3.6;

    // Inactive & buffered lines
    canvas.drawLine(Offset(pad, cy), Offset(pad + usableW, cy), trackPaint);
    if (bufferedX > activeX) {
      canvas.drawLine(Offset(activeX, cy), Offset(bufferedX, cy), bufPaint);
    }

    if (style == PlayerSliderStyle.wavy || style == PlayerSliderStyle.squiggly) {
      final path = Path();
      final amp = style == PlayerSliderStyle.squiggly ? 4.2 : 3.2;
      final freq = style == PlayerSliderStyle.squiggly ? 0.24 : 0.16;
      final steps = ((activeX - pad) / 2.5).ceil().clamp(1, 200);
      for (var i = 0; i <= steps; i++) {
        final x = pad + ((activeX - pad) * i / steps);
        final y = cy + math.sin((x - pad) * freq - phase) * amp;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, actPaint);
    } else {
      canvas.drawLine(Offset(pad, cy), Offset(activeX, cy), actPaint);
    }

    // Thumb indicator
    final thumbPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    if (style == PlayerSliderStyle.standard || style == PlayerSliderStyle.squiggly) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(activeX, cy), width: 4.0, height: 18.0),
          const Radius.circular(2),
        ),
        thumbPaint,
      );
    } else if (style == PlayerSliderStyle.wavy) {
      canvas.drawCircle(Offset(activeX, cy), 6.5, thumbPaint);
    } else {
      canvas.drawCircle(Offset(activeX, cy), 5.0, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SliderStylePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.buffered != buffered ||
        oldDelegate.style != style ||
        oldDelegate.phase != phase ||
        oldDelegate.activeColor != activeColor;
  }
}

class _PlayerToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _PlayerToggleIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: active ? AppColors.brandGreen : Colors.white,
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppColors.brandGreen : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
