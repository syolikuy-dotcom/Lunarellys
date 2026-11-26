import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';
import '../../state/library_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/detail_screens.dart';
import 'google_logo.dart';
import 'liquid_glass.dart';
import 'lunarellys_logo.dart';

class LunarellysDrawer extends ConsumerWidget {
  final ValueChanged<int> onNavigateTab;
  const LunarellysDrawer({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final library = ref.watch(libraryProvider);
    final user = auth.user;
    final name = user?.name ?? 'Pendengar Tamu';
    final isGoogle = auth.isSignedInGoogle;
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final border = AppColors.borderOf(context);

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width.clamp(268.0, 326.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
              color: isDark ? const Color(0xEC11151B) : const Color(0xF4FFFFFF),
              border: Border(right: BorderSide(color: border, width: 1)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isGoogle ? AppColors.horizonBlue : AppColors.pillOf(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: border, width: 1.2),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: user?.picture.isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: user!.picture,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _initialAvatar(user.initials, isGoogle, ink),
                                  )
                                : _initialAvatar(user?.initials ?? 'L', isGoogle, ink),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isGoogle ? 'Tersinkron ke cloud' : 'Tamu · Ketuk untuk lihat profil',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, color: sub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: border),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      children: [
                        if (!isGoogle)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AuthScreen(allowBack: true),
                                  ),
                                );
                              },
                              child: LiquidGlassSurface(
                                borderRadius: BorderRadius.circular(18),
                                blurSigma: 16,
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white : AppColors.lightSurfaceMuted,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(child: GoogleLogoIcon(size: 18)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Masuk dengan YouTube Music',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: ink,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Sinkron lagu disukai & playlist',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 11.5, color: sub),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ListTile(
                            leading: auth.isSyncing
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: ink),
                                  )
                                : const Icon(Icons.cloud_done_rounded, color: AppColors.horizonBlue),
                            title: Text('Sinkron Cloud', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              auth.isSyncing
                                  ? 'Menyinkronkan...'
                                  : 'Ketuk untuk sinkron ${library.likedSongs.length} lagu disukai',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: sub),
                            ),
                            onTap: () => ref.read(libraryProvider.notifier).syncWithCloud(),
                          ),
                        _drawerNavTile(
                          context,
                          icon: Icons.person_outline_rounded,
                          title: 'Kamu',
                          subtitle: 'Riwayat, Recap & Akun',
                          onTap: () {
                            Navigator.pop(context);
                            onNavigateTab(3);
                          },
                        ),
                        _drawerNavTile(
                          context,
                          icon: Icons.graphic_eq_rounded,
                          title: 'Ekualiser',
                          subtitle: 'Preset audio & tuning 5-band',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const EqualizerScreen()),
                            );
                          },
                        ),
                        _drawerNavTile(
                          context,
                          icon: Icons.bar_chart_rounded,
                          title: 'Statistik dan recap',
                          subtitle: '${library.recentlyPlayed.length} riwayat · Teratas 50',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const StatsRecapScreen()),
                            );
                          },
                        ),
                        _drawerNavTile(
                          context,
                          icon: Icons.groups_rounded,
                          title: 'Dengar bersama',
                          subtitle: 'Sinkron pemutaran langsung dengan teman',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const ListenTogetherScreen()),
                            );
                          },
                        ),
                        _drawerNavTile(
                          context,
                          icon: Icons.history_rounded,
                          title: 'Riwayat',
                          subtitle: '${library.recentlyPlayed.length} baru diputar',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
                            );
                          },
                        ),
                        _drawerNavTile(
                          context,
                          icon: Icons.settings_outlined,
                          title: 'Pengaturan',
                          subtitle: 'Suara, tampilan & penyimpanan',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        const LunarellysHorizonLogo(size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lunarellys',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                              Text(
                                'by ${AppConfig.developerName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.horizonBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isGoogle)
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await ref.read(authProvider.notifier).signOut();
                            },
                            child: const Text('Keluar', style: TextStyle(color: AppColors.error)),
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
    );
  }

  Widget _drawerNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final pill = AppColors.pillOf(context);
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: pill,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: ink, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: sub)),
      onTap: onTap,
    );
  }

  Widget _initialAvatar(String initial, bool isGoogle, Color ink) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: isGoogle ? Colors.white : ink,
        ),
      ),
    );
  }
}
