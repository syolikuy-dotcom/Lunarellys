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
import 'liquid_glass.dart';
import 'marquee_text.dart';
import 'permissions_sheet.dart';
import 'subscreen_mini_player.dart';

/// Opens the authentic iOS 27 Liquid Glass Control Center sheet.
void showIosControlCenter(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onOpenEqualizer,
}) {
  HapticFeedback.mediumImpact();
  ref.read(devicePermissionsProvider.notifier).refresh();
  showLiquidGlassSheet<void>(
    context: context,
    maxHeightFactor: 0.88,
    builder: (ctx) => _IosControlCenterSheet(
      parentContext: context,
      onOpenEqualizer: onOpenEqualizer,
    ),
  );
}

class _IosControlCenterSheet extends ConsumerWidget {
  final BuildContext parentContext;
  final VoidCallback? onOpenEqualizer;

  const _IosControlCenterSheet({
    required this.parentContext,
    this.onOpenEqualizer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final settings = ref.watch(settingsProvider);
    final perms = ref.watch(devicePermissionsProvider);
    final track = player.currentTrack;
    final isLiked = track != null &&
        ref.watch(libraryProvider.select((s) => s.isLiked(track.id)));

    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final accent = (settings.dynamicAlbumColors ? player.dynamicColor : null) ??
        AppColors.horizonBlueSoft;

    final pNotifier = ref.read(playerProvider.notifier);
    final sNotifier = ref.read(settingsProvider.notifier);
    final dNotifier = ref.read(dynamicIslandEventProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pusat Kontrol',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: ink,
                      ),
                    ),
                    Text(
                      '${AppConfig.appName} Audio',
                      style: TextStyle(fontSize: 12.5, color: sub),
                    ),
                  ],
                ),
              ),
              LiquidGlassTap(
                onTap: () {
                  Navigator.pop(context);
                  showPermissionsAndBackgroundSheet(parentContext, ref);
                },
                child: LiquidGlassCapsule(
                  blurSigma: 0,
                  chromaticAccent:
                      perms.backgroundReady ? AppColors.success : const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: perms.backgroundReady
                              ? AppColors.success
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        perms.backgroundReady ? 'Latar Siap' : 'Perlu Izin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Top Bento Row: Media Playback Glass Widget + Vertical Volume/Glass Sliders
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: iOS 27 Media Now Playing Widget
                Expanded(
                  flex: 6,
                  child: LiquidGlassCard(
                    radius: 26,
                    chromaticAccent: accent,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: track == null
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  openNowPlayingSheet(parentContext);
                                },
                          child: Row(
                            children: [
                              if (track != null)
                                MiniSpinningVinyl(
                                  artworkUrl: track.bestThumbUrl(size: 180),
                                  size: 46,
                                  isPlaying: player.isPlaying,
                                  accentColor: accent,
                                )
                              else
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.pillOf(context),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.music_note,
                                    color: sub,
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (track != null)
                                      MarqueeText(
                                        text: track.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: ink,
                                        ),
                                      )
                                    else
                                      Text(
                                        'Tidak ada lagu',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                    Text(
                                      track?.artistDisplay ?? 'Pilih lagu di Beranda',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: sub),
                                    ),
                                  ],
                                ),
                              ),
                              if (track != null)
                                AnimatedEqualizer(
                                  color: accent,
                                  isPlaying: player.isPlaying,
                                  size: 15,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ccTransportBtn(
                              icon: CupertinoIcons.backward_fill,
                              ink: ink,
                              onTap: track == null ? null : pNotifier.skipPrevious,
                            ),
                            LiquidGlassTap(
                              onTap: track == null ? null : pNotifier.togglePlayPause,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: ink,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  player.isPlaying
                                      ? CupertinoIcons.pause_fill
                                      : CupertinoIcons.play_fill,
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            _ccTransportBtn(
                              icon: CupertinoIcons.forward_fill,
                              ink: ink,
                              onTap: track == null ? null : pNotifier.skipNext,
                            ),
                            _ccTransportBtn(
                              icon: isLiked
                                  ? CupertinoIcons.heart_fill
                                  : CupertinoIcons.heart,
                              ink: isLiked ? AppColors.iosPink : ink,
                              onTap: track == null
                                  ? null
                                  : () => ref
                                      .read(libraryProvider.notifier)
                                      .toggleLike(track),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Right: iOS Vertical Capsule Sliders (Volume & Liquid Glass Opacity)
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Expanded(
                        child: _IosVerticalCapsuleSlider(
                          value: player.volume,
                          icon: player.volume <= 0.02
                              ? CupertinoIcons.volume_off
                              : (player.volume < 0.5
                                  ? CupertinoIcons.volume_down
                                  : CupertinoIcons.volume_up),
                          label: 'Vol',
                          accent: accent,
                          onChanged: pNotifier.setVolume,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _IosVerticalCapsuleSlider(
                          value: settings.liquidGlassOpacity,
                          icon: CupertinoIcons.sparkles,
                          label: 'Kaca',
                          accent: AppColors.iosBlue,
                          onChanged: sNotifier.setLiquidGlassOpacity,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick Control Center Toggle Grid (3x2 iOS Squircles)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
            children: [
              _CcTile(
                icon: settings.themePreference == AppThemePreference.dark
                    ? CupertinoIcons.moon_fill
                    : CupertinoIcons.sun_max_fill,
                title: 'Tema',
                subtitle: settings.themePreference.label,
                active: settings.themePreference == AppThemePreference.dark,
                accent: AppColors.iosIndigo,
                onTap: () {
                  final next = AppThemePreference.values[
                      (settings.themePreference.index + 1) %
                          AppThemePreference.values.length];
                  sNotifier.setThemePreference(next);
                  dNotifier.show(DynamicIslandEvent(
                    icon: CupertinoIcons.sun_max_fill,
                    title: 'Tema ${next.label}',
                    accent: AppColors.iosIndigo,
                  ));
                },
              ),
              _CcTile(
                icon: CupertinoIcons.sparkles,
                title: 'Tampilan',
                subtitle: settings.appearanceStyle == AppAppearanceStyle.glass
                    ? 'Liquid Glass'
                    : 'Datar',
                active: settings.appearanceStyle == AppAppearanceStyle.glass,
                accent: AppColors.iosBlue,
                onTap: () {
                  final next =
                      settings.appearanceStyle == AppAppearanceStyle.glass
                          ? AppAppearanceStyle.flat
                          : AppAppearanceStyle.glass;
                  sNotifier.setAppearanceStyle(next);
                  dNotifier.show(DynamicIslandEvent(
                    icon: CupertinoIcons.sparkles,
                    title: next.label,
                    accent: AppColors.iosBlue,
                  ));
                },
              ),
              _CcTile(
                icon: CupertinoIcons.waveform,
                title: 'Island',
                subtitle: settings.dynamicIslandEnabled ? 'Aktif' : 'Mati',
                active: settings.dynamicIslandEnabled,
                accent: AppColors.iosTeal,
                onTap: () async {
                  final next = !settings.dynamicIslandEnabled;
                  await sNotifier.setDynamicIslandEnabled(next);
                  if (next && !perms.notificationsGranted) {
                    await ref
                        .read(devicePermissionsProvider.notifier)
                        .requestNotifications();
                  }
                },
              ),
              _CcTile(
                icon: CupertinoIcons.headphones,
                title: 'Gaya Audio',
                subtitle: player.soundStyle.label,
                active: player.soundStyle != SoundStylePreset.normal,
                accent: AppColors.iosPink,
                onTap: () {
                  const presets = SoundStylePreset.values;
                  final next =
                      presets[(player.soundStyle.index + 1) % presets.length];
                  pNotifier.setSoundStyle(next);
                  dNotifier.show(DynamicIslandEvent(
                    icon: CupertinoIcons.headphones,
                    title: 'Gaya: ${next.label}',
                    subtitle: next.description,
                    accent: AppColors.iosPink,
                  ));
                },
              ),
              _CcTile(
                icon: CupertinoIcons.moon_fill,
                title: 'Timer',
                subtitle: player.sleepTimerRemaining != null
                    ? '${(player.sleepTimerRemaining!.inSeconds / 60).ceil()} mnt'
                    : (player.stopAfterCurrentTrack ? 'Akhir lagu' : 'Mati'),
                active: player.sleepTimerRemaining != null ||
                    player.stopAfterCurrentTrack,
                accent: AppColors.iosOrange,
                onTap: () {
                  final mins = player.sleepTimerRemaining?.inMinutes;
                  Duration? nextDur;
                  String msg;
                  if (player.sleepTimerRemaining == null &&
                      !player.stopAfterCurrentTrack) {
                    nextDur = const Duration(minutes: 15);
                    msg = 'Timer Tidur 15 menit';
                  } else if (mins != null && mins <= 15) {
                    nextDur = const Duration(minutes: 30);
                    msg = 'Timer Tidur 30 menit';
                  } else if (mins != null && mins <= 30) {
                    nextDur = const Duration(minutes: 60);
                    msg = 'Timer Tidur 60 menit';
                  } else {
                    nextDur = null;
                    msg = 'Timer Tidur dimatikan';
                  }
                  pNotifier.setSleepTimer(nextDur);
                  dNotifier.show(DynamicIslandEvent(
                    icon: CupertinoIcons.moon_fill,
                    title: msg,
                    accent: AppColors.iosOrange,
                  ));
                },
              ),
              _CcTile(
                icon: CupertinoIcons.slider_horizontal_3,
                title: 'Ekualiser',
                subtitle: settings.eqEnabled ? settings.eqPreset : 'Mati',
                active: settings.eqEnabled,
                accent: AppColors.iosGreen,
                onTap: () {
                  final next = !settings.eqEnabled;
                  sNotifier.setEqEnabled(next);
                  dNotifier.show(DynamicIslandEvent(
                    icon: CupertinoIcons.slider_horizontal_3,
                    title: next
                        ? 'Ekualiser: ${settings.eqPreset}'
                        : 'Ekualiser dimatikan',
                    accent: AppColors.iosGreen,
                  ));
                },
                onLongPress: onOpenEqualizer == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        onOpenEqualizer!();
                      },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Audio Quality Pill Selector
          LiquidGlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.speaker_2_fill, size: 17, color: ink),
                    const SizedBox(width: 8),
                    Text(
                      'Kualitas Streaming & Perizinan',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(settings.liquidGlassOpacity * 100).round()}% Kaca',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        color: sub,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: AudioQuality.values.map((q) {
                    final selected = settings.audioQuality == q;
                    final shortLabel = switch (q) {
                      AudioQuality.high => 'Tinggi',
                      AudioQuality.medium => 'Sedang',
                      AudioQuality.low => 'Hemat',
                    };
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: LiquidGlassTap(
                          onTap: () => sNotifier.setAudioQuality(q),
                          pressedScale: 0.94,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? ink
                                  : AppColors.pillOf(context).withAlpha(180),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Center(
                              child: Text(
                                shortLabel,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? (isDark ? Colors.black : Colors.white)
                                      : ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: AppColors.borderOf(context)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(CupertinoIcons.lock_fill, size: 16, color: ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lirik Lock Screen',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                    LiquidGlassTap(
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(devicePermissionsProvider.notifier)
                            .openLockScreenPreview();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pillOf(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Pratinjau',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    LiquidGlassToggleSwitch(
                      value: settings.lockScreenLyricsEnabled,
                      onChanged: sNotifier.setLockScreenLyricsEnabled,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ccTransportBtn({
    required IconData icon,
    required Color ink,
    required VoidCallback? onTap,
  }) {
    return LiquidGlassTap(
      onTap: onTap,
      pressedScale: 0.88,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          color: onTap == null ? ink.withAlpha(80) : ink,
          size: 22,
        ),
      ),
    );
  }
}

class _IosVerticalCapsuleSlider extends StatelessWidget {
  final double value;
  final IconData icon;
  final String label;
  final Color accent;
  final ValueChanged<double> onChanged;

  const _IosVerticalCapsuleSlider({
    required this.value,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final clamped = value.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 132.0;

        void updateFromLocalY(double localY) {
          final next = (1.0 - (localY / height)).clamp(0.0, 1.0);
          onChanged(next);
        }

        return GestureDetector(
          onVerticalDragUpdate: (d) => updateFromLocalY(d.localPosition.dy),
          onTapDown: (d) => updateFromLocalY(d.localPosition.dy),
          child: LiquidGlassCard(
            radius: 24,
            chromaticAccent: accent,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                FractionallySizedBox(
                  heightFactor: clamped,
                  widthFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withAlpha(isDark ? 190 : 210),
                          accent.withAlpha(isDark ? 230 : 235),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: clamped > 0.25 ? Colors.white : ink,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: clamped > 0.18 ? Colors.white : ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CcTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CcTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.accent,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return LiquidGlassTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: onLongPress,
      pressedScale: 0.94,
      child: LiquidGlassCard(
        radius: 22,
        tintColor: active ? accent.withAlpha(isDark ? 72 : 42) : null,
        chromaticAccent: active ? accent : null,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: active ? accent : AppColors.pillOf(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 17,
                color: active ? Colors.white : ink,
              ),
            ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w600,
                      color: active ? accent : sub,
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
