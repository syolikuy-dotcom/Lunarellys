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
    final name = user?.name ?? 'Guest Listener';
    final isGoogle = auth.isSignedInGoogle;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width.clamp(268.0, 326.0),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xD9162028),
                  const Color(0xEA0C1116),
                  const Color(0xF5070A0D),
                ],
              ),
              border: Border(
                right: BorderSide(color: Colors.white.withAlpha(22), width: 0.9),
              ),
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
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isGoogle ? AppColors.surfaceHigh : AppColors.brandGreenBright,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isGoogle ? AppColors.brandGreenBright : Colors.white.withAlpha(90),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brandGreen.withAlpha(65),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: user?.picture.isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: user!.picture,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _initialAvatar(user.initials, isGoogle),
                                  )
                                : _initialAvatar(user?.initials ?? 'L', isGoogle),
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
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isGoogle ? 'View profile · Cloud Synced' : 'Guest · Tap to view profile',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
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
                                borderRadius: 18,
                                blurSigma: 20,
                                tintColor: AppColors.brandDeep,
                                borderColor: AppColors.brandGreenBright.withAlpha(68),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(child: GoogleLogoIcon(size: 18)),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Sign in with Google',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Sync liked songs & playlists across devices',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary,
                                            ),
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
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppColors.brandGreenBright,
                                    ),
                                  )
                                : const Icon(Icons.cloud_done_rounded, color: AppColors.brandGreenBright),
                            title: const Text('Cloud Library Sync'),
                            subtitle: Text(
                              auth.isSyncing
                                  ? 'Syncing with cloud...'
                                  : 'Tap to sync ${library.likedSongs.length} liked songs',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => ref.read(libraryProvider.notifier).syncWithCloud(),
                          ),
                        _drawerNavTile(
                          icon: Icons.bolt_rounded,
                          title: "What's new",
                          subtitle: 'Charts & new releases',
                          onTap: () {
                            Navigator.pop(context);
                            onNavigateTab(3);
                          },
                        ),
                        _drawerNavTile(
                          icon: Icons.history_rounded,
                          title: 'Recents',
                          subtitle: '${library.recentlyPlayed.length} recently played',
                          onTap: () {
                            Navigator.pop(context);
                            onNavigateTab(2);
                          },
                        ),
                        _drawerNavTile(
                          icon: Icons.arrow_circle_down_rounded,
                          title: 'Offline Downloads',
                          subtitle: '${library.downloadedTracks.length} saved tracks',
                          onTap: () {
                            Navigator.pop(context);
                            onNavigateTab(2);
                          },
                        ),
                        _drawerNavTile(
                          icon: Icons.settings_outlined,
                          title: 'Settings and privacy',
                          subtitle: 'Appearance, playback & storage',
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
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        const LunarellysLogo(size: 30),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lunarellys Music',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Developed by ${AppConfig.developerName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandGreenBright,
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
                            child: const Text('Log out', style: TextStyle(color: AppColors.error)),
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
    );
  }

  Widget _drawerNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(16),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      onTap: onTap,
    );
  }

  Widget _initialAvatar(String initial, bool isGoogle) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: isGoogle ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
