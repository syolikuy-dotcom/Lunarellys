import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../services/chord_engine.dart';
import '../../services/device_permissions_service.dart';
import '../../state/dynamic_island_provider.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/animated_eq.dart';
import '../widgets/artwork_image.dart';
import '../widgets/ios_control_center.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/track_tile.dart';
import 'detail_screens.dart';
import 'poster_editor_screen.dart';

String _formatPlayerDuration(Duration d) {
  final totalSec = d.inSeconds.clamp(0, 359999);
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

int _findActiveLyricIndex(
  LyricsResult? lyrics,
  Duration position,
  int offsetMs,
) {
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

double _lyricLineProgress(
  LyricsResult? lyrics,
  int idx,
  Duration position,
  int offsetMs,
) {
  if (lyrics == null ||
      !lyrics.synced ||
      idx < 0 ||
      idx >= lyrics.lines.length) {
    return 1.0;
  }
  final curMs = lyrics.lines[idx].timeMs ?? 0;
  final nextMs =
      (idx + 1 < lyrics.lines.length && lyrics.lines[idx + 1].timeMs != null)
          ? lyrics.lines[idx + 1].timeMs!
          : (curMs + 4200);
  final span = (nextMs - curMs).clamp(600, 14000);
  final posMs = position.inMilliseconds + offsetMs;
  return ((posMs - curMs) / span).clamp(0.0, 1.0);
}

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  final ScrollController _lyricsScrollCtrl = ScrollController();
  int _panelMode = 0; // 0 = Player, 1 = Lyrics, 2 = Queue
  bool _lyricsFullscreen = false;
  bool _vinylMode = false;
  bool _videoMode = false;
  WebViewController? _videoController;
  String? _videoTrackId;
  Timer? _musicAlarmTimer;
  int? _musicAlarmMinutes;

  @override
  void dispose() {
    _musicAlarmTimer?.cancel();
    _lyricsScrollCtrl.dispose();
    super.dispose();
  }

  void _ensureVideoController(String trackId) {
    final embedUri = Uri.parse(
      'https://www.youtube.com/embed/$trackId?autoplay=1&playsinline=1&rel=0',
    );
    if (_videoController == null) {
      _videoController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadRequest(embedUri);
      _videoTrackId = trackId;
    } else if (_videoTrackId != trackId) {
      _videoTrackId = trackId;
      _videoController!.loadRequest(embedUri);
    }
  }

  void _scheduleMusicAlarm(int minutes, MusicItem track) {
    _musicAlarmTimer?.cancel();
    setState(() => _musicAlarmMinutes = minutes);
    _musicAlarmTimer = Timer(Duration(minutes: minutes), () {
      if (!mounted) return;
      setState(() => _musicAlarmMinutes = null);
      final p = ref.read(playerProvider);
      if (!p.isPlaying) {
        ref.read(playerProvider.notifier).togglePlayPause();
      }
      ref.read(dynamicIslandEventProvider.notifier).show(
            DynamicIslandEvent(
              icon: CupertinoIcons.alarm_fill,
              title: 'Alarm Musik Berbunyi',
              subtitle: track.title,
              accent: const Color(0xFF0A84FF),
            ),
          );
    });
  }

  void _cancelMusicAlarm() {
    _musicAlarmTimer?.cancel();
    _musicAlarmTimer = null;
    setState(() => _musicAlarmMinutes = null);
  }

  void _toggleLyricsPanel() {
    setState(() {
      if (_panelMode == 1) {
        _panelMode = 0;
        _lyricsFullscreen = false;
      } else {
        _panelMode = 1;
      }
    });
  }

  void _toggleQueuePanel() {
    setState(() {
      _lyricsFullscreen = false;
      _panelMode = _panelMode == 2 ? 0 : 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(playerProvider.select((s) => s.currentTrack));
    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Belum ada lagu yang diputar')),
      );
    }

    if (_videoMode && _videoTrackId != track.id) {
      _ensureVideoController(track.id);
    }

    final dynamicColor =
        ref.watch(playerProvider.select((s) => s.dynamicColor));
    final playingContext =
        ref.watch(playerProvider.select((s) => s.playingContext));
    final sleepActive = ref.watch(
      playerProvider.select(
        (s) => s.sleepTimerRemaining != null || s.stopAfterCurrentTrack,
      ),
    ) || _musicAlarmMinutes != null;
    final dynamicAlbumColors =
        ref.watch(settingsProvider.select((s) => s.dynamicAlbumColors));
    final playerBgStyle =
        ref.watch(settingsProvider.select((s) => s.playerBackgroundStyle));
    final isLiked =
        ref.watch(libraryProvider.select((s) => s.isLiked(track.id)));

    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    final baseAccent = dynamicAlbumColors
        ? (dynamicColor ?? const Color(0xFF9AA189))
        : const Color(0xFF9AA189);

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if (_panelMode == 0 && (d.primaryVelocity ?? 0) > 450) {
            Navigator.of(context).pop();
          } else if (_panelMode == 1 &&
              _lyricsFullscreen &&
              (d.primaryVelocity ?? 0) > 450) {
            setState(() => _lyricsFullscreen = false);
          }
        },
        child: _NowPlayingBackdrop(
          style: playerBgStyle,
          track: track,
          baseAccent: baseAccent,
          isDark: isDark,
          child: SafeArea(
            top: _panelMode != 0,
            child: Column(
              children: [
                if (_panelMode == 2)
                  Expanded(
                    child: _QueuePanelView(
                      isDark: isDark,
                      ink: ink,
                      sub: sub,
                      onCollapse: () => setState(() => _panelMode = 0),
                    ),
                  )
                else if (_panelMode == 1)
                  Expanded(
                    child: _LyricsPanelView(
                      scrollController: _lyricsScrollCtrl,
                      track: track,
                      fullscreen: _lyricsFullscreen,
                      isDark: isDark,
                      ink: ink,
                      sub: sub,
                      onToggleFullscreen: () => setState(
                        () => _lyricsFullscreen = !_lyricsFullscreen,
                      ),
                      onOpenOptions: () => _showLyricsOptionsSheet(
                        context,
                        track,
                        ref.read(playerProvider),
                      ),
                      onOpenAudioOutput: () => _showAudioOutputSheet(context),
                      onShareQuote: (quote) => _showShareSongCardModal(
                        context,
                        track,
                        quotedLyric: quote,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: _buildMainPlayerPanel(
                      context,
                      track: track,
                      playingContext: playingContext,
                      baseAccent: baseAccent,
                      isLiked: isLiked,
                      isDark: isDark,
                      ink: ink,
                      sub: sub,
                    ),
                  ),
                if (!(_panelMode == 1 && _lyricsFullscreen))
                  _buildBottomDock(
                    context,
                    track: track,
                    sleepActive: sleepActive,
                    isDark: isDark,
                    ink: ink,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainPlayerPanel(
    BuildContext context, {
    required MusicItem track,
    required String playingContext,
    required Color baseAccent,
    required bool isLiked,
    required bool isDark,
    required Color ink,
    required Color sub,
  }) {
    final topPad = MediaQuery.of(context).padding.top;
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final pill = AppColors.pillOf(context);
    final border = AppColors.borderOf(context);

    return Column(
      children: [
        // Clean edge-to-edge Top Header (separated from artwork so faces/titles are never covered)
        Padding(
          padding: EdgeInsets.fromLTRB(20, topPad + 6, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: sub.withAlpha(110),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sedang diputar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sub,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          playingContext.isNotEmpty
                              ? playingContext
                              : 'Mix ${track.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  LiquidGlassTap(
                    onTap: () => showIosControlCenter(
                      context,
                      ref,
                      onOpenEqualizer: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EqualizerScreen(),
                        ),
                      ),
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: pill,
                        shape: BoxShape.circle,
                        border: Border.all(color: border, width: 0.7),
                      ),
                      child: Icon(
                        CupertinoIcons.slider_horizontal_3,
                        color: ink,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  LiquidGlassTap(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: pill,
                        shape: BoxShape.circle,
                        border: Border.all(color: border, width: 0.7),
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        color: ink,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Full Uncropped Artwork Hero OR Spinning Vinyl Platter OR Embedded Video
        Expanded(
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _videoMode
                      ? Padding(
                          key: ValueKey('video_${track.id}'),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withAlpha(36),
                                      width: 1,
                                    ),
                                  ),
                                  child: _videoController != null
                                      ? WebViewWidget(controller: _videoController!)
                                      : const Center(
                                          child: CupertinoActivityIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : _vinylMode
                          ? Container(
                              key: const ValueKey('vinyl_stage'),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.only(bottom: 10),
                              child: LayoutBuilder(
                                builder: (ctx, c) {
                                  final maxDim = math.min(
                                    c.maxWidth * 0.72,
                                    c.maxHeight - 50,
                                  );
                                  final discSize = maxDim.clamp(140.0, 268.0);
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SpinningVinylDisc(
                                        artworkUrl: track.bestThumbUrl(size: 700),
                                        size: discSize,
                                        isPlaying: isPlaying,
                                        accentColor: baseAccent,
                                        showTonearm: true,
                                        onTap: () => ref
                                            .read(playerProvider.notifier)
                                            .togglePlayPause(),
                                      ),
                                      const SizedBox(height: 12),
                                      HarmonicSpectrumBars(
                                        isPlaying: isPlaying,
                                        color: AppColors.readableAccent(
                                          baseAccent,
                                          Theme.of(context).brightness,
                                        ),
                                        barCount: 24,
                                        height: 24,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            )
                          : LayoutBuilder(
                              key: const ValueKey('cover_stage'),
                              builder: (ctx, c) {
                                final artW = (c.maxWidth - 40).clamp(160.0, 440.0);
                                final artH = (c.maxHeight - 16).clamp(150.0, 440.0);
                                final frameSide = math.min(artW, artH);
                                final boxW = artW > frameSide * 1.18
                                    ? math.min(artW, frameSide * 1.38)
                                    : frameSide;
                                return Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withAlpha(isDark ? 115 : 44),
                                          blurRadius: 26,
                                          spreadRadius: -4,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: ArtworkImage(
                                      url: track.bestThumbUrl(size: 900),
                                      width: boxW,
                                      height: artH,
                                      size: boxW,
                                      radius: 22,
                                      preserveFull: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                // Left [Audio | Video] mode switcher capsule
                Positioned(
                  left: 24,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(isDark ? 148 : 168),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withAlpha(76),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _audioVideoSegment(
                          label: 'Audio',
                          selected: !_videoMode,
                          onTap: () {
                            if (_videoMode) {
                              HapticFeedback.selectionClick();
                              setState(() => _videoMode = false);
                            }
                          },
                        ),
                        _audioVideoSegment(
                          label: 'Video',
                          selected: _videoMode,
                          onTap: () {
                            if (!_videoMode) {
                              HapticFeedback.selectionClick();
                              if (isPlaying) {
                                ref.read(playerProvider.notifier).togglePlayPause();
                              }
                              _ensureVideoController(track.id);
                              setState(() {
                                _videoMode = true;
                                _vinylMode = false;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Interactive Sampul / Piringan Vinyl switcher pill
                if (!_videoMode)
                  Positioned(
                    right: 26,
                    bottom: 14,
                    child: LiquidGlassTap(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _vinylMode = !_vinylMode);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(isDark ? 148 : 168),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withAlpha(82),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(42),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _vinylMode
                                  ? CupertinoIcons.photo_fill
                                  : CupertinoIcons.circle_grid_hex_fill,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _vinylMode ? 'Sampul' : 'Piringan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Lower Control Deck (isolated ticking sub-widgets)
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
                            if (track.artists.isNotEmpty &&
                                track.artists.first.id != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ArtistScreen(
                                    artistId: track.artists.first.id!,
                                  ),
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
                    icon: isLiked
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    color: isLiked ? AppColors.iosPink : ink,
                    onTap: () =>
                        ref.read(libraryProvider.notifier).toggleLike(track),
                  ),
                  const SizedBox(width: 8),
                  _FrostedRoundAction(
                    icon: CupertinoIcons.ellipsis_vertical,
                    color: ink,
                    onTap: () => _showFullNowPlayingOptions(context, track),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _PlayerLyricSnippetPreview(
                ink: ink,
                sub: sub,
                onTap: () => setState(() => _panelMode = 1),
              ),
              const SizedBox(height: 6),
              _PlayerSeekBarDeck(ink: ink, sub: sub),
              const SizedBox(height: 6),
              _PlayerTransportButtons(ink: ink, sub: sub),
              const SizedBox(height: 2),
              _PlayerVolumeDeck(
                ink: ink,
                sub: sub,
                onOpenAudioOutput: () => _showAudioOutputSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomDock(
    BuildContext context, {
    required MusicItem track,
    required bool sleepActive,
    required bool isDark,
    required Color ink,
  }) {
    final pillBg =
        isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(20);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dockBtn(
            icon: CupertinoIcons.quote_bubble,
            active: _panelMode == 1,
            pillBg: pillBg,
            ink: ink,
            onTap: _toggleLyricsPanel,
          ),
          _dockBtn(
            icon: CupertinoIcons.list_bullet,
            active: _panelMode == 2,
            pillBg: pillBg,
            ink: ink,
            onTap: _toggleQueuePanel,
          ),
          _dockBtn(
            icon: CupertinoIcons.share,
            active: false,
            pillBg: pillBg,
            ink: ink,
            onTap: () => _showShareLinkSheet(context, track),
          ),
          _dockBtn(
            icon: sleepActive ? CupertinoIcons.moon_fill : CupertinoIcons.moon,
            active: sleepActive,
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
          border: active
              ? Border.all(
                  color: ink.withAlpha(24),
                  width: 0.7,
                )
              : null,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Share.share(
                        '${track.title} — ${track.artistDisplay}\n$url');
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
                    const SnackBar(
                      content: Text('Tautan disalin ke papan klip'),
                    ),
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
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.smartphone_rounded, color: ink),
              title: Text(
                'Speaker ponsel',
                style: TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              subtitle: Text('Aktif saat ini', style: TextStyle(color: sub)),
              trailing: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.horizonBlue,
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bluetooth_audio_rounded, color: ink),
              title: Text(
                'Perangkat Bluetooth / Headphone',
                style: TextStyle(color: ink),
              ),
              subtitle: Text(
                'Hubungkan via setelan Bluetooth sistem',
                style: TextStyle(color: sub),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Audio otomatis beralih saat perangkat tersambung',
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(CupertinoIcons.slider_horizontal_3, color: ink),
              title: Text(
                'Ekualiser & DSP 5-Band',
                style: TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              subtitle: Text(
                'Atur preset frekuensi & bass boost',
                style: TextStyle(color: sub),
              ),
              trailing: Icon(CupertinoIcons.chevron_forward, size: 16, color: sub),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EqualizerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioVideoSegment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white.withAlpha(210),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    final settings = ref.read(settingsProvider);
    final player = ref.read(playerProvider);
    final track = player.currentTrack;
    var minutes =
        (player.sleepTimerRemaining?.inMinutes ?? settings.defaultSleepMinutes)
            .clamp(5, 120);
    var alarmMinutes = _musicAlarmMinutes ?? 30;
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final border = AppColors.borderOf(context);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(isDark ? 150 : 95),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: LiquidGlassSurface(
            borderRadius: BorderRadius.circular(28),
            blurSigma: 28,
            chromaticAccent: const Color(0xFFF59E0B),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Timer tidur & Alarm',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$minutes menit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ink.withAlpha(210),
                          ),
                        ),
                        const SizedBox(height: 12),
                        LiquidGlassRangeSlider(
                          min: 5,
                          max: 120,
                          value: minutes.toDouble(),
                          activeColor: const Color(0xFFF59E0B),
                          onChanged: (v) =>
                              setModalState(() => minutes = v.round()),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.white
                                      : const Color(0xFF111315),
                                  foregroundColor:
                                      isDark ? Colors.black : Colors.white,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                onPressed: () {
                                  ref
                                      .read(settingsProvider.notifier)
                                      .setDefaultSleepMinutes(minutes);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$minutes menit dijadikan bawaan'),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Jadikan bawaan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ink,
                                  side: BorderSide(color: border),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                onPressed: () {
                                  ref
                                      .read(playerProvider.notifier)
                                      .setSleepAfterTrack(true);
                                  ref.read(dynamicIslandEventProvider.notifier).show(
                                        const DynamicIslandEvent(
                                          icon: Icons.bedtime_rounded,
                                          title: 'Berhenti di Akhir Lagu',
                                          accent: Color(0xFFF59E0B),
                                        ),
                                      );
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  'Akhir lagu',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (track != null) ...[
                          const SizedBox(height: 16),
                          Divider(height: 1, color: border),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.alarm_fill,
                                size: 17,
                                color: AppColors.iosBlue,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Alarm Musik',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                              const Spacer(),
                              if (_musicAlarmMinutes != null)
                                GestureDetector(
                                  onTap: () {
                                    _cancelMusicAlarm();
                                    setModalState(() {});
                                  },
                                  child: Text(
                                    'Aktif (${_musicAlarmMinutes}m) ×',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.iosRed,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final m in const [15, 30, 60, 120])
                                ChoiceChip(
                                  label: Text('${m}m'),
                                  selected: alarmMinutes == m,
                                  onSelected: (_) =>
                                      setModalState(() => alarmMinutes = m),
                                ),
                              FilledButton.tonal(
                                onPressed: () {
                                  _scheduleMusicAlarm(alarmMinutes, track);
                                  ref.read(dynamicIslandEventProvider.notifier).show(
                                        DynamicIslandEvent(
                                          icon: CupertinoIcons.alarm_fill,
                                          title: 'Alarm Musik $alarmMinutes menit',
                                          subtitle: track.title,
                                          accent: AppColors.iosBlue,
                                        ),
                                      );
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  'Setel Alarm',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 0.7, color: border),
                  InkWell(
                    onTap: () {
                      ref
                          .read(playerProvider.notifier)
                          .setSleepTimer(Duration(minutes: minutes));
                      ref.read(dynamicIslandEventProvider.notifier).show(
                            DynamicIslandEvent(
                              icon: Icons.bedtime_rounded,
                              title: 'Timer Tidur $minutes menit',
                              accent: const Color(0xFFF59E0B),
                            ),
                          );
                      Navigator.pop(ctx);
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Center(
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 15.5,
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
                      _cancelMusicAlarm();
                      ref.read(dynamicIslandEventProvider.notifier).show(
                            const DynamicIslandEvent(
                              icon: Icons.bedtime_off_rounded,
                              title: 'Timer Tidur Dimatikan',
                              accent: Color(0xFFF59E0B),
                            ),
                          );
                      Navigator.pop(ctx);
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Center(
                        child: Text(
                          'Atur ulang',
                          style: TextStyle(
                            fontSize: 15,
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
                      height: 48,
                      child: Center(
                        child: Text(
                          'Batalkan',
                          style: TextStyle(
                            fontSize: 15,
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
      ),
    );
  }

  void _showLyricsOptionsSheet(
    BuildContext context,
    MusicItem track,
    PlayerState player,
  ) {
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
                          const SnackBar(
                            content: Text('Menggunakan lirik tersinkronisasi'),
                          ),
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
                        final txt =
                            player.lyrics?.lines.map((l) => l.text).join('\n') ??
                                '';
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
                ListTile(
                  leading: Icon(Icons.blur_on_rounded, color: ink),
                  title: Text(
                    'Mode ambient',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Tampilan fokus sampul layar penuh',
                    style: TextStyle(color: sub, fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: sub),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AmbientModeScreen(),
                      ),
                    );
                  },
                ),
                LiquidGlassSwitchTile(
                  title: const Text('Terjemahan lirik AI'),
                  subtitle: const Text('Tampilkan terjemahan bahasa pilihan'),
                  value: st.aiTranslateLyrics,
                  onChanged: (v) async {
                    await modalRef
                        .read(settingsProvider.notifier)
                        .setAiTranslateLyrics(v);
                    if (v) {
                      unawaited(ref.read(playerProvider.notifier).enrichLyrics());
                    }
                  },
                ),
                LiquidGlassSwitchTile(
                  title: const Text('Ikuti posisi agen'),
                  value: st.agentPositionSync,
                  onChanged: (v) => modalRef
                      .read(settingsProvider.notifier)
                      .setAgentPositionSync(v),
                ),
                LiquidGlassSwitchTile(
                  title: const Text('Tampilkan indikator interval'),
                  value: st.showIntervalIndicator,
                  onChanged: (v) => modalRef
                      .read(settingsProvider.notifier)
                      .setShowIntervalIndicator(v),
                ),
                ListTile(
                  title: Text(
                    'Sumber lirik',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    st.lyricsSourceName,
                    style: TextStyle(color: sub),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: sub),
                  onTap: () {
                    final idx = kLyricsSources.indexOf(st.lyricsSourceName);
                    final next =
                        kLyricsSources[(idx + 1) % kLyricsSources.length];
                    modalRef
                        .read(settingsProvider.notifier)
                        .setLyricsSourceName(next);
                  },
                ),
                ListTile(
                  title: Text(
                    'Waktu lirik',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${st.lyricsOffsetMs} ms',
                    style: TextStyle(color: sub),
                  ),
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
                LiquidGlassSwitchTile(
                  title: const Text('Romanisasi lirik'),
                  value: st.romanizeLyrics,
                  onChanged: (v) async {
                    await modalRef
                        .read(settingsProvider.notifier)
                        .setRomanizeLyrics(v);
                    if (v) {
                      unawaited(ref.read(playerProvider.notifier).enrichLyrics());
                    }
                  },
                ),
                LiquidGlassSwitchTile(
                  title: const Text('Tampilkan di Lock Screen'),
                  subtitle: const Text(
                    'Buka panel lirik langsung dari notifikasi layar kunci',
                  ),
                  value: st.lockScreenLyricsEnabled,
                  onChanged: (v) async {
                    await modalRef
                        .read(settingsProvider.notifier)
                        .setLockScreenLyricsEnabled(v);
                    if (v &&
                        !modalRef
                            .read(devicePermissionsProvider)
                            .notificationsGranted) {
                      await modalRef
                          .read(devicePermissionsProvider.notifier)
                          .requestNotifications();
                    }
                  },
                ),
                ListTile(
                  leading: Icon(CupertinoIcons.lock_fill, color: ink),
                  title: Text(
                    'Pratinjau Lock Screen',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w600),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: sub),
                  onTap: () {
                    Navigator.pop(ctx);
                    modalRef
                        .read(devicePermissionsProvider.notifier)
                        .openLockScreenPreview();
                  },
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
          decoration: BoxDecoration(
            color: pill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: ink),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
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
          final volume = modalRef.watch(playerProvider.select((s) => s.volume));
          final isDownloaded = modalRef
              .watch(libraryProvider.select((s) => s.isDownloaded(track.id)));
          final isLiked =
              modalRef.watch(libraryProvider.select((s) => s.isLiked(track.id)));
          final isPinned = modalRef.watch(
            libraryProvider.select((s) => s.isPinnedSpeedDial(track.id)),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ArtworkImage(
                      url: track.bestThumbUrl(size: 160),
                      size: 50,
                      radius: 10,
                    ),
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
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: ink,
                            ),
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
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kontrol Pemutar',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: sub,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 224,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left vertical iOS Volume Bar
                      _VerticalVolumeBentoBar(
                        volume: volume,
                        ink: ink,
                        pill: pill,
                        onChanged: (v) =>
                            modalRef.read(playerProvider.notifier).setVolume(v),
                      ),
                      const SizedBox(width: 10),
                      // Right Bento Tiles Grid (3 columns x 3 rows)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.moon_stars_fill,
                                    label: 'Timer tidur',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      _showSleepTimerDialog(context);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.slider_horizontal_3,
                                    label: 'Ekualiser',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const EqualizerScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.waveform_path_ecg,
                                    label: 'Gaya suara',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      _showSoundStylesSheet(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.speedometer,
                                    label: 'Tempo & nada',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      _showAdvancedTempoPitchSheet(context);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.sparkles,
                                    label: 'Ambient',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const AmbientModeScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.radiowaves_right,
                                    label: 'Mulai radio',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      ref.read(playerProvider.notifier).startRadio(track);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.text_quote,
                                    label: 'Bagikan lirik',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      _showShareSongCardModal(context, track);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.photo_on_rectangle,
                                    label: 'Buat poster',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              PosterEditorScreen(initialTrack: track),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _bentoTile(
                                    pill: pill,
                                    ink: ink,
                                    icon: CupertinoIcons.music_note_list,
                                    label: 'Playlist',
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      showTrackPlaylistPicker(context, ref, track);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _sheetGridBtn(
                      context,
                      pill: pill,
                      ink: ink,
                      icon: Icons.link_rounded,
                      label: 'Salin\ntautan',
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: 'https://music.youtube.com/watch?v=${track.id}',
                          ),
                        );
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tautan disalin')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _sheetGridBtn(
                      context,
                      pill: pill,
                      ink: ink,
                      icon: Icons.replay_10_rounded,
                      label: 'Mundur\n10 detik',
                      onTap: () {
                        ref
                            .read(playerProvider.notifier)
                            .seekRelative(const Duration(seconds: -10));
                      },
                    ),
                    const SizedBox(width: 8),
                    _sheetGridBtn(
                      context,
                      pill: pill,
                      ink: ink,
                      icon: Icons.forward_10_rounded,
                      label: 'Maju\n10 detik',
                      onTap: () {
                        ref
                            .read(playerProvider.notifier)
                            .seekRelative(const Duration(seconds: 10));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (loopCtx) {
                    final loopA = modalRef.watch(playerProvider.select((s) => s.loopStart));
                    final loopB = modalRef.watch(playerProvider.select((s) => s.loopEnd));
                    final loopActive = loopA != null && loopB != null;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: pill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 18,
                            color: loopActive ? AppColors.horizonBlue : ink,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loopActive
                                  ? 'Loop ${_formatPlayerDuration(loopA)} – ${_formatPlayerDuration(loopB)}'
                                  : loopA != null
                                      ? 'Titik A: ${_formatPlayerDuration(loopA)}'
                                      : 'Loop Bagian (A–B)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                modalRef.read(playerProvider.notifier).setLoopA(),
                            child: Text(loopA != null ? 'A*' : 'Set A'),
                          ),
                          TextButton(
                            onPressed: () =>
                                modalRef.read(playerProvider.notifier).setLoopB(),
                            child: Text(loopB != null ? 'B*' : 'Set B'),
                          ),
                          if (loopA != null || loopB != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.close_rounded, size: 18, color: sub),
                              onPressed: () =>
                                  modalRef.read(playerProvider.notifier).clearABLoop(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: border),
                if (track.artists.isNotEmpty && track.artists.first.id != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Lihat artis',
                      style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                    ),
                    subtitle: Text(
                      track.artists.first.name,
                      style: TextStyle(color: sub),
                    ),
                    trailing: Icon(Icons.record_voice_over_outlined, color: ink),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ArtistScreen(artistId: track.artists.first.id!),
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
                    isLiked
                        ? Icons.library_add_check_rounded
                        : Icons.library_add_outlined,
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
                    isPinned
                        ? 'Lepas dari speed dial'
                        : 'Sematkan ke speed dial',
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
                    isDownloaded
                        ? Icons.delete_outline_rounded
                        : Icons.download_rounded,
                    color: ink,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    if (isDownloaded) {
                      await ref
                          .read(libraryProvider.notifier)
                          .removeDownload(track.id);
                    } else {
                      try {
                        await ref
                            .read(libraryProvider.notifier)
                            .downloadTrack(track);
                      } catch (_) {}
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Dengar bersama',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  trailing: Icon(Icons.group_outlined, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ListenTogetherScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Rincian',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  subtitle: Text(
                    'Lihat detail lagu',
                    style: TextStyle(color: sub),
                  ),
                  trailing: Icon(Icons.info_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showSongMetadataDialog(context, track);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Mode ambient',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  subtitle: Text(
                    'Lagu yang sedang diputar ditampilkan layar penuh dengan tenang',
                    style: TextStyle(color: sub),
                  ),
                  trailing: Icon(Icons.fullscreen_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AmbientModeScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Ekualiser',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  subtitle: Text(
                    'Buka ekualiser audio',
                    style: TextStyle(color: sub),
                  ),
                  trailing: Icon(Icons.bar_chart_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EqualizerScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Ekualiser sistem',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  subtitle: Text(
                    'Buka Ekualiser Android bawaan',
                    style: TextStyle(color: sub),
                  ),
                  trailing: Icon(Icons.graphic_eq_rounded, color: ink),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EqualizerScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Gaya suara',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
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
                  title: Text(
                    'Lanjutan',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  subtitle: Text(
                    'Sesuaikan tempo dan nada lagu',
                    style: TextStyle(color: sub),
                  ),
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

  Widget _bentoTile({
    required Color pill,
    required Color ink,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: LiquidGlassTap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: pill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: ink),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
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
          final current =
              modalRef.watch(playerProvider.select((s) => s.soundStyle));
          final maxH = MediaQuery.of(ctx).size.height * 0.72;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gaya suara',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ubah nuansa tempo dan nada lagu secara instan',
                    style: TextStyle(fontSize: 13, color: sub),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: SoundStylePreset.values
                          .map(
                            (preset) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                preset.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              subtitle: Text(
                                preset.description,
                                style: TextStyle(color: sub, fontSize: 12.5),
                              ),
                              trailing: current == preset
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.iosBlue,
                                    )
                                  : Icon(
                                      Icons.radio_button_unchecked_rounded,
                                      color: sub.withAlpha(110),
                                    ),
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                await modalRef
                                    .read(playerProvider.notifier)
                                    .setSoundStyle(preset);
                                ref.read(dynamicIslandEventProvider.notifier).show(
                                      DynamicIslandEvent(
                                        icon: Icons.speed_rounded,
                                        title: 'Gaya Audio: ${preset.label}',
                                        subtitle: preset.description,
                                        accent: const Color(0xFFEC4899),
                                      ),
                                    );
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.iosBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Oke',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
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
          final speed =
              modalRef.watch(playerProvider.select((s) => s.playbackSpeed));
          final pitch = modalRef.watch(playerProvider.select((s) => s.pitch));
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
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          modalRef.read(playerProvider.notifier).resetTempoPitch(),
                      child: const Text('Setel ulang'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tempo (${speed.toStringAsFixed(2)}x)',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 6),
                LiquidGlassRangeSlider(
                  min: 0.5,
                  max: 2.0,
                  value: speed,
                  onChanged: (v) => modalRef
                      .read(playerProvider.notifier)
                      .setPlaybackSpeed(v),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nada / Pitch (${pitch.toStringAsFixed(2)}x)',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 6),
                LiquidGlassRangeSlider(
                  min: 0.5,
                  max: 1.5,
                  value: pitch,
                  onChanged: (v) =>
                      modalRef.read(playerProvider.notifier).setPitch(v),
                ),
                const SizedBox(height: 6),
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
    showArchysGlassDialog<void>(
      context: context,
      title: const Text('Rincian lagu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metaRow('Judul', track.title),
          _metaRow('Artis', track.artistDisplay),
          if (track.album?.name.isNotEmpty == true)
            _metaRow('Album', track.album!.name),
          _metaRow('ID Track', track.id),
          if (track.duration != null) _metaRow('Durasi', track.duration!),
        ],
      ),
      actionsBuilder: (ctx) => [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _showShareSongCardModal(
    BuildContext context,
    MusicItem track, {
    String? quotedLyric,
  }) {
    final accent = ref.read(playerProvider).dynamicColor ?? AppColors.iosBlue;
    final lyrics = ref.read(playerProvider).lyrics;
    final allLines = lyrics?.lines
            .map((l) => l.text.trim())
            .where((t) => t.isNotEmpty && t != '•••')
            .toList() ??
        const <String>[];

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(190),
      builder: (ctx) => _ShareLyricsStudioModal(
        track: track,
        accent: accent,
        initialQuote: quotedLyric,
        lyricLines: allLines,
      ),
    );
  }
}

class _VerticalVolumeBentoBar extends StatelessWidget {
  final double volume;
  final Color ink;
  final Color pill;
  final ValueChanged<double> onChanged;

  const _VerticalVolumeBentoBar({
    required this.volume,
    required this.ink,
    required this.pill,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (volume.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: 64,
      child: LayoutBuilder(
        builder: (ctx, c) {
          final h = c.maxHeight > 0 ? c.maxHeight : 200.0;
          void updateFromDy(double dy) {
            final next = (1.0 - (dy / h)).clamp(0.0, 1.0);
            onChanged(next);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (d) => updateFromDy(d.localPosition.dy),
            onVerticalDragUpdate: (d) => updateFromDy(d.localPosition.dy),
            onTapDown: (d) => updateFromDy(d.localPosition.dy),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: pill),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: volume.clamp(0.04, 1.0),
                      widthFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.iosBlue.withAlpha(220),
                              AppColors.iosBlue,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '$pct%',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: pct > 78 ? Colors.white : ink,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Icon(
                          volume <= 0.02
                              ? CupertinoIcons.volume_off
                              : CupertinoIcons.volume_up,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShareLyricsStudioModal extends StatefulWidget {
  final MusicItem track;
  final Color accent;
  final String? initialQuote;
  final List<String> lyricLines;

  const _ShareLyricsStudioModal({
    required this.track,
    required this.accent,
    this.initialQuote,
    this.lyricLines = const [],
  });

  @override
  State<_ShareLyricsStudioModal> createState() =>
      _ShareLyricsStudioModalState();
}

class _ShareLyricsStudioModalState extends State<_ShareLyricsStudioModal>
    with SingleTickerProviderStateMixin {
  final GlobalKey _captureKey = GlobalKey();
  late final AnimationController _karaokeCtrl;

  String _mode = 'Lirik'; // 'Fokus' | 'Lirik' | 'Kartu pemutar'
  String _ratio = '4:5'; // '1:1' | '4:5' | '9:16' | '16:9'
  String _bgStyle = 'Gradasi'; // 'Kaca' | 'Polos' | 'Buram' | 'Gradasi'
  String _fontFamily = 'Plus Jakarta Sans';
  bool _boldWeight = true;
  bool _centerAlign = false;
  double _startOffsetSec = 0.0;
  bool _animateKaraoke = true;
  bool _exporting = false;
  late List<String> _selectedLines;

  static const _modes = ['Fokus', 'Lirik', 'Kartu pemutar'];
  static const _ratios = ['1:1', '4:5', '9:16', '16:9'];
  static const _bgStyles = ['Kaca', 'Polos', 'Buram', 'Gradasi'];
  static const _fonts = [
    'Plus Jakarta Sans',
    'Inter',
    'Playfair',
    'JetBrains Mono',
  ];

  @override
  void initState() {
    super.initState();
    _karaokeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();

    if (widget.initialQuote != null && widget.initialQuote!.trim().isNotEmpty) {
      final idx = widget.lyricLines.indexWhere(
        (l) => l.toLowerCase() == widget.initialQuote!.trim().toLowerCase(),
      );
      if (idx != -1) {
        _selectedLines = widget.lyricLines
            .skip(idx)
            .take(2)
            .toList();
      } else {
        _selectedLines = [widget.initialQuote!.trim()];
      }
      _mode = 'Lirik';
    } else if (widget.lyricLines.isNotEmpty) {
      _selectedLines = widget.lyricLines.take(2).toList();
      _mode = 'Lirik';
    } else {
      _selectedLines = ['${widget.track.title} — ${widget.track.artistDisplay}'];
      _mode = 'Kartu pemutar';
    }
  }

  @override
  void dispose() {
    _karaokeCtrl.dispose();
    super.dispose();
  }

  double get _aspectRatioValue {
    switch (_ratio) {
      case '1:1':
        return 1.0;
      case '9:16':
        return 9 / 16;
      case '16:9':
        return 16 / 9;
      case '4:5':
      default:
        return 4 / 5;
    }
  }

  TextStyle _quoteTextStyle(Color fg) {
    final weight = _boldWeight ? FontWeight.w800 : FontWeight.w500;
    final baseSize = _mode == 'Fokus' ? 20.0 : 16.5;
    switch (_fontFamily) {
      case 'Playfair':
        return GoogleFonts.playfairDisplay(
          fontSize: baseSize + 1,
          fontWeight: weight,
          height: 1.28,
          color: fg,
        );
      case 'JetBrains Mono':
        return GoogleFonts.jetBrainsMono(
          fontSize: baseSize - 1.5,
          fontWeight: weight,
          height: 1.32,
          color: fg,
        );
      case 'Inter':
        return GoogleFonts.inter(
          fontSize: baseSize,
          fontWeight: weight,
          height: 1.28,
          color: fg,
        );
      case 'Plus Jakarta Sans':
      default:
        return GoogleFonts.plusJakartaSans(
          fontSize: baseSize,
          fontWeight: weight,
          height: 1.28,
          color: fg,
        );
    }
  }

  Future<void> _exportAndShare({bool saveOnly = false}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final img = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await img.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/archys_lirik_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(outPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (saveOnly) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kartu lirik tersimpan di ${file.path}')),
          );
        }
      } else {
        final quote = _selectedLines.join('\n');
        await Share.shareXFiles(
          [XFile(outPath)],
          text:
              '"$quote"\n\n🎵 ${widget.track.title} — ${widget.track.artistDisplay}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ekspor gambar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final pill = AppColors.pillOf(context);
    final quoteText = _selectedLines.join('\n');

    final List<Color> gradColors = switch (_bgStyle) {
      'Polos' => [const Color(0xFF101319), const Color(0xFF07090D)],
      'Kaca' => [
          Color.lerp(const Color(0xFF1E293B), widget.accent, 0.25)!,
          Color.lerp(const Color(0xFF0F172A), widget.accent, 0.14)!,
        ],
      _ => [
          Color.lerp(const Color(0xFF1D283A), widget.accent, 0.56)!,
          Color.lerp(const Color(0xFF0C111B), widget.accent, 0.18)!,
        ],
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(28),
        blurSigma: 26,
        chromaticAccent: widget.accent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Studio Bagikan Lirik',
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(CupertinoIcons.xmark_circle_fill, color: sub),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Live Card Preview Stage
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: AspectRatio(
                    aspectRatio: _aspectRatioValue,
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_bgStyle == 'Buram')
                              Positioned.fill(
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: 18,
                                    sigmaY: 18,
                                    tileMode: TileMode.clamp,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: ArtworkImage(
                                      url: widget.track.bestThumbUrl(size: 500),
                                      size: 320,
                                      radius: 0,
                                    ),
                                  ),
                                ),
                              )
                            else
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: gradColors,
                                  ),
                                ),
                              ),
                            Container(
                              color: Colors.black.withAlpha(
                                _bgStyle == 'Buram' ? 115 : (_bgStyle == 'Kaca' ? 40 : 20),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: _centerAlign
                                    ? CrossAxisAlignment.center
                                    : CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Header track info
                                  Row(
                                    mainAxisAlignment: _centerAlign
                                        ? MainAxisAlignment.center
                                        : MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ArtworkImage(
                                        url: widget.track.bestThumbUrl(size: 200),
                                        size: _mode == 'Kartu pemutar' ? 54 : 38,
                                        radius: 10,
                                        preserveFull: true,
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              widget.track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              widget.track.artistDisplay,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Quote body or Player Card bar
                                  if (_mode != 'Kartu pemutar')
                                    Flexible(
                                      child: AnimatedBuilder(
                                        animation: _karaokeCtrl,
                                        builder: (_, __) {
                                          final p = _animateKaraoke
                                              ? _karaokeCtrl.value
                                              : 1.0;
                                          final split = (quoteText.length * p)
                                              .round()
                                              .clamp(0, quoteText.length);
                                          final baseStyle =
                                              _quoteTextStyle(Colors.white);
                                          return RichText(
                                            textAlign: _centerAlign
                                                ? TextAlign.center
                                                : TextAlign.left,
                                            maxLines: 5,
                                            overflow: TextOverflow.ellipsis,
                                            text: TextSpan(
                                              style: baseStyle,
                                              children: [
                                                TextSpan(
                                                  text: quoteText.substring(0, split),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: quoteText.substring(split),
                                                  style: TextStyle(
                                                    color: Colors.white.withAlpha(118),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(24),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withAlpha(55),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            CupertinoIcons.play_fill,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: LinearProgressIndicator(
                                              value: 0.42,
                                              backgroundColor: Colors.white24,
                                              color: Colors.white,
                                              minHeight: 3,
                                              borderRadius: BorderRadius.circular(99),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Bottom Archys watermark
                                  Row(
                                    mainAxisAlignment: _centerAlign
                                        ? MainAxisAlignment.center
                                        : MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppConfig.appName,
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(190),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (_startOffsetSec != 0 && !_centerAlign)
                                        Text(
                                          '${_startOffsetSec > 0 ? '+' : ''}${_startOffsetSec.toStringAsFixed(1)} dtk',
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(145),
                                            fontSize: 10.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Mode selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in _modes) ...[
                      ChoiceChip(
                        label: Text(m),
                        selected: _mode == m,
                        onSelected: (_) => setState(() => _mode = m),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Ratio + Background + Font controls
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final r in _ratios) ...[
                      _miniChip(
                        label: r,
                        selected: _ratio == r,
                        pill: pill,
                        ink: ink,
                        onTap: () => setState(() => _ratio = r),
                      ),
                      const SizedBox(width: 5),
                    ],
                    const SizedBox(width: 6),
                    for (final b in _bgStyles) ...[
                      _miniChip(
                        label: b,
                        selected: _bgStyle == b,
                        pill: pill,
                        ink: ink,
                        onTap: () => setState(() => _bgStyle = b),
                      ),
                      const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _fonts) ...[
                      _miniChip(
                        label: f,
                        selected: _fontFamily == f,
                        pill: pill,
                        ink: ink,
                        onTap: () => setState(() => _fontFamily = f),
                      ),
                      const SizedBox(width: 5),
                    ],
                    const SizedBox(width: 6),
                    _miniChip(
                      label: _boldWeight ? 'Tebal' : 'Normal',
                      selected: _boldWeight,
                      pill: pill,
                      ink: ink,
                      onTap: () => setState(() => _boldWeight = !_boldWeight),
                    ),
                    const SizedBox(width: 5),
                    _miniChip(
                      label: _centerAlign ? 'Tengah' : 'Kiri',
                      selected: _centerAlign,
                      pill: pill,
                      ink: ink,
                      onTap: () => setState(() => _centerAlign = !_centerAlign),
                    ),
                    const SizedBox(width: 5),
                    _miniChip(
                      label: _animateKaraoke ? 'Karaoke' : 'Statis',
                      selected: _animateKaraoke,
                      pill: pill,
                      ink: ink,
                      onTap: () {
                        setState(() {
                          _animateKaraoke = !_animateKaraoke;
                          if (_animateKaraoke) {
                            _karaokeCtrl.repeat();
                          } else {
                            _karaokeCtrl.stop();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Start offset (-0,5 dtk / +0,5 dtk) & Lyric lines picker
              Row(
                children: [
                  Text(
                    'Mulai: ${_startOffsetSec.toStringAsFixed(1)} dtk',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sub),
                  ),
                  const SizedBox(width: 8),
                  _miniChip(
                    label: '-0,5 dtk',
                    selected: false,
                    pill: pill,
                    ink: ink,
                    onTap: () => setState(
                      () => _startOffsetSec = (_startOffsetSec - 0.5).clamp(-5.0, 5.0),
                    ),
                  ),
                  const SizedBox(width: 5),
                  _miniChip(
                    label: '+0,5 dtk',
                    selected: false,
                    pill: pill,
                    ink: ink,
                    onTap: () => setState(
                      () => _startOffsetSec = (_startOffsetSec + 0.5).clamp(-5.0, 5.0),
                    ),
                  ),
                ],
              ),
              if (widget.lyricLines.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.lyricLines.take(18).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final l = widget.lyricLines[i];
                      final sel = _selectedLines.contains(l);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (sel && _selectedLines.length > 1) {
                              _selectedLines.remove(l);
                            } else if (!sel) {
                              if (_selectedLines.length >= 3) {
                                _selectedLines.removeAt(0);
                              }
                              _selectedLines.add(l);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.iosBlue : pill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : ink,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Save & Share Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => _exportAndShare(saveOnly: true),
                      icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 17),
                      label: const Text('Simpan gambar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : AppColors.iosBlue,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                      ),
                      onPressed: _exporting ? null : () => _exportAndShare(),
                      icon: _exporting
                          ? const CupertinoActivityIndicator(radius: 8)
                          : const Icon(CupertinoIcons.share, size: 17),
                      label: const Text('Bagikan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip({
    required String label,
    required bool selected,
    required Color pill,
    required Color ink,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.iosBlue : pill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : ink,
          ),
        ),
      ),
    );
  }
}

class _NowPlayingBackdrop extends StatefulWidget {
  final PlayerBackgroundStyle style;
  final MusicItem track;
  final Color baseAccent;
  final bool isDark;
  final Widget child;

  const _NowPlayingBackdrop({
    required this.style,
    required this.track,
    required this.baseAccent,
    required this.isDark,
    required this.child,
  });

  @override
  State<_NowPlayingBackdrop> createState() => _NowPlayingBackdropState();
}

class _NowPlayingBackdropState extends State<_NowPlayingBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  bool _tickerActive = true;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
  }

  void _syncGlow() {
    final shouldRun =
        widget.style == PlayerBackgroundStyle.glowAnimated && _tickerActive;
    if (shouldRun && !_glowCtrl.isAnimating) {
      _glowCtrl.repeat(reverse: true);
    } else if (!shouldRun && _glowCtrl.isAnimating) {
      _glowCtrl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerActive = TickerMode.valuesOf(context).enabled;
    _syncGlow();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGlow();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgTop = widget.isDark
        ? Color.lerp(const Color(0xFF0A0D12), widget.baseAccent, 0.34)!
        : Color.lerp(const Color(0xFFF2F4F8), widget.baseAccent, 0.24)!;
    final bgBottom = widget.isDark
        ? const Color(0xFF000000)
        : Color.lerp(const Color(0xFFF6F7FB), widget.baseAccent, 0.08)!;

    if (widget.style == PlayerBackgroundStyle.blur) {
      final thumb = widget.track.bestThumbUrl(size: 400);
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgBottom],
              ),
            ),
          ),
          if (thumb != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 24,
                  sigmaY: 24,
                  tileMode: TileMode.clamp,
                ),
                child: Opacity(
                  opacity: widget.isDark ? 0.52 : 0.34,
                  child: ArtworkImage(
                    url: thumb,
                    size: MediaQuery.of(context).size.height,
                    radius: 0,
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.isDark
                    ? [
                        Colors.black.withAlpha(88),
                        const Color(0xD905070B),
                      ]
                    : [
                        Colors.white.withAlpha(88),
                        const Color(0xE8F3F5F9),
                      ],
              ),
            ),
          ),
          widget.child,
        ],
      );
    }

    if (widget.style == PlayerBackgroundStyle.liveMesh) {
      final hsl = HSLColor.fromColor(widget.baseAccent);
      final altAccent = hsl
          .withHue((hsl.hue + 145) % 360)
          .withSaturation(0.60)
          .toColor();
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgBottom],
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            width: 300,
            height: 300,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.baseAccent.withAlpha(widget.isDark ? 120 : 88),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            width: 320,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      altAccent.withAlpha(widget.isDark ? 95 : 70),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      );
    }

    if (widget.style == PlayerBackgroundStyle.glowAnimated) {
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgBottom],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) {
              final pulse = 0.72 + _glowCtrl.value * 0.45;
              return IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.35),
                      radius: 0.9 * pulse,
                      colors: [
                        widget.baseAccent.withAlpha(
                          ((widget.isDark ? 125 : 85) * pulse).round().clamp(0, 255),
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          widget.child,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgBottom],
        ),
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// ISOLATED TICKING SUB-WIDGETS (prevents 5Hz full-screen rebuild lag)
// ---------------------------------------------------------------------------

class _PlayerSeekBarDeck extends ConsumerStatefulWidget {
  final Color ink;
  final Color sub;

  const _PlayerSeekBarDeck({required this.ink, required this.sub});

  @override
  ConsumerState<_PlayerSeekBarDeck> createState() => _PlayerSeekBarDeckState();
}

class _PlayerSeekBarDeckState extends ConsumerState<_PlayerSeekBarDeck>
    with SingleTickerProviderStateMixin {
  double? _draggingValue;
  late final AnimationController _waveCtrl;
  bool _tickerActive = true;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerActive = TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posDur = ref.watch(
      playerProvider.select(
        (s) => (s.position, s.duration, s.isPlaying, s.loopStart, s.loopEnd, s.playbackSpeed),
      ),
    );
    final sliderStyle =
        ref.watch(settingsProvider.select((s) => s.sliderStyle));

    final totalMs = posDur.$2.inMilliseconds.toDouble();
    final safeTotal = totalMs > 0 ? totalMs : 1.0;
    final currentMs = (_draggingValue ?? posDur.$1.inMilliseconds.toDouble())
        .clamp(0.0, safeTotal);
    final fraction = (currentMs / safeTotal).clamp(0.0, 1.0);
    final remainingDur = Duration(
      milliseconds:
          ((totalMs - currentMs).clamp(0.0, double.infinity)).round(),
    );

    final isPlaying = posDur.$3;
    final loopA = posDur.$4;
    final loopB = posDur.$5;
    final speed = posDur.$6;

    final shouldWave =
        sliderStyle == PlayerSliderStyle.squiggly && isPlaying && _tickerActive;
    if (shouldWave && !_waveCtrl.isAnimating) {
      _waveCtrl.repeat();
    } else if (!shouldWave && _waveCtrl.isAnimating) {
      _waveCtrl.stop();
    }

    Widget seekWidget;
    if (sliderStyle == PlayerSliderStyle.wavy ||
        sliderStyle == PlayerSliderStyle.squiggly) {
      seekWidget = SizedBox(
        height: 30,
        child: LayoutBuilder(
          builder: (ctx, c) {
            final maxW = c.maxWidth > 0 ? c.maxWidth : 1.0;
            void handleDx(double dx) {
              final f = (dx / maxW).clamp(0.0, 1.0);
              setState(() => _draggingValue = f * safeTotal);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => handleDx(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => handleDx(d.localPosition.dx),
              onHorizontalDragEnd: (_) async {
                final v = _draggingValue;
                setState(() => _draggingValue = null);
                if (v != null) {
                  await ref.read(playerProvider.notifier).seek(
                        Duration(milliseconds: v.round()),
                      );
                }
              },
              onTapDown: (d) async {
                final f = (d.localPosition.dx / maxW).clamp(0.0, 1.0);
                await ref.read(playerProvider.notifier).seek(
                      Duration(milliseconds: (f * safeTotal).round()),
                    );
              },
              child: AnimatedBuilder(
                animation: _waveCtrl,
                builder: (_, __) => CustomPaint(
                  size: Size(maxW, 30),
                  painter: _WaveSeekPainter(
                    progress: fraction,
                    color: widget.ink,
                    trackBg: widget.ink.withAlpha(42),
                    squiggly: sliderStyle == PlayerSliderStyle.squiggly,
                    phase: _waveCtrl.value * math.pi * 2,
                    loopAFraction: loopA != null && totalMs > 0
                        ? (loopA.inMilliseconds / totalMs).clamp(0.0, 1.0)
                        : null,
                    loopBFraction: loopB != null && totalMs > 0
                        ? (loopB.inMilliseconds / totalMs).clamp(0.0, 1.0)
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      seekWidget = SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: sliderStyle == PlayerSliderStyle.slim ? 2.5 : 3.8,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: widget.ink,
          inactiveTrackColor: widget.ink.withAlpha(38),
          thumbColor: widget.ink,
        ),
        child: Slider(
          min: 0,
          max: safeTotal,
          value: currentMs,
          onChanged: (v) => setState(() => _draggingValue = v),
          onChangeEnd: (v) async {
            setState(() => _draggingValue = null);
            await ref.read(playerProvider.notifier).seek(
                  Duration(milliseconds: v.round()),
                );
          },
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        seekWidget,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                _formatPlayerDuration(
                  Duration(milliseconds: currentMs.round()),
                ),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: widget.sub,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (loopA != null || loopB != null)
                GestureDetector(
                  onTap: () => ref.read(playerProvider.notifier).clearABLoop(),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.ink.withAlpha(24),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      loopB != null ? 'Loop A–B ×' : 'Loop A… ×',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: widget.ink,
                      ),
                    ),
                  ),
                ),
              if ((speed - 1.0).abs() > 0.02)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.ink.withAlpha(20),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${speed.toStringAsFixed(2)}x',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: widget.ink,
                    ),
                  ),
                ),
              Text(
                '-${_formatPlayerDuration(remainingDur)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: widget.sub,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaveSeekPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackBg;
  final bool squiggly;
  final double phase;
  final double? loopAFraction;
  final double? loopBFraction;

  const _WaveSeekPainter({
    required this.progress,
    required this.color,
    required this.trackBg,
    required this.squiggly,
    required this.phase,
    this.loopAFraction,
    this.loopBFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const pad = 6.0;
    final usableW = (size.width - pad * 2).clamp(1.0, size.width);
    final activeX = pad + usableW * progress.clamp(0.0, 1.0);

    final bgPaint = Paint()
      ..color = trackBg
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(activeX, cy), Offset(size.width - pad, cy), bgPaint);

    if (loopAFraction != null) {
      final ax = pad + usableW * loopAFraction!;
      canvas.drawCircle(Offset(ax, cy), 3.2, Paint()..color = AppColors.horizonBlue);
    }
    if (loopBFraction != null) {
      final bx = pad + usableW * loopBFraction!;
      canvas.drawCircle(Offset(bx, cy), 3.2, Paint()..color = AppColors.horizonBlue);
    }

    final activePath = Path();
    const step = 3.0;
    final amp = squiggly ? 3.2 : 2.1;
    final freq = squiggly ? 0.22 : 0.11;
    for (double x = pad; x <= activeX; x += step) {
      final t = (x - pad) * freq + phase;
      final y = cy + math.sin(t) * amp;
      if (x == pad) {
        activePath.moveTo(x, y);
      } else {
        activePath.lineTo(x, y);
      }
    }
    if (activeX > pad) {
      final endY = cy + math.sin((activeX - pad) * freq + phase) * amp;
      activePath.lineTo(activeX, endY);
      canvas.drawPath(
        activePath,
        Paint()
          ..color = color
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    canvas.drawCircle(
      Offset(activeX, cy),
      5.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveSeekPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.squiggly != squiggly ||
      oldDelegate.color != color ||
      oldDelegate.loopAFraction != loopAFraction ||
      oldDelegate.loopBFraction != loopBFraction;
}

class _PlayerTransportButtons extends ConsumerWidget {
  final Color ink;
  final Color sub;

  const _PlayerTransportButtons({required this.ink, required this.sub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controls = ref.watch(
      playerProvider.select(
        (s) => (s.isPlaying, s.isBuffering, s.shuffle, s.repeat),
      ),
    );
    final isDark = AppColors.isDark(context);
    final iosAccent = isDark ? const Color(0xFF0A84FF) : AppColors.iosBlue;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: controls.$3
                ? iosAccent.withAlpha(isDark ? 44 : 26)
                : Colors.transparent,
          ),
          icon: Icon(
            CupertinoIcons.shuffle,
            size: 21,
            color: controls.$3 ? iosAccent : sub.withAlpha(175),
          ),
          onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
        ),
        IconButton(
          icon: Icon(CupertinoIcons.backward_fill, size: 30, color: ink),
          onPressed: () => ref.read(playerProvider.notifier).skipPrevious(),
        ),
        LiquidGlassTap(
          onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: controls.$2
                ? SizedBox(
                    width: 34,
                    height: 34,
                    child: CupertinoActivityIndicator(radius: 14, color: ink),
                  )
                : Icon(
                    controls.$1
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: ink,
                    size: 40,
                  ),
          ),
        ),
        IconButton(
          icon: Icon(CupertinoIcons.forward_fill, size: 30, color: ink),
          onPressed: () => ref.read(playerProvider.notifier).skipNext(),
        ),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: controls.$4 != RepeatSetting.off
                ? iosAccent.withAlpha(isDark ? 44 : 26)
                : Colors.transparent,
          ),
          icon: Icon(
            controls.$4 == RepeatSetting.one
                ? CupertinoIcons.repeat_1
                : CupertinoIcons.repeat,
            size: 21,
            color:
                controls.$4 == RepeatSetting.off ? sub.withAlpha(175) : iosAccent,
          ),
          onPressed: () => ref.read(playerProvider.notifier).cycleRepeat(),
        ),
      ],
    );
  }
}

class _PlayerVolumeDeck extends ConsumerWidget {
  final Color ink;
  final Color sub;
  final VoidCallback onOpenAudioOutput;

  const _PlayerVolumeDeck({
    required this.ink,
    required this.sub,
    required this.onOpenAudioOutput,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider.select((s) => s.volume));
    return Row(
      children: [
        Icon(CupertinoIcons.volume_down, size: 18, color: sub),
        const SizedBox(width: 8),
        Expanded(
          child: LiquidGlassRangeSlider(
            min: 0.0,
            max: 1.0,
            compact: true,
            activeColor: ink,
            inactiveColor: ink.withAlpha(38),
            value: volume,
            onChanged: (v) =>
                ref.read(playerProvider.notifier).setVolume(v),
          ),
        ),
        const SizedBox(width: 8),
        Icon(CupertinoIcons.volume_up, size: 18, color: sub),
        const SizedBox(width: 8),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(CupertinoIcons.bluetooth, size: 19, color: ink),
          tooltip: 'Output audio',
          onPressed: onOpenAudioOutput,
        ),
      ],
    );
  }
}

class _PlayerLyricSnippetPreview extends ConsumerWidget {
  final Color ink;
  final Color sub;
  final VoidCallback onTap;

  const _PlayerLyricSnippetPreview({
    required this.ink,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricState = ref.watch(
      playerProvider.select((s) => (s.lyrics, s.loadingLyrics, s.position)),
    );
    final lyricsOffsetMs =
        ref.watch(settingsProvider.select((s) => s.lyricsOffsetMs));
    final lyrics = lyricState.$1;
    final loadingLyrics = lyricState.$2;
    final position = lyricState.$3;

    final activeIdx = _findActiveLyricIndex(lyrics, position, lyricsOffsetMs);
    final activeLine =
        (activeIdx >= 0 && lyrics != null && activeIdx < lyrics.lines.length)
            ? lyrics.lines[activeIdx].text
            : null;
    final activeProgress =
        _lyricLineProgress(lyrics, activeIdx, position, lyricsOffsetMs);

    return GestureDetector(
      onTap: onTap,
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
                loadingLyrics ? 'Memuat lirik...' : 'Ketuk untuk lihat lirik',
                style: TextStyle(
                  fontSize: 13.5,
                  color: sub.withAlpha(180),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LYRICS PANEL (Supports normal & fullscreen mode matching screenshot 16-23-10)
// ---------------------------------------------------------------------------

class _LyricsPanelView extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final MusicItem track;
  final bool fullscreen;
  final bool isDark;
  final Color ink;
  final Color sub;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onOpenOptions;
  final VoidCallback onOpenAudioOutput;
  final ValueChanged<String>? onShareQuote;

  const _LyricsPanelView({
    required this.scrollController,
    required this.track,
    required this.fullscreen,
    required this.isDark,
    required this.ink,
    required this.sub,
    required this.onToggleFullscreen,
    required this.onOpenOptions,
    required this.onOpenAudioOutput,
    this.onShareQuote,
  });

  @override
  ConsumerState<_LyricsPanelView> createState() => _LyricsPanelViewState();
}

class _LyricsPanelViewState extends ConsumerState<_LyricsPanelView> {
  bool _userScrollingLyrics = false;
  int _lastActiveLyricIndex = -1;

  void _syncLyricsScroll(int activeIdx) {
    if (_userScrollingLyrics || activeIdx < 0) return;
    if (activeIdx == _lastActiveLyricIndex) return;
    _lastActiveLyricIndex = activeIdx;
    if (!widget.scrollController.hasClients) return;
    final offsetBias = widget.fullscreen ? 140.0 : 105.0;
    final target = (activeIdx * 68.0 - offsetBias).clamp(
      0.0,
      widget.scrollController.position.maxScrollExtent,
    );
    widget.scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricState = ref.watch(
      playerProvider.select((s) => (s.lyrics, s.loadingLyrics, s.position)),
    );
    final lyricOpts = ref.watch(
      settingsProvider.select(
        (s) => (
          s.lyricsOffsetMs,
          s.romanizeLyrics,
          s.aiTranslateLyrics,
          s.chordsEnabled,
          s.chordMode,
          s.chordTranspose,
          s.chordCapo,
        ),
      ),
    );
    final lyricsOffsetMs = lyricOpts.$1;
    final showRoman = lyricOpts.$2;
    final showTranslate = lyricOpts.$3;
    final chordsEnabled = lyricOpts.$4;
    final chordMode = ChordMode.fromString(lyricOpts.$5);
    final chordTranspose = lyricOpts.$6;
    final chordCapo = lyricOpts.$7;
    final lyrics = lyricState.$1;
    final loadingLyrics = lyricState.$2;
    final position = lyricState.$3;

    final chordAnalysis = (chordsEnabled && lyrics != null && lyrics.lines.isNotEmpty)
        ? ChordEngine.analyzeTrack(
            widget.track,
            lyrics.lines,
            mode: chordMode,
            transpose: chordTranspose,
            capo: chordCapo,
          )
        : null;

    final activeLyricIdx =
        _findActiveLyricIndex(lyrics, position, lyricsOffsetMs);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncLyricsScroll(activeLyricIdx));

    return Column(
      children: [
        if (chordAnalysis != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                showChordSettingsSheet(
                  context,
                  ref,
                  progression: chordAnalysis.progression,
                  baseKey: chordAnalysis.baseKey,
                  accentColor: const Color(0xFF4FD1C5),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14181F).withAlpha(widget.isDark ? 195 : 32),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: (widget.isDark ? Colors.white : Colors.black).withAlpha(46),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.guitars,
                      size: 15,
                      color: Color(0xFF5CE1E6),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        chordAnalysis.summaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: widget.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 13,
                      color: widget.sub,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              if (loadingLyrics)
                Center(child: CircularProgressIndicator(color: widget.ink))
              else if (lyrics == null || lyrics.lines.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lyrics_outlined, size: 46, color: widget.sub),
                      const SizedBox(height: 10),
                      Text(
                        'Lirik tidak tersedia untuk lagu ini',
                        style: TextStyle(color: widget.sub),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(playerProvider.notifier).refreshLyrics(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Muat ulang lirik'),
                      ),
                    ],
                  ),
                )
              else
                RepaintBoundary(
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.10, 0.86, 1.0],
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
                        controller: widget.scrollController,
                        padding: EdgeInsets.fromLTRB(
                          30,
                          widget.fullscreen ? 36 : 24,
                          30,
                          48,
                        ),
                        itemCount: lyrics.lines.length,
                        itemBuilder: (_, idx) {
                          final line = lyrics.lines[idx];
                          final isActive =
                              !lyrics.synced || idx == activeLyricIdx;
                          final progress = _lyricLineProgress(
                            lyrics,
                            idx,
                            position,
                            lyricsOffsetMs,
                          );
                          final fontSize = widget.fullscreen ? 27.0 : 25.5;
                          final placements = (chordAnalysis != null &&
                                  idx < chordAnalysis.lineChords.length)
                              ? chordAnalysis.lineChords[idx]
                              : const <ChordPlacement>[];

                          final Widget mainLineWidget;
                          if (placements.isNotEmpty) {
                            final words = line.text
                                .trim()
                                .split(RegExp(r'\s+'))
                                .where((w) => w.isNotEmpty)
                                .toList();
                            final chordMap = <int, ChordPlacement>{
                              for (final p in placements) p.wordIndex: p,
                            };
                            mainLineWidget = Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              children: [
                                for (var wi = 0; wi < words.length; wi++)
                                  Builder(
                                    builder: (_) {
                                      final cp = chordMap[wi];
                                      final wordFraction =
                                          (wi + 1) / math.max(words.length, 1);
                                      final wordDone = !lyrics.synced ||
                                          (isActive && progress >= wordFraction);
                                      final wordCol = isActive
                                          ? (wordDone
                                              ? widget.ink
                                              : widget.ink.withAlpha(118))
                                          : widget.ink.withAlpha(88);
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (cp != null)
                                            GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                showGuitarChordDiagramDialog(
                                                  context,
                                                  chordName: cp.displayChord,
                                                  accentColor: const Color(0xFF4FD1C5),
                                                );
                                              },
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 3,
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: isActive ? 7 : 2,
                                                  vertical: isActive ? 1.5 : 1,
                                                ),
                                                decoration: isActive
                                                    ? BoxDecoration(
                                                        color: const Color(0xFF4FD1C5)
                                                            .withAlpha(38),
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: const Color(0xFF5CE1E6)
                                                              .withAlpha(110),
                                                          width: 0.75,
                                                        ),
                                                      )
                                                    : null,
                                                child: Text(
                                                  cp.displayChord,
                                                  style: GoogleFonts
                                                      .jetBrainsMono(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: widget.isDark
                                                        ? const Color(0xFF5CE1E6)
                                                            .withAlpha(isActive ? 255 : 135)
                                                        : AppColors.iosTeal
                                                            .withAlpha(isActive ? 255 : 145),
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            const SizedBox(height: 19),
                                          Text(
                                            words[wi],
                                            style: TextStyle(
                                              fontSize: fontSize - 2,
                                              height: 1.2,
                                              letterSpacing: -0.4,
                                              fontWeight: isActive
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: wordCol,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            );
                          } else if (isActive && lyrics.synced) {
                            mainLineWidget = _ContrastSweepText(
                              text: line.text,
                              progress: progress,
                              activeColor: widget.ink,
                              inactiveColor: widget.ink.withAlpha(115),
                              fontSize: fontSize + 0.5,
                              fontWeight: FontWeight.w800,
                            );
                          } else {
                            mainLineWidget = Text(
                              line.text,
                              style: TextStyle(
                                fontSize: fontSize,
                                height: 1.24,
                                letterSpacing: -0.5,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isActive
                                    ? widget.ink
                                    : widget.ink.withAlpha(88),
                              ),
                            );
                          }

                          final hasRoman = showRoman &&
                              line.romanized != null &&
                              line.romanized!.isNotEmpty;
                          final hasTrans = showTranslate &&
                              line.translated != null &&
                              line.translated!.isNotEmpty;

                          return GestureDetector(
                            onTap: line.timeMs != null
                                ? () {
                                    setState(() => _userScrollingLyrics = false);
                                    ref.read(playerProvider.notifier).seek(
                                          Duration(milliseconds: line.timeMs!),
                                        );
                                  }
                                : null,
                            onLongPress: widget.onShareQuote != null
                                ? () {
                                    HapticFeedback.mediumImpact();
                                    widget.onShareQuote!(line.text);
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  mainLineWidget,
                                  if (hasRoman) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      line.romanized!,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontStyle: FontStyle.italic,
                                        color: isActive
                                            ? widget.ink.withAlpha(200)
                                            : widget.ink.withAlpha(76),
                                      ),
                                    ),
                                  ],
                                  if (hasTrans) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      line.translated!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isActive
                                            ? widget.sub
                                            : widget.sub.withAlpha(82),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
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
        // Compact Track Header + Seek/Volume Deck matching 16-23-07 & 16-23-10
        Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            4,
            22,
            widget.fullscreen ? 16 : 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  MiniSpinningVinyl(
                    artworkUrl: widget.track.bestThumbUrl(size: 160),
                    size: 48,
                    isPlaying: ref.watch(playerProvider.select((s) => s.isPlaying)),
                    accentColor: AppColors.horizonBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: widget.ink,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.track.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, color: widget.sub),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.guitars,
                      color: chordsEnabled ? AppColors.iosBlue : widget.ink,
                      size: 21,
                    ),
                    tooltip: chordsEnabled ? 'Sembunyikan chord' : 'Tampilkan chord',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(settingsProvider.notifier)
                          .setChordsEnabled(!chordsEnabled);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      widget.fullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: widget.ink,
                      size: 24,
                    ),
                    tooltip: widget.fullscreen
                        ? 'Keluar layar penuh'
                        : 'Lirik layar penuh',
                    onPressed: widget.onToggleFullscreen,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: widget.ink,
                      size: 22,
                    ),
                    tooltip: 'Opsi lirik',
                    onPressed: widget.onOpenOptions,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _PlayerSeekBarDeck(ink: widget.ink, sub: widget.sub),
              if (!widget.fullscreen) ...[
                const SizedBox(height: 6),
                _PlayerTransportButtons(ink: widget.ink, sub: widget.sub),
              ],
              const SizedBox(height: 4),
              _PlayerVolumeDeck(
                ink: widget.ink,
                sub: widget.sub,
                onOpenAudioOutput: widget.onOpenAudioOutput,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// QUEUE PANEL (Fixed "Antrean" header never truncating like screenshot 16-23-14)
// ---------------------------------------------------------------------------

class _QueuePanelView extends ConsumerWidget {
  final bool isDark;
  final Color ink;
  final Color sub;
  final VoidCallback onCollapse;

  const _QueuePanelView({
    required this.isDark,
    required this.ink,
    required this.sub,
    required this.onCollapse,
  });

  String _formatTotalQueueDuration(List<MusicItem> queue) {
    var total = 0;
    for (final q in queue) {
      total += q.durationSeconds ?? 210;
    }
    return _formatPlayerDuration(Duration(seconds: total));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      playerProvider.select(
        (s) => (
          s.queue,
          s.currentIndex,
          s.queueLocked,
          s.playingContext,
          s.isPlaying,
          s.shuffle,
          s.repeat,
          s.currentTrack,
        ),
      ),
    );
    final queue = state.$1;
    final currentIndex = state.$2;
    final queueLocked = state.$3;
    final playingContext = state.$4;
    final isPlaying = state.$5;
    final shuffle = state.$6;
    final repeat = state.$7;
    final currentTrack = state.$8;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Antrean',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints.tightFor(width: 34, height: 34),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.history_rounded, color: ink, size: 21),
                    tooltip: 'Riwayat',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HistoryScreen(),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints.tightFor(width: 34, height: 34),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.playlist_add_rounded,
                      color: ink,
                      size: 21,
                    ),
                    tooltip: 'Simpan ke playlist',
                    onPressed: () {
                      if (currentTrack != null) {
                        showTrackPlaylistPicker(context, ref, currentTrack);
                      }
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints.tightFor(width: 34, height: 34),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      queueLocked
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      color: queueLocked ? AppColors.horizonBlue : ink,
                      size: 20,
                    ),
                    tooltip: queueLocked ? 'Antrean terkunci' : 'Kunci antrean',
                    onPressed: () =>
                        ref.read(playerProvider.notifier).toggleQueueLock(),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Aksi antrean',
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_horiz_rounded, color: ink, size: 21),
                    onSelected: (action) async {
                      if (action == 'save_pl' && queue.isNotEmpty) {
                        final title = currentTrack?.title.isNotEmpty == true
                            ? '${currentTrack!.title} Mix'
                            : 'Antrean ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
                        final created = await ref
                            .read(libraryProvider.notifier)
                            .createPlaylist(title, initialTracks: queue);
                        if (created != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Antrean disimpan ke "${created.name}"',
                              ),
                            ),
                          );
                        }
                      } else if (action == 'clear_upcoming') {
                        ref
                            .read(playerProvider.notifier)
                            .clearUpcomingQueue();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem<String>(
                        value: 'save_pl',
                        child: Text('Simpan antrean jadi playlist'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'clear_upcoming',
                        child: Text('Hapus lagu berikutnya'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${queue.length} lagu • ${_formatTotalQueueDuration(queue)}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: sub,
                      ),
                    ),
                  ),
                ],
              ),
              if (playingContext.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  playingContext,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: sub),
                ),
              ],
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
              if (!queueLocked) {
                ref.read(playerProvider.notifier).reorderQueue(oldIndex, newIndex);
              }
            },
            itemBuilder: (_, idx) {
              final item = queue[idx];
              final isCurrent = idx == currentIndex;
              return Container(
                key: ValueKey('q_${item.id}_$idx'),
                color: isCurrent
                    ? (isDark
                        ? Colors.white.withAlpha(18)
                        : Colors.black.withAlpha(12))
                    : Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
                  onTap: () => ref.read(playerProvider.notifier).playTrack(
                        item,
                        queue: queue,
                        contextName: playingContext,
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
                                  isPlaying: isPlaying,
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
                      if (isCurrent)
                        MiniSpinningVinyl(
                          artworkUrl: item.bestThumbUrl(size: 140),
                          size: 46,
                          isPlaying: isPlaying,
                          accentColor: AppColors.horizonBlue,
                        )
                      else
                        ArtworkImage(
                          url: item.bestThumbUrl(size: 140),
                          size: 46,
                          radius: 8,
                        ),
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
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: sub,
                          ),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 19,
                          color: sub,
                        ),
                        onPressed: () =>
                            showTrackOptionsSheet(context, ref, item),
                      ),
                      if (!queueLocked)
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
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: shuffle ? ink : sub,
                ),
                onPressed: () =>
                    ref.read(playerProvider.notifier).toggleShuffle(),
              ),
              IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: ink,
                  size: 28,
                ),
                onPressed: onCollapse,
              ),
              IconButton(
                icon: Icon(
                  repeat == RepeatSetting.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: repeat == RepeatSetting.off ? sub : ink,
                ),
                onPressed: () =>
                    ref.read(playerProvider.notifier).cycleRepeat(),
              ),
            ],
          ),
        ),
      ],
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
    return LiquidGlassTap(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(28)
              : Colors.white.withAlpha(145),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(42)
                : Colors.white.withAlpha(200),
            width: 0.7,
          ),
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
    final split =
        (text.length * progress.clamp(0.0, 1.0)).round().clamp(0, text.length);
    final donePart = text.substring(0, split);
    final todoPart = text.substring(split);

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: -0.25,
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

class AmbientModeScreen extends ConsumerStatefulWidget {
  const AmbientModeScreen({super.key});

  @override
  ConsumerState<AmbientModeScreen> createState() => _AmbientModeScreenState();
}

class _AmbientModeScreenState extends ConsumerState<AmbientModeScreen> {
  bool _showVinyl = true;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(playerProvider.select((s) => s.currentTrack));
    final accent =
        ref.watch(playerProvider.select((s) => s.dynamicColor)) ??
            AppColors.horizonBlue;
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final lyrics = ref.watch(playerProvider.select((s) => s.lyrics));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final lyricsOffsetMs =
        ref.watch(settingsProvider.select((s) => s.lyricsOffsetMs));
    final activeIdx = _findActiveLyricIndex(lyrics, position, lyricsOffsetMs);
    final activeLine =
        (activeIdx >= 0 && lyrics != null && activeIdx < lyrics.lines.length)
            ? lyrics.lines[activeIdx].text
            : null;
    final size = MediaQuery.of(context).size;
    final discSize = math.min(size.width * 0.64, size.height * 0.34).clamp(150.0, 276.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 1.25,
              colors: [
                accent.withAlpha(118),
                const Color(0xFF0A0D12),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LiquidGlassTap(
                        onTap: () => setState(() => _showVinyl = !_showVinyl),
                        child: LiquidGlassCapsule(
                          blurSigma: 18,
                          tintColor: Colors.white.withAlpha(24),
                          chromaticAccent: accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showVinyl
                                    ? CupertinoIcons.photo_fill
                                    : CupertinoIcons.circle_grid_hex_fill,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showVinyl ? 'Sampul' : 'Piringan',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      LiquidGlassTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: LiquidGlassCapsule(
                          blurSigma: 18,
                          tintColor: Colors.white.withAlpha(24),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (track != null) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      child: _showVinyl
                          ? SpinningVinylDisc(
                              key: const ValueKey('ambient_vinyl'),
                              artworkUrl: track.bestThumbUrl(size: 800),
                              size: discSize,
                              isPlaying: isPlaying,
                              accentColor: accent,
                              showTonearm: true,
                              onTap: () => ref
                                  .read(playerProvider.notifier)
                                  .togglePlayPause(),
                            )
                          : ClipRRect(
                              key: const ValueKey('ambient_cover'),
                              borderRadius: BorderRadius.circular(24),
                              child: ArtworkImage(
                                url: track.bestThumbUrl(size: 800),
                                size: discSize,
                                radius: 24,
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    HarmonicSpectrumBars(
                      isPlaying: isPlaying,
                      color: accent,
                      barCount: 28,
                      height: 28,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      track.artistDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        color: Colors.white70,
                      ),
                    ),
                    if (activeLine != null && activeLine.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: Text(
                          activeLine,
                          key: ValueKey(activeLine),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color.lerp(Colors.white, accent, 0.35),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    LiquidGlassCapsule(
                      blurSigma: 20,
                      tintColor: Colors.white.withAlpha(22),
                      chromaticAccent: accent,
                      interactiveFlex: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.backward_fill,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () =>
                                ref.read(playerProvider.notifier).skipPrevious(),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Icon(
                              isPlaying
                                  ? CupertinoIcons.pause_circle_fill
                                  : CupertinoIcons.play_circle_fill,
                              color: Colors.white,
                              size: 54,
                            ),
                            onPressed: () => ref
                                .read(playerProvider.notifier)
                                .togglePlayPause(),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.forward_fill,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () =>
                                ref.read(playerProvider.notifier).skipNext(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Text(
                    'Ketuk area kosong untuk keluar dari Mode ambient',
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
