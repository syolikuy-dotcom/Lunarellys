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
import 'liquid_glass.dart';
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
    final preset = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandPreset),
    );
    final customAccentVal = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandAccentValue),
    );
    final islandScale = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandScale),
    );
    final islandYOffset = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandYOffset),
    );
    final showLyrics = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandShowLyrics),
    );

    final track = ref.watch(playerProvider.select((s) => s.currentTrack));
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final sleepRem = ref.watch(
      playerProvider.select((s) => s.sleepTimerRemaining),
    );
    final stopAfter = ref.watch(
      playerProvider.select((s) => s.stopAfterCurrentTrack),
    );
    final lyricsObj = ref.watch(playerProvider.select((s) => s.lyrics));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final lyricsOffsetMs = ref.watch(
      settingsProvider.select((s) => s.lyricsOffsetMs),
    );
    final event = ref.watch(dynamicIslandEventProvider);

    final hasActivity =
        track != null || sleepRem != null || stopAfter || event != null;
    if (!alwaysVisible && !hasActivity) {
      return const SizedBox.shrink();
    }

    String? activeLyric;
    if (showLyrics &&
        lyricsObj != null &&
        lyricsObj.lines.isNotEmpty &&
        isPlaying) {
      final posMs = position.inMilliseconds + lyricsOffsetMs;
      var activeIdx = -1;
      for (var i = 0; i < lyricsObj.lines.length; i++) {
        final t = lyricsObj.lines[i].timeMs;
        if (t == null) continue;
        if (t <= posMs) {
          activeIdx = i;
        } else {
          break;
        }
      }
      if (activeIdx >= 0 && activeIdx < lyricsObj.lines.length) {
        activeLyric = lyricsObj.lines[activeIdx].text.trim();
      }
    }

    final media = MediaQuery.of(context);
    final topInset = math.max(media.padding.top, media.viewPadding.top);
    final screenW = media.size.width;
    final isDark = AppColors.isDark(context);
    final bool notchCompact =
        positionMode == 'notch' && !_expanded && event == null;

    final double baseWidth;
    if (_expanded) {
      baseWidth = math.min(screenW - 24, 388);
    } else if (event != null) {
      baseWidth = math.min(screenW - 44, 308);
    } else if (notchCompact) {
      baseWidth = math.min(screenW * 0.30, 106);
    } else if (track != null) {
      baseWidth = math.min(screenW - 76, 250);
    } else {
      baseWidth = math.min(screenW - 110, 168);
    }
    final double targetWidth = _expanded
        ? baseWidth
        : (baseWidth * islandScale).clamp(84.0, screenW - 36);

    final double topOffset = (notchCompact
            ? ((topInset - 28) * 0.5).clamp(4.0, topInset)
            : topInset + 6.0) +
        islandYOffset;

    final dynamicColor = ref.watch(playerProvider.select((s) => s.dynamicColor));
    final dynamicAlbumColors = ref.watch(
      settingsProvider.select((s) => s.dynamicAlbumColors),
    );
    final glassOpacity = ref.watch(
      settingsProvider.select((s) => s.liquidGlassOpacity),
    );
    final rawAccent = customAccentVal != 0
        ? Color(customAccentVal)
        : ((dynamicAlbumColors ? dynamicColor : null) ??
            const Color(0xFF60A5FA));
    final isLightPreset = preset == DynamicIslandPreset.minimalLight;
    final accent = AppColors.readableAccent(
      rawAccent,
      isLightPreset ? Brightness.light : Brightness.dark,
    );
    final glowColor = event?.accent ?? accent;
    final double cornerRadius = _expanded ? 34.0 : 999.0;

    final Color surfaceTint;
    switch (preset) {
      case DynamicIslandPreset.minimalLight:
        surfaceTint = const Color(0xFFF6F8FC);
        break;
      case DynamicIslandPreset.iosBlue:
        surfaceTint = const Color(0xFF0A2452);
        break;
      case DynamicIslandPreset.aurora:
        surfaceTint = const Color(0xFF0D2330);
        break;
      case DynamicIslandPreset.ultraGlass:
        surfaceTint = _expanded
            ? const Color(0xFF0C111A).withAlpha(240)
            : const Color(0xFF101826).withAlpha(176);
        break;
      case DynamicIslandPreset.dynamicCover:
        surfaceTint = Color.lerp(const Color(0xFF090D14), rawAccent, 0.24)!;
        break;
      case DynamicIslandPreset.classicBlack:
        surfaceTint = const Color(0xFF000000);
        break;
    }

    final bool useGlassBody =
        preset == DynamicIslandPreset.ultraGlass && !_expanded;

    final Widget islandInner = AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _expanded
          ? _ExpandedIslandContent(
              accent: glowColor,
              lightSurface: isLightPreset,
              activeLyric: activeLyric,
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
              ? _TransientEventPill(
                  event: event,
                  lightSurface: isLightPreset,
                )
              : _CompactIslandPill(
                  accent: accent,
                  lightSurface: isLightPreset,
                  microMode: notchCompact,
                  activeLyric: activeLyric,
                )),
    );

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
                  color: Colors.black.withAlpha(isDark ? 128 : 72),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: topOffset.clamp(2.0, 240.0),
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
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: targetWidth,
                    decoration: BoxDecoration(
                      color: useGlassBody ? null : surfaceTint,
                      borderRadius: BorderRadius.circular(cornerRadius),
                      border: useGlassBody
                          ? null
                          : Border.all(
                              color: isLightPreset
                                  ? Colors.black.withAlpha(22)
                                  : Colors.white.withAlpha(_expanded ? 28 : 34),
                              width: 0.85,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(
                            isLightPreset ? 45 : (isDark ? 200 : 108),
                          ),
                          blurRadius: _expanded ? 34 : 16,
                          spreadRadius: _expanded ? 2 : -2,
                          offset: Offset(0, _expanded ? 14 : 6),
                        ),
                        if (preset == DynamicIslandPreset.aurora ||
                            preset == DynamicIslandPreset.iosBlue)
                          BoxShadow(
                            color: (preset == DynamicIslandPreset.aurora
                                    ? const Color(0xFF5EEAD4)
                                    : glowColor)
                                .withAlpha(_expanded ? 54 : 32),
                            blurRadius: _expanded ? 24 : 14,
                            spreadRadius: -3,
                          ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: useGlassBody
                        ? LiquidGlassSurface(
                            borderRadius: BorderRadius.circular(cornerRadius),
                            blurSigma: 10,
                            useBackdropBlur: true,
                            tintColor: surfaceTint.withAlpha(
                              lerpDouble(140, 210, glassOpacity)!.round(),
                            ),
                            chromaticAccent: glowColor,
                            interactiveFlex: false,
                            child: islandInner,
                          )
                        : Material(
                            type: MaterialType.transparency,
                            child: islandInner,
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
  final bool lightSurface;
  final bool microMode;
  final String? activeLyric;
  const _CompactIslandPill({
    required this.accent,
    this.lightSurface = false,
    this.microMode = false,
    this.activeLyric,
  });

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
    final fgColor = lightSurface ? const Color(0xFF0F172A) : Colors.white;

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
                ArchysHorizonLogo(
                  size: 15,
                  color: fgColor,
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
              ArchysHorizonLogo(
                size: 18,
                color: fgColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  AppConfig.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: permsReady ? AppColors.iosGreen : AppColors.iosOrange,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayLabel =
        (activeLyric != null && activeLyric!.isNotEmpty)
            ? activeLyric!
            : track.title;

    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(
          children: [
            MiniSpinningVinyl(
              artworkUrl: track.bestThumbUrl(size: 120),
              size: 25,
              isPlaying: isPlaying,
              accentColor: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MarqueeText(
                text: displayLabel,
                style: TextStyle(
                  color: fgColor,
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
                    color: lightSurface
                        ? const Color(0xFFB45309)
                        : const Color(0xFFFCD34D),
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
                child: Text(
                  'A-B',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: fgColor,
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
  final bool lightSurface;
  const _TransientEventPill({
    required this.event,
    this.lightSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = event.accent ?? const Color(0xFF60A5FA);
    final fgColor = lightSurface ? const Color(0xFF0F172A) : Colors.white;
    final subColor = lightSurface ? const Color(0xFF475569) : Colors.white60;
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
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (event.subtitle != null && event.subtitle!.isNotEmpty)
                    Text(
                      event.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subColor,
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
  final bool lightSurface;
  final String? activeLyric;
  final VoidCallback onCollapse;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback onOpenControlCenter;
  final VoidCallback onOpenPermissions;
  final VoidCallback onOpenLockScreenPreview;

  const _ExpandedIslandContent({
    required this.accent,
    this.lightSurface = false,
    this.activeLyric,
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
    final fgColor = lightSurface ? const Color(0xFF0F172A) : Colors.white;
    final subColor = lightSurface ? const Color(0xFF475569) : Colors.white70;
    final mutedColor = lightSurface ? const Color(0xFF64748B) : Colors.white60;

    if (track == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ArchysHorizonLogo(size: 32, color: fgColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppConfig.appName} Live Island',
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Siap memutar musik',
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onCollapse,
                  icon: Icon(
                    CupertinoIcons.chevron_up,
                    color: subColor,
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
                    fgColor: fgColor,
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
                    fgColor: fgColor,
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
    final remDuration = duration > position ? (duration - position) : Duration.zero;
    final Color eqWarmColor = lightSurface
        ? const Color(0xFF4B5563)
        : const Color(0xFFC5B4A3);
    final Color sliderTrackColor = lightSurface
        ? const Color(0xFF111827)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Track Row (iPhone Dynamic Island 78140 style: square-rounded cover + crisp typography + taupe eq)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenNowPlaying,
            child: Row(
              children: [
                ArtworkImage(
                  url: track.bestThumbUrl(size: 220),
                  size: 50,
                  radius: 13,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarqueeText(
                        text: track.title,
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artistDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedEqualizer(
                  color: eqWarmColor,
                  isPlaying: isPlaying,
                  size: 20,
                ),
              ],
            ),
          ),
          if (activeLyric != null && activeLyric!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (lightSurface ? Colors.black : Colors.white).withAlpha(14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                activeLyric!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fgColor.withAlpha(232),
                  fontSize: 12.2,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Live Seekable Progress Row (crisp white track matching 78140)
          Row(
            children: [
              Text(
                _formatCompactDuration(position),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LiquidGlassRangeSlider(
                    value: progress,
                    compact: true,
                    activeColor: sliderTrackColor,
                    inactiveColor:
                        (lightSurface ? Colors.black : Colors.white).withAlpha(46),
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
                '-${_formatCompactDuration(remDuration)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Clean Transport Row matching 78140 (Favorite / Prev / Pause / Next / Lyrics-or-Controls)
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
                  color: isLiked ? AppColors.iosPink : subColor,
                  size: 19,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  pNotifier.skipPrevious();
                },
                icon: Icon(
                  CupertinoIcons.backward_end_fill,
                  color: fgColor,
                  size: 25,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  pNotifier.togglePlayPause();
                },
                icon: isBuffering
                    ? CupertinoActivityIndicator(
                        radius: 12,
                        color: fgColor,
                      )
                    : Icon(
                        isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        color: fgColor,
                        size: 30,
                      ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  pNotifier.skipNext();
                },
                icon: Icon(
                  CupertinoIcons.forward_end_fill,
                  color: fgColor,
                  size: 25,
                ),
              ),
              GestureDetector(
                onLongPress: onOpenLockScreenPreview,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Pemutar Penuh',
                  onPressed: onOpenNowPlaying,
                  icon: Icon(
                    CupertinoIcons.quote_bubble,
                    color: subColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (soundStyle != SoundStylePreset.normal ||
              sleepRem != null ||
              !perms.backgroundReady ||
              !perms.overlayGranted) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (soundStyle != SoundStylePreset.normal)
                  _miniStatusChip(
                    icon: CupertinoIcons.waveform,
                    label: soundStyle.label,
                    color: fgColor,
                    onTap: onOpenControlCenter,
                  ),
                if (sleepRem != null)
                  _miniStatusChip(
                    icon: CupertinoIcons.moon_fill,
                    label: '${(sleepRem.inSeconds / 60).ceil()}m',
                    color: fgColor,
                    onTap: onOpenControlCenter,
                  ),
                if (!perms.backgroundReady || !perms.overlayGranted)
                  _miniStatusChip(
                    icon: CupertinoIcons.layers_alt_fill,
                    label: !perms.overlayGranted
                        ? 'Izinkan Island Luar App'
                        : 'Izinkan Latar Belakang',
                    color: subColor,
                    onTap: onOpenPermissions,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _islandPillButton({
    required IconData icon,
    required String label,
    required Color accent,
    required Color fgColor,
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
            Icon(icon, color: fgColor, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fgColor,
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

