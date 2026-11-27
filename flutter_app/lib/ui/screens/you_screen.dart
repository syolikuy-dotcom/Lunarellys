import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../services/device_permissions_service.dart';
import '../../state/auth_provider.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/ios_control_center.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/lunarellys_logo.dart';
import '../widgets/permissions_sheet.dart';
import '../widgets/subscreen_mini_player.dart';
import '../widgets/track_tile.dart';
import 'detail_screens.dart';
import 'ytm_login_screen.dart';

class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );
    final spotifyConnected = ref.watch(
      settingsProvider.select((s) => s.spotifyConnected),
    );
    final spotifyDisplayName = ref.watch(
      settingsProvider.select((s) => s.spotifyDisplayName),
    );
    final currentStreak = ref.watch(
      libraryProvider.select((s) => s.currentStreak),
    );
    final islandEnabled = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandEnabled),
    );
    final islandAlways = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandAlwaysVisible),
    );
    final hasTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack != null),
    );
    final perms = ref.watch(devicePermissionsProvider);
    final islandPosition = ref.watch(
      settingsProvider.select((s) => s.dynamicIslandPosition),
    );
    final islandShown = islandEnabled && (islandAlways || hasTrack);
    final islandClearance =
        islandShown ? (islandPosition == 'notch' ? 8.0 : 42.0) : 0.0;

    final T = AppStrings.of(appLanguage);
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final border = AppColors.borderOf(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical) {
              _scrollOffset.value = n.metrics.pixels;
            }
            return false;
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, topPad + 16 + islandClearance, 16, 170),
            children: [
              // Clean Kamu title + iOS Control Center quick button
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        T.navYou,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
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
                      child: LiquidGlassCapsule(
                        blurSigma: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.slider_horizontal_3, size: 17, color: ink),
                            const SizedBox(width: 5),
                            Text(
                              'Kontrol',
                              style: TextStyle(
                                fontSize: 12.5,
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
              ),

              // Percikan Streak Banner Card
              PercikanBannerCard(
                streakDays: currentStreak,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const StatsRecapScreen()),
                ),
              ),
              const SizedBox(height: 14),

              LiquidGlassCard(
                radius: 22,
                child: Column(
                  children: [
                    _menuRow(
                      context,
                      icon: CupertinoIcons.clock_fill,
                      iconBg: AppColors.iosBlue,
                      title: T.history,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: border),
                    _menuRow(
                      context,
                      icon: CupertinoIcons.chart_bar_fill,
                      iconBg: AppColors.iosOrange,
                      title: T.statsRecap,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const StatsRecapScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LiquidGlassCard(
                radius: 22,
                child: Column(
                  children: [
                    _menuRow(
                      context,
                      icon: CupertinoIcons.person_2_fill,
                      iconBg: AppColors.iosIndigo,
                      title: T.listenTogether,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const ListenTogetherScreen()),
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: border),
                    _menuRow(
                      context,
                      icon: CupertinoIcons.mic_fill,
                      iconBg: AppColors.iosPink,
                      title: T.recognizeSong,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SongRecognitionScreen()),
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: border),
                    _menuRow(
                      context,
                      icon: CupertinoIcons.waveform,
                      iconBg: AppColors.iosGreen,
                      title: T.equalizer,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const EqualizerScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Akun',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: sub,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _AccountCard(
                      bgColor: isDark
                          ? const Color(0x9928171B)
                          : const Color(0xB8FDF1F2),
                      chromaticAccent: const Color(0xFFFF3B30),
                      logo: const YouTubeMusicLogoIcon(size: 46),
                      title: 'YouTube Music',
                      subtitle: auth.isSignedInGoogle
                          ? (auth.user?.name ?? 'Tersambung')
                          : 'Sinkronkan pustaka\ndan playlist',
                      buttonLabel: auth.isSignedInGoogle ? 'Tersambung' : 'Masuk',
                      isConnected: auth.isSignedInGoogle,
                      onPressed: () {
                        if (auth.isSignedInGoogle) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const YouTubeMusicLoginScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AccountCard(
                      bgColor: isDark
                          ? const Color(0x9914271C)
                          : const Color(0xB8EEF9F2),
                      chromaticAccent: const Color(0xFF1DB954),
                      logo: const SpotifyLogoIcon(size: 46),
                      title: 'Spotify',
                      subtitle: spotifyConnected
                          ? (spotifyDisplayName.isNotEmpty
                              ? spotifyDisplayName
                              : 'Tersambung ke Pustaka')
                          : 'Playlist tampil di\nPustaka',
                      buttonLabel: spotifyConnected ? 'Kelola' : 'Hubungkan',
                      isConnected: spotifyConnected,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SpotifyConnectScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LiquidGlassCard(
                radius: 22,
                child: Column(
                  children: [
                    _menuRow(
                      context,
                      icon: CupertinoIcons.bell_fill,
                      iconBg: AppColors.iosRed,
                      title: 'Perizinan & Latar Belakang',
                      trailingBadge: perms.backgroundReady ? 'Siap' : 'Atur',
                      badgeColor: perms.backgroundReady
                          ? AppColors.iosGreen
                          : AppColors.iosOrange,
                      onTap: () => showPermissionsAndBackgroundSheet(context, ref),
                    ),
                    Divider(height: 1, indent: 60, color: border),
                    _menuRow(
                      context,
                      icon: CupertinoIcons.gear_alt_fill,
                      iconBg: const Color(0xFF64748B),
                      title: T.settings,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: border),
                    _menuRow(
                      context,
                      icon: CupertinoIcons.info_circle_fill,
                      iconBg: AppColors.iosTeal,
                      title: T.about,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Center(
                  child: Text(
                    '${AppConfig.appName} v${AppConfig.appVersion} · ${AppConfig.developerName}',
                    style: TextStyle(fontSize: 12, color: ink.withAlpha(110)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sticky Liquid Glass "Kamu" top header on scroll (prevents collision with scrolled cards)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _scrollOffset,
            builder: (context, offset, child) {
              final stickyOpacity = ((offset - 22) / 30).clamp(0.0, 1.0);
              if (stickyOpacity <= 0.02) return const SizedBox.shrink();
              return IgnorePointer(
                ignoring: stickyOpacity < 0.2,
                child: Opacity(opacity: stickyOpacity, child: child),
              );
            },
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topPad + (islandShown ? 44 : 10),
                    16,
                    12,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF0E1218) : const Color(0xFFF6F7F9))
                        .withAlpha(isDark ? 190 : 210),
                    border: Border(
                      bottom: BorderSide(
                        color: border.withAlpha(130),
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          T.navYou,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: ink,
                          ),
                        ),
                      ),
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
                        child: Icon(CupertinoIcons.slider_horizontal_3, size: 21, color: ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuRow(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required String title,
    String? trailingBadge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: IosSquircleBadge(icon: icon, color: iconBg),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingBadge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? AppColors.iosBlue).withAlpha(28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailingBadge,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: badgeColor ?? AppColors.iosBlue,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(CupertinoIcons.chevron_forward, color: sub, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Color bgColor;
  final Color chromaticAccent;
  final Widget logo;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool isConnected;
  final VoidCallback onPressed;

  const _AccountCard({
    required this.bgColor,
    required this.chromaticAccent,
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.isConnected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return LiquidGlassCard(
      radius: 22,
      tintColor: bgColor,
      chromaticAccent: chromaticAccent,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          logo,
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 34,
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: sub,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isConnected
                    ? ink.withAlpha(26)
                    : (isDark ? Colors.white : const Color(0xFF111315)),
                foregroundColor: isConnected
                    ? ink
                    : (isDark ? Colors.black : Colors.white),
                padding: EdgeInsets.zero,
              ),
              onPressed: onPressed,
              child: Text(
                buttonLabel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Spotify Connect screen matching screenshot 16-23-49-23
class SpotifyConnectScreen extends ConsumerWidget {
  const SpotifyConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Spotify')),
      body: SubscreenMiniPlayerLayer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 128),
        children: [
          const Center(child: SpotifyLogoIcon(size: 74)),
          const SizedBox(height: 18),
          Text(
            'Hubungkan Spotify',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bawa playlist Spotify ke ${AppConfig.appName}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: sub),
          ),
          const SizedBox(height: 22),
          LiquidGlassCard(
            radius: 22,
            chromaticAccent: const Color(0xFF1DB954),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              children: [
                _featureRow(
                  icon: LibraryBooksIcon(size: 21, color: ink, filled: true),
                  text: 'Playlist dan lagu disukai di Pustaka',
                  ink: ink,
                ),
                const SizedBox(height: 18),
                _featureRow(
                  icon: Icon(Icons.play_arrow_rounded, color: ink, size: 24),
                  text: 'Lagu tetap diputar lewat YouTube Music',
                  ink: ink,
                ),
                const SizedBox(height: 18),
                _featureRow(
                  icon: Icon(Icons.movie_creation_outlined, color: ink, size: 22),
                  text: 'Sampul animasi dari Spotify',
                  ink: ink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF111315),
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => _showSpotifyConnectSheet(context, ref),
              child: Text(
                settings.spotifyConnected
                    ? 'Kelola (${settings.spotifyDisplayName})'
                    : 'Hubungkan Spotify',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (settings.spotifyConnected) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                await ref
                    .read(settingsProvider.notifier)
                    .setSpotifyConnection(connected: false, displayName: '');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Koneksi Spotify diputuskan')),
                  );
                }
              },
              child: const Text('Putuskan akun Spotify'),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Data masuk disimpan di HP ini dan tidak ikut cadangan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: sub),
          ),
        ],
        ),
      ),
    );
  }

  Widget _featureRow({
    required Widget icon,
    required String text,
    required Color ink,
  }) {
    return Row(
      children: [
        SizedBox(width: 28, child: Center(child: icon)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: ink,
            ),
          ),
        ),
      ],
    );
  }
}

void _showSpotifyConnectSheet(BuildContext context, WidgetRef ref) {
  final settings = ref.read(settingsProvider);
  final nameCtrl = TextEditingController(
    text: settings.spotifyDisplayName.isEmpty
        ? 'Playlist Spotify'
        : settings.spotifyDisplayName,
  );
  final queryCtrl = TextEditingController();
  final ink = AppColors.inkOf(context);
  final sub = AppColors.subOf(context);

  showLiquidGlassSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        6,
        20,
        MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SpotifyLogoIcon(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spotify Impor & Koneksi',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink),
                    ),
                    Text(
                      'Tampilkan & impor playlist ke Pustaka',
                      style: TextStyle(fontSize: 12.5, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama profil / playlist',
              hintText: 'Contoh: Playlist Santai',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: queryCtrl,
            decoration: const InputDecoration(
              labelText: 'Cari lagu atau tautan playlist untuk diimpor (opsional)',
              hintText: 'Contoh: Tulus / Hivi / Link playlist',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (settings.spotifyConnected)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(settingsProvider.notifier)
                          .setSpotifyConnection(connected: false, displayName: '');
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Putuskan'),
                  ),
                ),
              if (settings.spotifyConnected) const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final label = nameCtrl.text.trim().isEmpty
                        ? 'Playlist Spotify'
                        : nameCtrl.text.trim();
                    await ref
                        .read(settingsProvider.notifier)
                        .setSpotifyConnection(connected: true, displayName: label);
                    final q = queryCtrl.text.trim();
                    if (q.isNotEmpty) {
                      try {
                        final res =
                            await ref.read(apiClientProvider).search(q, filter: 'songs');
                        if (res.results.isNotEmpty) {
                          await ref.read(libraryProvider.notifier).createPlaylist(label);
                          final playlists = ref.read(libraryProvider).playlists;
                          if (playlists.isNotEmpty) {
                            final targetId = playlists.last.id;
                            for (final tr in res.results.take(8)) {
                              await ref
                                  .read(libraryProvider.notifier)
                                  .addTrackToPlaylist(targetId, tr);
                            }
                          }
                        }
                      } catch (_) {}
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Spotify tersambung ($label)')),
                      );
                    }
                  },
                  child: Text(settings.spotifyConnected ? 'Simpan' : 'Hubungkan'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    nameCtrl.dispose();
    queryCtrl.dispose();
  });
}

class SongRecognitionScreen extends ConsumerStatefulWidget {
  const SongRecognitionScreen({super.key});

  @override
  ConsumerState<SongRecognitionScreen> createState() => _SongRecognitionScreenState();
}

class _SongRecognitionScreenState extends ConsumerState<SongRecognitionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  final TextEditingController _clueCtrl = TextEditingController();
  bool _listening = false;
  bool _searching = false;
  String _statusText = 'Ketuk untuk mengenali';
  List<MusicItem> _matches = const [];
  Timer? _listenTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _listenTimer?.cancel();
    _pulseCtrl.dispose();
    _clueCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    HapticFeedback.mediumImpact();
    if (_listening) {
      _stopListening();
      return;
    }
    final perms = ref.read(devicePermissionsProvider);
    if (!perms.microphoneGranted) {
      final granted =
          await ref.read(devicePermissionsProvider.notifier).requestMicrophone();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _statusText =
              'Izin mikrofon dibutuhkan — ketuk lagi atau ketik lirik di bawah';
        });
        return;
      }
    }
    setState(() {
      _listening = true;
      _statusText = 'Mendengarkan audio di sekitar...';
    });
    _pulseCtrl.repeat();

    _listenTimer?.cancel();
    _listenTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      _pulseCtrl.stop();
      setState(() {
        _listening = false;
        _searching = true;
        _statusText = 'Mencocokkan sidik suara...';
      });
      await _findMatches();
    });
  }

  void _stopListening() {
    _listenTimer?.cancel();
    _pulseCtrl.stop();
    setState(() {
      _listening = false;
      _statusText = 'Ketuk untuk mengenali';
    });
  }

  Future<void> _findMatches() async {
    final recent = ref.read(libraryProvider).recentlyPlayed;
    final current = ref.read(playerProvider).currentTrack;
    final clue = _clueCtrl.text.trim();
    final query = clue.isNotEmpty
        ? clue
        : (current != null
            ? '${current.title} ${current.artistDisplay}'
            : (recent.isNotEmpty ? recent.first.title : 'Tulus Monokrom'));

    try {
      final res = await ref.read(apiClientProvider).search(query, filter: 'songs');
      if (!mounted) return;
      setState(() {
        _searching = false;
        _matches = res.results.take(6).toList();
        _statusText = _matches.isEmpty
            ? 'Tidak ada kecocokan langsung — ketik lirik atau judul di bawah'
            : 'Ditemukan ${_matches.length} lagu yang cocok';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _statusText = 'Ketuk lagi atau ketik penggalan lirik untuk mencari';
      });
    }
  }

  void _showRecognitionHistorySheet() {
    final history = ref.read(libraryProvider).recentlyPlayed;
    final ink = AppColors.inkOf(context);
    showLiquidGlassSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Row(
              children: [
                Text(
                  'Riwayat identifikasi & putar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Belum ada riwayat lagu.'),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
                itemCount: history.length.clamp(0, 15),
                itemBuilder: (_, i) => TrackTile(track: history[i], queue: history),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final pill = AppColors.pillOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kenali musik'),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: ink),
            tooltip: 'Riwayat',
            onPressed: _showRecognitionHistorySheet,
          ),
        ],
      ),
      body: SubscreenMiniPlayerLayer(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 128),
              child: Column(
                children: [
                  const SizedBox(height: 44),
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_listening)
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, __) {
                              final t = _pulseCtrl.value;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 140 + (t * 68),
                                    height: 140 + (t * 68),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ink.withAlpha(((1.0 - t) * 90).round()),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 136 + (((t + 0.5) % 1.0) * 60),
                                    height: 136 + (((t + 0.5) % 1.0) * 60),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ink.withAlpha(
                                        (((1.0 - ((t + 0.5) % 1.0)) * 30)).round(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        Container(
                          width: 162,
                          height: 162,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pill.withAlpha(160),
                          ),
                        ),
                        LiquidGlassTap(
                          onTap: _searching ? null : _toggleListen,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: _listening ? 148 : 136,
                            height: _listening ? 148 : 136,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : const Color(0xFF111315),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(isDark ? 90 : 35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _searching
                                  ? CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: isDark ? Colors.black : Colors.white,
                                    )
                                  : Icon(
                                      _listening
                                          ? Icons.graphic_eq_rounded
                                          : Icons.mic_rounded,
                                      size: 48,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: pill,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.music_note_rounded, color: sub, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _clueCtrl,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _findMatches(),
                            decoration: const InputDecoration(
                              hintText: 'Atau ketik penggalan lirik / judul...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.search_rounded, color: ink),
                          onPressed: _findMatches,
                        ),
                      ],
                    ),
                  ),
                  if (_matches.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Hasil Identifikasi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._matches.map(
                      (track) => TrackTile(track: track, queue: _matches),
                    ),
                  ],
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
