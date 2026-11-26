import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/animated_eq.dart';
import '../widgets/artwork_image.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/track_tile.dart';
import 'detail_screens.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _lyricsScrollCtrl = ScrollController();
  late final AnimationController _ambientCtrl;
  double? _draggingValue;
  int _panelMode = 0; // 0 = Player, 1 = Lyrics, 2 = Queue
  bool _userScrollingLyrics = false;
  int _lastActiveLyricIndex = -1;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lyricsScrollCtrl.dispose();
    _ambientCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatTotalQueueDuration(List<MusicItem> queue) {
    var total = 0;
    for (final q in queue) {
      total += q.durationSeconds ?? 210;
    }
    return _formatDuration(Duration(seconds: total));
  }

  int _findActiveLyricIndex(LyricsResult? lyrics, Duration position, int offsetMs) {
    if (lyrics == null || !lyrics.synced || lyrics.lines.isEmpty) return -1;
    final posMs = position.inMilliseconds + offsetMs;
    var active = 0;
    for (var i = 0; i < lyrics.lines.length; i++) {
      final t = lyrics.lines[i].timeMs;
      if (t != null && t <= posMs) {
        active = i;
      } else if (t != null && t > posMs) {
        break;
      }
    }
    return active;
  }

  double _lineProgress(LyricsResult? lyrics, int idx, Duration position, int offsetMs) {
    if (lyrics == null || !lyrics.synced || idx < 0 || idx >= lyrics.lines.length) {
      return 1.0;
    }
    final curMs = lyrics.lines[idx].timeMs ?? 0;
    final nextMs = (idx + 1 < lyrics.lines.length && lyrics.lines[idx + 1].timeMs != null)
        ? lyrics.lines[idx + 1].timeMs!
        : (curMs + 4200);
    final span = (nextMs - curMs).clamp(600, 14000);
    final posMs = position.inMilliseconds + offsetMs;
    return ((posMs - curMs) / span).clamp(0.0, 1.0);
  }

  void _syncLyricsScroll(int activeIdx) {
    if (_panelMode != 1 || _userScrollingLyrics || activeIdx < 0) return;
    if (activeIdx == _lastActiveLyricIndex) return;
    _lastActiveLyricIndex = activeIdx;
    if (!_lyricsScrollCtrl.hasClients) return;
    final target = (activeIdx * 62.0 - 110.0)
        .clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent);
    _lyricsScrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final library = ref.watch(libraryProvider);
    final settings = ref.watch(settingsProvider);
    final track = player.currentTrack;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Belum ada lagu yang diputar')),
      );
    }

    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    final baseAccent = settings.dynamicAlbumColors
        ? (player.dynamicColor ?? const Color(0xFF9AA189))
        : const Color(0xFF9AA189);

    final bgTop = isDark
        ? Color.lerp(const Color(0xFF101318), baseAccent, 0.34)!
        : Color.lerp(const Color(0xFFDFE2DF), baseAccent, 0.28)!;
    final bgBottom = isDark
        ? const Color(0xFF0B0D10)
        : Color.lerp(const Color(0xFFE5E7E4), baseAccent, 0.14)!;

    final totalMs = player.duration.inMilliseconds.toDouble();
    final currentMs = (_draggingValue ?? player.position.inMilliseconds.toDouble())
        .clamp(0.0, totalMs > 0 ? totalMs : 1.0);
    final remainingDur = Duration(
      milliseconds: ((totalMs - currentMs).clamp(0.0, double.infinity)).round(),
    );

    final activeLyricIdx = _findActiveLyricIndex(
      player.lyrics,
      player.position,
      settings.lyricsOffsetMs,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLyricsScroll(activeLyricIdx));

    final isLiked = library.isLiked(track.id);

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if (_panelMode == 0 && (d.primaryVelocity ?? 0) > 450) {
            Navigator.of(context).pop();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgTop, bgBottom],
            ),
          ),
          child: SafeArea(
            top: _panelMode != 0,
            child: Column(
              children: [
                if (_panelMode == 2)
                  Expanded(
                    child: _buildQueuePanel(context, player, isDark, ink, sub),
                  )
                else if (_panelMode == 1)
                  Expanded(
                    child: _buildLyricsPanel(
                      context,
                      track,
                      player,
                      settings,
                      activeLyricIdx,
                      totalMs,
                      currentMs,
                      remainingDur,
                      isDark,
                      ink,
                      sub,
                    ),
                  )
                else
                  Expanded(
                    child: _buildMainPlayerPanel(
                      context,
                      track,
                      player,
                      settings,
                      isLiked,
                      activeLyricIdx,
                      totalMs,
                      currentMs,
                      remainingDur,
                      bgTop,
                      isDark,
                      ink,
                      sub,
                    ),
                  ),

                // Persistent Bottom Navigation Dock inside Player
                _buildBottomDock(context, track, player, isDark, ink),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainPlayerPanel(
    BuildContext context,
    MusicItem track,
    PlayerState player,
    AppSettingsState settings,
    bool isLiked,
    int activeLyricIdx,
    double totalMs,
    double currentMs,
    Duration remainingDur,
    Color bgTop,
    bool isDark,
    Color ink,
    Color sub,
  ) {
    final topPad = MediaQuery.of(context).padding.top;
    final activeLine = (activeLyricIdx >= 0 &&
            player.lyrics != null &&
            activeLyricIdx < player.lyrics!.lines.length)
        ? player.lyrics!.lines[activeLyricIdx].text
        : null;
    final activeProgress =
        _lineProgress(player.lyrics, activeLyricIdx, player.position, settings.lyricsOffsetMs);

    return Column(
      children: [
        // Top blended edge-to-edge Artwork Hero with vertical alpha dissolve
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.72, 1.0],
                  colors: [Colors.white, Colors.white, Colors.transparent],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ArtworkImage(
                  url: track.bestThumbUrl(size: 900),
                  size: MediaQuery.of(context).size.width,
                  radius: 0,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topPad + 92,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(110),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topPad + 10,
                left: 20,
                right: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sedang diputar',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(225),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      player.playingContext.isNotEmpty
                          ? player.playingContext
                          : 'Mix ${track.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: topPad + 8,
                right: 14,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withAlpha(70),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),

        // Lower Control Deck
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 2, 22, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () {
                            if (track.artists.isNotEmpty && track.artists.first.id != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ArtistScreen(artistId: track.artists.first.id!),
                                ),
                              );
                            }
                          },
                          child: Text(
                            track.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              color: sub,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FrostedRoundAction(
                    icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? const Color(0xFFE11D48) : ink,
                    onTap: () => ref.read(libraryProvider.notifier).toggleLike(track),
                  ),
                  const SizedBox(width: 8),
                  _FrostedRoundAction(
                    icon: Icons.more_vert_rounded,
                    color: ink,
                    onTap: () => _showFullNowPlayingOptions(context, track),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              // Single-line synced lyric snippet preview
              GestureDetector(
                onTap: () => setState(() => _panelMode = 1),
                child: SizedBox(
                  height: 22,
                  child: activeLine != null
                      ? _ContrastSweepText(
                          text: activeLine,
                          progress: activeProgress,
                          activeColor: ink,
                          inactiveColor: ink.withAlpha(115),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        )
                      : Text(
                          player.loadingLyrics ? 'Memuat lirik...' : 'Ketuk untuk lihat lirik',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: sub.withAlpha(180),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 6),
              _buildSeekAndTransportDeck(
                context,
                player: player,
                settings: settings,
                totalMs: totalMs,
                currentMs: currentMs,
                remainingDur: remainingDur,
                ink: ink,
                sub: sub,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeekAndTransportDeck(
    BuildContext context, {
    required PlayerState player,
    required AppSettingsState settings,
    required double totalMs,
    required double currentMs,
    required Duration remainingDur,
    required Color ink,
    required Color sub,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: settings.sliderStyle == PlayerSliderStyle.slim ? 2.6 : 3.8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: ink,
            inactiveTrackColor: ink.withAlpha(38),
            thumbColor: ink,
          ),
          child: Slider(
            min: 0,
            max: totalMs > 0 ? totalMs : 1,
            value: currentMs,
            onChanged: (v) => setState(() => _draggingValue = v),
            onChangeEnd: (v) async {
              setState(() => _draggingValue = null);
              await ref.read(playerProvider.notifier).seek(
                    Duration(milliseconds: v.round()),
                  );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: currentMs.round())),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: sub,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '-${_formatDuration(remainingDur)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: sub,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                Icons.shuffle_rounded,
                size: 24,
                color: player.shuffle ? ink : sub.withAlpha(170),
              ),
              onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
            ),
            IconButton(
              icon: Icon(Icons.skip_previous_rounded, size: 34, color: ink),
              onPressed: () => ref.read(playerProvider.notifier).skipPrevious(),
            ),
            LiquidGlassTap(
              onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: player.isBuffering
                    ? SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 3, color: ink),
                      )
                    : Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: ink,
                        size: 46,
                      ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.skip_next_rounded, size: 34, color: ink),
              onPressed: () => ref.read(playerProvider.notifier).skipNext(),
            ),
            IconButton(
              icon: Icon(
                player.repeat == RepeatSetting.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 24,
                color: player.repeat == RepeatSetting.off
                    ? sub.withAlpha(170)
                    : ink,
              ),
              onPressed: () => ref.read(playerProvider.notifier).cycleRepeat(),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.volume_down_rounded, size: 20, color: sub),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: ink,
                  inactiveTrackColor: ink.withAlpha(38),
                  thumbColor: ink,
                ),
                child: Slider(
                  min: 0.0,
                  max: 1.0,
                  value: player.volume,
                  onChanged: (v) => ref.read(playerProvider.notifier).setVolume(v),
                ),
              ),
            ),
            Icon(Icons.volume_up_rounded, size: 20, color: sub),
            const SizedBox(width: 8),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.bluetooth_rounded, size: 20, color: ink),
              tooltip: 'Output audio',
              onPressed: () => _showAudioOutputSheet(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLyricsPanel(
    BuildContext context,
    MusicItem track,
    PlayerState player,
    AppSettingsState settings,
    int activeLyricIdx,
    double totalMs,
    double currentMs,
    Duration remainingDur,
    bool isDark,
    Color ink,
    Color sub,
  ) {
    final lyrics = player.lyrics;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (player.loadingLyrics)
                Center(child: CircularProgressIndicator(color: ink))
              else if (lyrics == null || lyrics.lines.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lyrics_outlined, size: 46, color: sub),
                      const SizedBox(height: 10),
                      Text('Lirik tidak tersedia untuk lagu ini', style: TextStyle(color: sub)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.read(playerProvider.notifier).refreshLyrics(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Muat ulang lirik'),
                      ),
                    ],
                  ),
                )
              else
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.12, 0.85, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: (n) {
                      if (!_userScrollingLyrics) {
                        setState(() => _userScrollingLyrics = true);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _lyricsScrollCtrl,
                      padding: const EdgeInsets.fromLTRB(32, 26, 32, 48),
                      itemCount: lyrics.lines.length,
                      itemBuilder: (_, idx) {
                        final line = lyrics.lines[idx];
                        final isActive = !lyrics.synced || idx == activeLyricIdx;
                        final progress = _lineProgress(
                          lyrics,
                          idx,
                          player.position,
                          settings.lyricsOffsetMs,
                        );

                        return GestureDetector(
                          onTap: line.timeMs != null
                              ? () {
                                  setState(() => _userScrollingLyrics = false);
                                  ref.read(playerProvider.notifier).seek(
                                        Duration(milliseconds: line.timeMs!),
                                      );
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: isActive && lyrics.synced
                                ? _ContrastSweepText(
                                    text: line.text,
                                    progress: progress,
                                    activeColor: ink,
                                    inactiveColor: ink.withAlpha(115),
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                  )
                                : Text(
                                    line.text,
                                    style: TextStyle(
                                      fontSize: 26,
                                      height: 1.24,
                                      letterSpacing: -0.5,
                                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                                      color: isActive ? ink : ink.withAlpha(90),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              if (_userScrollingLyrics && lyrics != null && lyrics.synced)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 6,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: () {
                        setState(() {
                          _userScrollingLyrics = false;
                          _lastActiveLyricIndex = -1;
                        });
                        _syncLyricsScroll(activeLyricIdx);
                      },
                      icon: const Icon(Icons.sync_rounded, size: 17),
                      label: const Text(
                        'Sinkron ulang',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Compact Track Header + Seek/Transport/Volume Deck matching screenshot 16-23-07-23
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ArtworkImage(url: track.bestThumbUrl(size: 160), size: 48, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          track.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.fullscreen_rounded, color: ink, size: 22),
                    tooltip: 'Mode ambient',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AmbientModeScreen()),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz_rounded, color: ink, size: 22),
                    tooltip: 'Opsi lirik',
                    onPressed: () => _showLyricsOptionsSheet(context, track, player),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSeekAndTransportDeck(
                context,
                player: player,
                settings: settings,
                totalMs: totalMs,
                currentMs: currentMs,
                remainingDur: remainingDur,
                ink: ink,
                sub: sub,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQueuePanel(
    BuildContext context,
    PlayerState player,
    bool isDark,
    Color ink,
    Color sub,
  ) {
    final queue = player.queue;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antrean',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink),
                    ),
                    Text(
                      player.playingContext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: sub),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.history_rounded, color: ink),
                tooltip: 'Riwayat',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.playlist_add_rounded, color: ink),
                tooltip: 'Simpan ke playlist',
                onPressed: () {
                  if (player.currentTrack != null) {
                    showTrackPlaylistPicker(context, ref, player.currentTrack!);
                  }
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  player.queueLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: player.queueLocked ? AppColors.horizonBlue : ink,
                ),
                tooltip: player.queueLocked ? 'Antrean terkunci' : 'Kunci antrean',
                onPressed: () => ref.read(playerProvider.notifier).toggleQueueLock(),
              ),
              Text(
                '${queue.length} lagu • ${_formatTotalQueueDuration(queue)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sub),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: queue.length,
            onReorder: (oldIndex, newIndex) {
              if (!player.queueLocked) {
                ref.read(playerProvider.notifier).reorderQueue(oldIndex, newIndex);
              }
            },
            itemBuilder: (_, idx) {
              final item = queue[idx];
              final isCurrent = idx == player.currentIndex;
              return Container(
                key: ValueKey('q_${item.id}_$idx'),
                color: isCurrent
                    ? (isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12))
                    : Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
                  onTap: () => ref.read(playerProvider.notifier).playTrack(
                        item,
                        queue: queue,
                        contextName: player.playingContext,
                      ),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Center(
                          child: isCurrent
                              ? AnimatedEqualizer(
                                  color: ink,
                                  isPlaying: player.isPlaying,
                                  size: 16,
                                )
                              : Text(
                                  (idx + 1).toString().padLeft(2, '0'),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.5,
                                    color: sub,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ArtworkImage(url: item.bestThumbUrl(size: 140), size: 46, radius: 8),
                    ],
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isCurrent ? AppColors.horizonBlue : ink,
                    ),
                  ),
                  subtitle: Text(
                    item.artistDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: sub),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.duration != null)
                        Text(
                          item.duration!,
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: sub),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.more_vert_rounded, size: 19, color: sub),
                        onPressed: () => showTrackOptionsSheet(context, ref, item),
                      ),
                      if (!player.queueLocked)
                        ReorderableDragStartListener(
                          index: idx,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.drag_handle_rounded, color: ink),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: player.shuffle ? ink : sub,
                ),
                onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
              ),
              IconButton(
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: ink, size: 28),
                onPressed: () => setState(() => _panelMode = 0),
              ),
              IconButton(
                icon: Icon(
                  player.repeat == RepeatSetting.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: player.repeat == RepeatSetting.off ? sub : ink,
                ),
                onPressed: () => ref.read(playerProvider.notifier).cycleRepeat(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomDock(
    BuildContext context,
    MusicItem track,
    PlayerState player,
    bool isDark,
    Color ink,
  ) {
    final pillBg = isDark ? Colors.white.withAlpha(26) : Colors.black.withAlpha(18);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dockBtn(
            icon: Icons.chat_bubble_outline_rounded,
            active: _panelMode == 1,
            pillBg: pillBg,
            ink: ink,
            onTap: () => setState(() => _panelMode = _panelMode == 1 ? 0 : 1),
          ),
          _dockBtn(
            icon: Icons.format_list_bulleted_rounded,
            active: _panelMode == 2,
            pillBg: pillBg,
            ink: ink,
            onTap: () => setState(() => _panelMode = _panelMode == 2 ? 0 : 2),
          ),
          _dockBtn(
            icon: Icons.ios_share_rounded,
            active: false,
            pillBg: pillBg,
            ink: ink,
            onTap: () => _showShareLinkSheet(context, track),
          ),
          _dockBtn(
            icon: Icons.nightlight_outlined,
            active: player.sleepTimerRemaining != null || player.stopAfterCurrentTrack,
            pillBg: pillBg,
            ink: ink,
            onTap: () => _showSleepTimerDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _dockBtn({
    required IconData icon,
    required bool active,
    required Color pillBg,
    required Color ink,
    required VoidCallback onTap,
  }) {
    return LiquidGlassTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: active ? pillBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: ink, size: 22),
      ),
    );
  }

  void _showShareLinkSheet(BuildContext context, MusicItem track) {
    final url = 'https://music.youtube.com/watch?v=${track.id}';
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final pill = AppColors.pillOf(context);

    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batalkan'),
                ),
                Expanded(
                  child: Text(
                    'Bagikan tautan',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Share.share('${track.title} — ${track.artistDisplay}\n$url');
                  },
                  child: const Text('Lainnya'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: pill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(fontSize: 13, color: sub),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tautan disalin ke papan klip')),
                  );
                },
                child: const Text('Salin'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioOutputSheet(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Output audio',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.smartphone_rounded, color: ink),
              title: Text('Speaker ponsel', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              subtitle: Text('Aktif saat ini', style: TextStyle(color: sub)),
              trailing: const Icon(Icons.check_circle_rounded, color: AppColors.horizonBlue),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bluetooth_audio_rounded, color: ink),
              title: Text('Perangkat Bluetooth / Headphone', style: TextStyle(color: ink)),
              subtitle: Text('Hubungkan via setelan Bluetooth sistem', style: TextStyle(color: sub)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio otomatis beralih saat perangkat tersambung')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    final settings = ref.read(settingsProvider);
    final player = ref.read(playerProvider);
    var minutes = (player.sleepTimerRemaining?.inMinutes ?? settings.defaultSleepMinutes)
        .clamp(5, 120);
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final card = isDark ? AppColors.darkSurface : Colors.white;
    final border = AppColors.borderOf(context);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(isDark ? 150 : 95),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Timer tidur',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$minutes menit',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: ink.withAlpha(210),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 8,
                          activeTrackColor: ink,
                          inactiveTrackColor: ink.withAlpha(30),
                          thumbColor: isDark ? Colors.white : Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 12,
                            elevation: 3,
                          ),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                        ),
                        child: Slider(
                          min: 5,
                          max: 120,
                          divisions: 23,
                          value: minutes.toDouble(),
                          onChanged: (v) => setModalState(() => minutes = v.round()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 196,
                        height: 46,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : const Color(0xFF111315),
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            ref.read(settingsProvider.notifier).setDefaultSleepMinutes(minutes);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$minutes menit dijadikan bawaan')),
                            );
                          },
                          child: const Text(
                            'Jadikan bawaan',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 140,
                        height: 40,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            side: BorderSide(color: border),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            ref.read(playerProvider.notifier).setSleepAfterTrack(true);
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Akhir lagu',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 0.7, color: border),
                InkWell(
                  onTap: () {
                    ref.read(playerProvider.notifier).setSleepTimer(Duration(minutes: minutes));
                    Navigator.pop(ctx);
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Center(
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 0.7, color: border),
                InkWell(
                  onTap: () {
                    ref.read(playerProvider.notifier).setSleepTimer(null);
                    Navigator.pop(ctx);
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Center(
                      child: Text(
                        'Atur ulang',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 0.7, color: border),
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Center(
                      child: Text(
                        'Batalkan',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: sub,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLyricsOptionsSheet(BuildContext context, MusicItem track, PlayerState player) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final st = modalRef.watch(settingsProvider);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _lOptionBtn(
                      context,
                      icon: Icons.edit_outlined,
                      label: 'Ubah lirik',
                      onTap: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Menggunakan lirik tersinkronisasi')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _lOptionBtn(
                      context,
                      icon: Icons.refresh_rounded,
                      label: 'Muat ulang\nlirik',
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(playerProvider.notifier).refreshLyrics();
                      },
                    ),
                    const SizedBox(width: 8),
                    _lOptionBtn(
                      context,
                      icon: Icons.search_rounded,
                      label: 'Cari lirik',
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(playerProvider.notifier).refreshLyrics();
                      },
                    ),
                    const SizedBox(width: 8),
                    _lOptionBtn(
                      context,
                      icon: Icons.copy_rounded,
                      label: 'Salin lirik',
                      onTap: () {
                        final txt = player.lyrics?.lines.map((l) => l.text).join('\n') ?? '';
                        if (txt.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: txt));
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lirik disalin')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: Text('Terjemahan lirik AI', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                  subtitle: Text('Tampilkan terjemahan bahasa pilihan', style: TextStyle(color: sub, fontSize: 12)),
                  value: st.aiTranslateLyrics,
                  onChanged: (v) => modalRef.read(settingsProvider.notifier).setAiTranslateLyrics(v),
                ),
                SwitchListTile(
                  title: Text('Ikuti posisi agen', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                  value: st.agentPositionSync,
                  onChanged: (v) => modalRef.read(settingsProvider.notifier).setAgentPositionSync(v),
                ),
                SwitchListTile(
                  title: Text('Tampilkan indikator interval', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                  value: st.showIntervalIndicator,
                  onChanged: (v) => modalRef.read(settingsProvider.notifier).setShowIntervalIndicator(v),
                ),
                ListTile(
                  title: Text('Sumber lirik', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                  subtitle: Text(st.lyricsSourceName, style: TextStyle(color: sub)),
                  trailing: Icon(Icons.chevron_right_rounded, color: sub),
                  onTap: () {
                    final next = st.lyricsSourceName == 'BiniLyrics' ? 'LRCLIB Sync' : 'BiniLyrics';
                    modalRef.read(settingsProvider.notifier).setLyricsSourceName(next);
                  },
                ),
                ListTile(
                  title: Text('Waktu lirik', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                  subtitle: Text('${st.lyricsOffsetMs} ms', style: TextStyle(color: sub)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: () => modalRef
                            .read(settingsProvider.notifier)
                            .setLyricsOffsetMs(st.lyricsOffsetMs - 250),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () => modalRef
                            .read(settingsProvider.notifier)
                            .setLyricsOffsetMs(st.lyricsOffsetMs + 250),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: Text('Romanisasi lirik', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                  value: st.romanizeLyrics,
                  onChanged: (v) => modalRef.read(settingsProvider.notifier).setRomanizeLyrics(v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _lOptionBtn(
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
          decoration: BoxDecoration(color: pill, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Icon(icon, size: 20, color: ink),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullNowPlayingOptions(BuildContext context, MusicItem track) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final pill = AppColors.pillOf(context);
    final border = AppColors.borderOf(context);

    showLiquidGlassSheet<void>(
      context: context,
      builder: (sheetCtx) => Consumer(
        builder: (sheetCtx, modalRef, _) {
          final pState = modalRef.watch(playerProvider);
          final lib = modalRef.watch(libraryProvider);
          final isDownloaded = lib.isDownloaded(track.id);
          final isLiked = lib.isLiked(track.id);
          final isPinned = lib.isPinnedSpeedDial(track.id);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
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
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                          ),
                          Text(
                            track.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: sub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.volume_down_rounded, size: 20, color: sub),
                    Expanded(
                      child: Slider(
                        min: 0.0,
                        max: 1.0,
                        value: pState.volume,
                        onChanged: (v) => modalRef.read(playerProvider.notifier).setVolume(v),
                      ),
                    ),
                    Icon(Icons.volume_up_rounded, size: 20, color: sub),
                  ],
                ),
                const SizedBox(height: 8),
                // 3 + 1 airy icon grid matching screenshots 16-22-59-10 / 14-11-47-94
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetGridBtn(
                      context,
                      pill: pill,
                      ink: ink,
                      icon: Icons.radio_rounded,
                      label: 'Mulai radio',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        ref.read(playerProvider.notifier).startRadio(track);
                      },
                    ),
                    const SizedBox(width: 8),
                    _sheetGridBtn(
                      context,
                      pill: pill,
                      ink: ink,
                      icon: Icons.playlist_add_rounded,
                      label: 'Tambah ke\nplaylist',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        showTrackPlaylistPicker(context, ref, track);
                      },
                    ),
                    const SizedBox(width: 8),
                    _sheetGridBtn(
                      context,
                      pill: pill,
                      ink: ink,
                      icon: Icons.link_rounded,
                      label: 'Salin link',
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: 'https://music.youtube.com/watch?v=${track.id}'),
                        );
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tautan disalin')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _sheetGridBtn(
                      context,
                      pill: pill,
                      ink: ink,
                      icon: Icons.share_outlined,
                      label: 'Bagikan\nkartu lagu',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _showShareSongCardModal(context, track);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox.shrink()),
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
                const SizedBox(height: 12),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isLiked ? 'Hapus dari pustaka' : 'Tambah ke pustaka',
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
                    color: ink,
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ref.read(libraryProvider.notifier).togglePinSpeedDial(track);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isDownloaded ? 'Hapus unduhan' : 'Unduh',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  trailing: Icon(
                    isDownloaded ? Icons.delete_outline_rounded : Icons.download_rounded,
                    color: ink,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    if (isDownloaded) {
                      await ref.read(libraryProvider.notifier).removeDownload(track.id);
                    } else {
                      try {
                        await ref.read(libraryProvider.notifier).downloadTrack(track);
                      } catch (_) {}
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Dengar bersama', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  trailing: Icon(Icons.group_outlined, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ListenTogetherScreen()),
                    );
                  },
                ),
                Divider(height: 1, color: border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Rincian', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  subtitle: Text('Lihat detail lagu', style: TextStyle(color: sub)),
                  trailing: Icon(Icons.info_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showSongMetadataDialog(context, track);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Mode ambient', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  subtitle: Text(
                    'Lagu yang sedang diputar ditampilkan layar penuh dengan tenang',
                    style: TextStyle(color: sub),
                  ),
                  trailing: Icon(Icons.fullscreen_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AmbientModeScreen()),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ekualiser', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  subtitle: Text('Buka ekualiser audio', style: TextStyle(color: sub)),
                  trailing: Icon(Icons.bar_chart_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const EqualizerScreen()),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ekualiser sistem', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  subtitle: Text('Buka Ekualiser Android bawaan', style: TextStyle(color: sub)),
                  trailing: Icon(Icons.graphic_eq_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const EqualizerScreen()),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Gaya suara', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  subtitle: Text(
                    'Sped up, slowed + reverb, lo-fi, 8D, dan lainnya',
                    style: TextStyle(color: sub),
                  ),
                  trailing: Icon(Icons.speed_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showSoundStylesSheet(context);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Lanjutan', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  subtitle: Text('Sesuaikan tempo dan nada lagu', style: TextStyle(color: sub)),
                  trailing: Icon(Icons.tune_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showAdvancedTempoPitchSheet(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sheetGridBtn(
    BuildContext context, {
    required Color pill,
    required Color ink,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: LiquidGlassTap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 25, color: ink),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSoundStylesSheet(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final current = modalRef.watch(playerProvider.select((s) => s.soundStyle));
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gaya suara',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ubah nuansa tempo dan nada lagu secara instan',
                  style: TextStyle(fontSize: 13, color: sub),
                ),
                const SizedBox(height: 10),
                ...SoundStylePreset.values.map(
                  (preset) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      preset.label,
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    subtitle: Text(preset.description, style: TextStyle(color: sub, fontSize: 12.5)),
                    trailing: current == preset
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.horizonBlue)
                        : null,
                    onTap: () async {
                      await modalRef.read(playerProvider.notifier).setSoundStyle(preset);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAdvancedTempoPitchSheet(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final pState = modalRef.watch(playerProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Lanjutan',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => modalRef.read(playerProvider.notifier).resetTempoPitch(),
                      child: const Text('Setel ulang'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tempo (${pState.playbackSpeed.toStringAsFixed(2)}x)',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                Slider(
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  value: pState.playbackSpeed,
                  onChanged: (v) => modalRef.read(playerProvider.notifier).setPlaybackSpeed(v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nada / Pitch (${pState.pitch.toStringAsFixed(2)}x)',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                Slider(
                  min: 0.5,
                  max: 1.5,
                  divisions: 20,
                  value: pState.pitch,
                  onChanged: (v) => modalRef.read(playerProvider.notifier).setPitch(v),
                ),
                Text(
                  'Geser ke kiri untuk lebih berat, ke kanan untuk lebih tinggi.',
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSongMetadataDialog(BuildContext context, MusicItem track) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rincian lagu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metaRow('Judul', track.title),
            _metaRow('Artis', track.artistDisplay),
            if (track.album?.name.isNotEmpty == true) _metaRow('Album', track.album!.name),
            _metaRow('ID Track', track.id),
            if (track.duration != null) _metaRow('Durasi', track.duration!),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _showShareSongCardModal(BuildContext context, MusicItem track) {
    final accent = ref.read(playerProvider).dynamicColor ?? AppColors.horizonBlue;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF1A222E), accent, 0.45)!,
                const Color(0xFF101318),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtworkImage(
                url: track.bestThumbUrl(size: 500),
                size: 240,
                radius: 16,
              ),
              const SizedBox(height: 16),
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                track.artistDisplay,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Lunarellys',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white60,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Share.share(
                        '🎵 ${track.title} — ${track.artistDisplay}\nhttps://music.youtube.com/watch?v=${track.id}',
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 17),
                    label: const Text('Bagikan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrostedRoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FrostedRoundAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(24) : Colors.white.withAlpha(115),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _ContrastSweepText extends StatelessWidget {
  final String text;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double fontSize;
  final FontWeight fontWeight;

  const _ContrastSweepText({
    required this.text,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.fontSize,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final split = (text.length * progress.clamp(0.0, 1.0)).round().clamp(0, text.length);
    final donePart = text.substring(0, split);
    final todoPart = text.substring(split);

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.28,
        ),
        children: [
          TextSpan(text: donePart, style: TextStyle(color: activeColor)),
          TextSpan(text: todoPart, style: TextStyle(color: inactiveColor)),
        ],
      ),
    );
  }
}

class AmbientModeScreen extends ConsumerWidget {
  const AmbientModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    final accent = player.dynamicColor ?? AppColors.horizonBlue;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 1.2,
              colors: [
                accent.withAlpha(115),
                const Color(0xFF0A0D12),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (track != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: ArtworkImage(
                        url: track.bestThumbUrl(size: 800),
                        size: math.min(MediaQuery.of(context).size.width * 0.72, 300),
                        radius: 24,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      track.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      track.artistDisplay,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                          onPressed: () => ref.read(playerProvider.notifier).skipPrevious(),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: Colors.white,
                            size: 62,
                          ),
                          onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                          onPressed: () => ref.read(playerProvider.notifier).skipNext(),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 36),
                  const Text(
                    'Ketuk di mana saja untuk keluar dari Mode ambient',
                    style: TextStyle(fontSize: 12.5, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
