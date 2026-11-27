import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/device_permissions_service.dart';
import '../../state/dynamic_island_provider.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import 'animated_eq.dart';
import 'artwork_image.dart';
import 'ios_control_center.dart';
import 'lunarellys_logo.dart';
import 'marquee_text.dart';
import 'permissions_sheet.dart';
import 'subscreen_mini_player.dart';

String _formatCompactDuration(Duration d) {
  final total = d.inSeconds.clamp(0, 359999);
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Floating Apple iOS Dynamic Island & Live Activities overlay anchored
/// inside SafeArea at top-center of MainShell.
class DynamicIslandOverlay extends ConsumerStatefulWidget {
  final VoidCallback? onOpenEqualizer;

  const DynamicIslandOverlay({
    super.key,
    this.onOpenEqualizer,
  });

  @override
  ConsumerState<DynamicIslandOverlay> createState() =>
      _DynamicIslandOverlayState();
}

class _DynamicIslandOverlayState extends ConsumerState<DynamicIslandOverlay> {
  bool _expanded = false;

  void _toggleExpanded() {
    HapticFeedback.mediumImpact();
    setState(() => _expanded = !_expanded);
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandEnabled),
    );
    if (!enabled) return const SizedBox.shrink();

    final alwaysVisible = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandAlwaysVisible),
    );
    final positionMode = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandPosition),
    );
    final track = ref.watch(playerProvider.select((s) => s.currentTrack));
    final sleepRem = ref.watch(
      playerProvider.select((s) => s.sleepTimerRemaining),
    );
    final stopAfter = ref.watch(
      playerProvider.select((s) => s.stopAfterCurrentTrack),
    );
    final event = ref.watch(dynamicIslandEventProvider);

    final hasActivity =
        track != null || sleepRem != null || stopAfter || event != null;
    if (!alwaysVisible && !hasActivity) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final topInset = math.max(media.padding.top, media.viewPadding.top);
    final screenW = media.size.width;
    final isDark = AppColors.isDark(context);
    final bool notchCompact =
        positionMode == 'notch' && !_expanded && event == null;

    final double targetWidth;
    if (_expanded) {
      targetWidth = math.min(screenW - 24, 388);
    } else if (event != null) {
      targetWidth = math.min(screenW - 44, 308);
    } else if (notchCompact) {
      targetWidth = math.min(screenW * 0.30, 106);
    } else if (track != null) {
      targetWidth = math.min(screenW - 84, 244);
    } else {
      targetWidth = math.min(screenW - 110, 168);
    }

    final double topOffset = notchCompact
        ? ((topInset - 28) * 0.5).clamp(4.0, topInset)
        : topInset + 6.0;

    final dynamicColor = ref.watch(playerProvider.select((s) => s.dynamicColor));
    final dynamicAlbumColors = ref.watch(
      settingsProvider.select((s) => s.dynamicAlbumColors),
    );
    final glassOpacity = ref.watch(
      settingsProvider.select((s) => s.liquidGlassOpacity),
    );
    final accent = (dynamicAlbumColors ? dynamicColor : null) ??
        const Color(0xFF60A5FA);
    final glowColor = event?.accent ?? accent;
    final double cornerRadius = _expanded ? 34.0 : 999.0;
    final int glassBaseAlpha =
        lerpDouble(182, 232, glassOpacity)!.round().clamp(170, 238);

    return Positioned.fill(
      child: Stack(
        children: [
          if (_expanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _collapse,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  color: Colors.black.withAlpha(isDark ? 98 : 48),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: topOffset,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleExpanded,
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  _collapse();
                  showIosControlCenter(
                    context,
                    ref,
                    onOpenEqualizer: widget.onOpenEqualizer,
                  );
                },
                onVerticalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v > 180 && !_expanded) {
                    _toggleExpanded();
                  } else if (v < -180 && _expanded) {
                    _collapse();
                  }
                },
                child: RepaintBoundary(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 340),
                    curve: Curves.easeOutBack,
                    width: targetWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cornerRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 175 : 88),
                          blurRadius: _expanded ? 32 : 16,
                          spreadRadius: _expanded ? 1 : -2,
                          offset: Offset(0, _expanded ? 14 : 6),
                        ),
                        BoxShadow(
                          color: glowColor.withAlpha(_expanded ? 62 : 34),
                          blurRadius: _expanded ? 26 : 14,
                          spreadRadius: -3,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(cornerRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 26,
                          sigmaY: 26,
                          tileMode: TileMode.clamp,
                        ),
                        child: CustomPaint(
                          foregroundPainter: _IslandLiquidGlassRimPainter(
                            radius: cornerRadius,
                            accent: glowColor,
                            expanded: _expanded,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF141B27).withAlpha(glassBaseAlpha),
                                  const Color(0xFF0A0F18).withAlpha(
                                    (glassBaseAlpha - 12).clamp(160, 232),
                                  ),
                                  const Color(0xFF070A10).withAlpha(glassBaseAlpha),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: -18,
                                  top: -16,
                                  width: 110,
                                  height: 76,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          center: const Alignment(-0.2, -0.1),
                                          radius: 0.9,
                                          colors: [
                                            glowColor.withAlpha(_expanded ? 58 : 44),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: _expanded
                                      ? _ExpandedIslandContent(
                                          accent: glowColor,
                                          onCollapse: _collapse,
                                          onOpenNowPlaying: () {
                                            _collapse();
                                            openNowPlayingSheet(context);
                                          },
                                          onOpenControlCenter: () {
                                            _collapse();
                                            showIosControlCenter(
                                              context,
                                              ref,
                                              onOpenEqualizer: widget.onOpenEqualizer,
                                            );
                                          },
                                          onOpenPermissions: () {
                                            _collapse();
                                            showPermissionsAndBackgroundSheet(context, ref);
                                          },
                                          onOpenLockScreenPreview: () {
                                            _collapse();
                                            ref
                                                .read(devicePermissionsProvider.notifier)
                                                .openLockScreenPreview();
                                          },
                                        )
                                      : (event != null
                                          ? _TransientEventPill(event: event)
                                          : _CompactIslandPill(
                                              accent: accent,
                                              microMode: notchCompact,
                                            )),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactIslandPill extends ConsumerWidget {
  final Color accent;
  final bool microMode;
  const _CompactIslandPill({required this.accent, this.microMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playerProvider.select((s) => s.currentTrack));
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final sleepRem = ref.watch(
      playerProvider.select((s) => s.sleepTimerRemaining),
    );
    final loopActive = ref.watch(
      playerProvider.select((s) => s.loopStart != null && s.loopEnd != null),
    );
    final permsReady = ref.watch(
      devicePermissionsProvider.select((s) => s.backgroundReady),
    );

    if (microMode) {
      return SizedBox(
        height: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (track != null)
                ArtworkImage(
                  url: track.bestThumbUrl(size: 100),
                  size: 18,
                  radius: 9,
                )
              else
                const LunarellysHorizonLogo(
                  size: 15,
                  color: Colors.white,
                ),
              AnimatedEqualizer(
                color: track != null ? accent : AppColors.iosGreen,
                isPlaying: track != null && isPlaying,
                size: 12,
              ),
            ],
          ),
        ),
      );
    }

    if (track == null) {
      return SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const LunarellysHorizonLogo(
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  AppConfig.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF101828),
                  border: Border.all(color: Colors.white.withAlpha(24), width: 0.7),
                ),
                child: Center(
                  child: Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: permsReady
                      ? AppColors.iosGreen
                      : AppColors.iosOrange,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(
          children: [
            ArtworkImage(
              url: track.bestThumbUrl(size: 120),
              size: 24,
              radius: 12,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MarqueeText(
                text: track.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (sleepRem != null)
              Container(
                margin: const EdgeInsets.only(right: 5),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withAlpha(46),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(sleepRem.inSeconds / 60).ceil()}m',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFCD34D),
                  ),
                ),
              )
            else if (loopActive)
              Container(
                margin: const EdgeInsets.only(right: 5),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withAlpha(56),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'A-B',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AnimatedEqualizer(
                color: accent,
                isPlaying: isPlaying,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransientEventPill extends StatelessWidget {
  final DynamicIslandEvent event;
  const _TransientEventPill({required this.event});

  @override
  Widget build(BuildContext context) {
    final badgeColor = event.accent ?? const Color(0xFF60A5FA);
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(55),
                shape: BoxShape.circle,
              ),
              child: Icon(event.icon, color: badgeColor, size: 14),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (event.subtitle != null && event.subtitle!.isNotEmpty)
                    Text(
                      event.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
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
}

class _ExpandedIslandContent extends ConsumerWidget {
  final Color accent;
  final VoidCallback onCollapse;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback onOpenControlCenter;
  final VoidCallback onOpenPermissions;
  final VoidCallback onOpenLockScreenPreview;

  const _ExpandedIslandContent({
    required this.accent,
    required this.onCollapse,
    required this.onOpenNowPlaying,
    required this.onOpenControlCenter,
    required this.onOpenPermissions,
    required this.onOpenLockScreenPreview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playerProvider.select((s) => s.currentTrack));
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final isBuffering = ref.watch(playerProvider.select((s) => s.isBuffering));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final soundStyle = ref.watch(playerProvider.select((s) => s.soundStyle));
    final sleepRem = ref.watch(
      playerProvider.select((s) => s.sleepTimerRemaining),
    );
    final perms = ref.watch(devicePermissionsProvider);
    final isLiked = track != null &&
        ref.watch(libraryProvider.select((s) => s.isLiked(track.id)));

    final pNotifier = ref.read(playerProvider.notifier);

    if (track == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LunarellysHorizonLogo(size: 32, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppConfig.appName} Live Island',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Siap memutar musik',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onCollapse,
                  icon: const Icon(
                    CupertinoIcons.chevron_up,
                    color: Colors.white70,
                    size: 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _islandPillButton(
                    icon: CupertinoIcons.slider_horizontal_3,
                    label: 'Pusat Kontrol',
                    accent: accent,
                    onTap: onOpenControlCenter,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _islandPillButton(
                    icon: perms.backgroundReady
                        ? CupertinoIcons.checkmark_seal_fill
                        : CupertinoIcons.bell_fill,
                    label: perms.backgroundReady ? 'Izin Siap' : 'Atur Izin',
                    accent: perms.backgroundReady
                        ? AppColors.iosGreen
                        : AppColors.iosOrange,
                    onTap: onOpenPermissions,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final totalMs = duration.inMilliseconds.clamp(1, 1 << 30);
    final progress = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Track Row
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenNowPlaying,
            child: Row(
              children: [
                ArtworkImage(
                  url: track.bestThumbUrl(size: 200),
                  size: 52,
                  radius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarqueeText(
                        text: track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artistDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedEqualizer(
                  color: accent,
                  isPlaying: isPlaying,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Live Seekable Progress Row
          Row(
            children: [
              Text(
                _formatCompactDuration(position),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: Colors.white60,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withAlpha(50),
                    thumbColor: Colors.white,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 11),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) {
                      if (duration.inMilliseconds > 0) {
                        pNotifier.seek(
                          Duration(
                            milliseconds: (duration.inMilliseconds * v).round(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              Text(
                _formatCompactDuration(duration),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: Colors.white60,
                ),
              ),
            ],
          ),

          // Transport & Quick Utility Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(libraryProvider.notifier).toggleLike(track);
                },
                icon: Icon(
                  isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: isLiked ? AppColors.iosPink : Colors.white70,
                  size: 19,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  pNotifier.skipPrevious();
                },
                icon: const Icon(
                  CupertinoIcons.backward_fill,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  pNotifier.togglePlayPause();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: isBuffering
                      ? const CupertinoActivityIndicator(
                          radius: 10,
                          color: Colors.black,
                        )
                      : Icon(
                          isPlaying
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.play_fill,
                          color: Colors.black,
                          size: 22,
                        ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  pNotifier.skipNext();
                },
                icon: const Icon(
                  CupertinoIcons.forward_fill,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Pusat Kontrol',
                onPressed: onOpenControlCenter,
                icon: const Icon(
                  CupertinoIcons.slider_horizontal_3,
                  color: Colors.white70,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Status chips + Permissions warning if missing
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _miniStatusChip(
                icon: CupertinoIcons.music_note,
                label: 'Pemutar Penuh',
                onTap: onOpenNowPlaying,
              ),
              _miniStatusChip(
                icon: CupertinoIcons.lock_fill,
                label: 'Lock Screen',
                onTap: onOpenLockScreenPreview,
              ),
              if (soundStyle != SoundStylePreset.normal)
                _miniStatusChip(
                  icon: CupertinoIcons.waveform,
                  label: soundStyle.label,
                  onTap: onOpenControlCenter,
                ),
              if (sleepRem != null)
                _miniStatusChip(
                  icon: CupertinoIcons.moon_fill,
                  label: '${(sleepRem.inSeconds / 60).ceil()}m',
                  color: AppColors.iosOrange,
                  onTap: onOpenControlCenter,
                ),
              if (!perms.backgroundReady || !perms.overlayGranted)
                _miniStatusChip(
                  icon: CupertinoIcons.layers_alt_fill,
                  label: !perms.overlayGranted
                      ? 'Aktifkan Island Luar App'
                      : 'Aktifkan Izin Latar',
                  color: AppColors.iosOrange,
                  onTap: onOpenPermissions,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _islandPillButton({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withAlpha(42),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withAlpha(90), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStatusChip({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final tint = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: tint.withAlpha(28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tint.withAlpha(62), width: 0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: tint),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslandLiquidGlassRimPainter extends CustomPainter {
  final double radius;
  final Color accent;
  final bool expanded;

  const _IslandLiquidGlassRimPainter({
    required this.radius,
    required this.accent,
    required this.expanded,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(radius.clamp(1.0, size.shortestSide * 0.5));

    // Outer darkened contrast edge
    final outerRRect = RRect.fromRectAndRadius(rect.deflate(0.4), r);
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..color = Colors.black.withAlpha(175);
    canvas.drawRRect(outerRRect, outerPaint);

    // Brighter directional Fresnel specular bevel inside rim
    final innerRRect = RRect.fromRectAndRadius(rect.deflate(1.15), r);
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(expanded ? 190 : 165),
          accent.withAlpha(expanded ? 120 : 92),
          Colors.white.withAlpha(32),
          Colors.white.withAlpha(expanded ? 110 : 84),
        ],
        stops: const [0.0, 0.34, 0.68, 1.0],
      ).createShader(rect);
    canvas.drawRRect(innerRRect, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _IslandLiquidGlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.accent != accent ||
      oldDelegate.expanded != expanded;
}
