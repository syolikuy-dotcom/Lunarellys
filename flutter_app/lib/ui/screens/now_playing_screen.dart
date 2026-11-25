import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/media_card.dart';
import '../widgets/track_tile.dart';
import 'detail_screens.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  int _panelMode = 0; // 0 = Now, 1 = Lyrics, 2 = Queue
  final ScrollController _lyricsScroll = ScrollController();
  final GlobalKey _activeLyricKey = GlobalKey();
  int _lastScrolledLyricIdx = -1;

  static const _speeds = [0.75, 1.0, 1.25, 1.5];

  @override
  void dispose() {
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
    final track = player.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final accent = player.dynamicColor ?? AppColors.spotifyGreen;
    final isLiked = library.isLiked(track.id);
    final isDownloaded = library.isDownloaded(track.id);
    final dlProgress = library.downloadProgress[track.id];

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFF1E1E1E), accent, 0.58)!,
              Color.lerp(AppColors.background, accent, 0.22)!,
              AppColors.backgroundDeep,
            ],
            stops: const [0.0, 0.52, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(85),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: [
                      _modeTab(0, 'Track'),
                      _modeTab(1, 'Lyrics'),
                      _modeTab(2, 'Queue (${player.queue.length})'),
                    ],
                  ),
                ),
              ),
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
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  child: _panelMode == 0
                      ? _buildPlayerView(context, player, track, accent, isLiked, isDownloaded, dlProgress)
                      : _panelMode == 1
                          ? _buildLyricsView(player, accent)
                          : _buildQueueView(context, player, track, accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTab(int idx, String label) {
    final active = _panelMode == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _panelMode = idx;
            _lastScrolledLyricIdx = -1;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white.withAlpha(32) : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : Colors.white70,
            ),
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
    bool isLiked,
    bool isDownloaded,
    double? dlProgress,
  ) {
    final totalMs = player.duration.inMilliseconds > 0 ? player.duration.inMilliseconds : 1;
    final currentMs = player.position.inMilliseconds.clamp(0, totalMs);
    final speedLabel = '${player.playbackSpeed == 1.0 ? "1.0" : player.playbackSpeed}x';
    final related = player.songDetail?.related ?? const <MusicItem>[];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final artSize = math.min(constraints.maxWidth - 48, constraints.maxHeight * 0.42).clamp(164.0, 340.0);
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
                            color: Colors.black.withAlpha(120),
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
              const SizedBox(height: 22),
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
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.spotifyGreen),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        isDownloaded ? Icons.arrow_circle_down_rounded : Icons.download_for_offline_outlined,
                        color: isDownloaded ? AppColors.spotifyGreen : AppColors.textSecondary,
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
                      color: isLiked ? AppColors.spotifyGreenBright : Colors.white,
                      size: 28,
                    ),
                    onPressed: () => ref.read(libraryProvider.notifier).toggleLike(track),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                min: 0,
                max: totalMs.toDouble(),
                value: currentMs.toDouble(),
                onChanged: (val) => ref.read(playerProvider.notifier).seek(Duration(milliseconds: val.round())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
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
                          color: AppColors.spotifyGreenBright,
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
                  _SpotifyToggleIcon(
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
                  _SpotifyToggleIcon(
                    icon: player.repeat == RepeatSetting.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                    active: player.repeat != RepeatSetting.off,
                    onTap: () => ref.read(playerProvider.notifier).cycleRepeat(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.spotifyGreen),
                              )
                            : const Icon(Icons.radio_rounded, size: 21, color: AppColors.textSecondary),
                        tooltip: 'Song Radio',
                        onPressed: player.isLoadingRadio
                            ? null
                            : () => ref.read(playerProvider.notifier).startRadio(track),
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
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _panelMode = 1),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color.lerp(accent, const Color(0xFF181818), 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                                color: Colors.black.withAlpha(75),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'Expand',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(14),
                  ),
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
        child: CircularProgressIndicator(color: AppColors.spotifyGreen),
      );
    }
    final lyrics = player.lyrics;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const Center(
        child: Text('No lyrics available for this track', style: TextStyle(color: Colors.white70)),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        color: Color.lerp(accent, const Color(0xFF141414), 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
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
    );
  }

  Widget _buildQueueView(BuildContext context, PlayerState player, MusicItem track, Color accent) {
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
                icon: const Icon(Icons.radio_rounded, size: 17, color: AppColors.spotifyGreen),
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

  void _showMoreSheet(BuildContext context, MusicItem track, PlayerState player, Color accent) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
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
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
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
      ),
    );
  }
}

class _SpotifyToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SpotifyToggleIcon({
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
              color: active ? AppColors.spotifyGreen : Colors.white,
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppColors.spotifyGreen : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
