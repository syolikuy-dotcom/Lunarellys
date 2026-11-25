import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';
import '../../state/library_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/detail_screens.dart';
import 'google_logo.dart';
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
      backgroundColor: AppColors.surface,
      width: MediaQuery.of(context).size.width.clamp(260.0, 320.0),
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
                        color: isGoogle ? AppColors.surfaceHigh : AppColors.brandGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isGoogle ? AppColors.brandGreen : Colors.transparent,
                          width: 1.5,
                        ),
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
                            isGoogle ? 'View profile · Google Synced' : 'Guest · Tap to view profile',
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (!isGoogle)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AuthScreen(allowBack: true),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.brandGreen.withAlpha(42),
                                AppColors.surfaceElevated,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.brandGreen.withAlpha(90)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
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
                                color: AppColors.brandGreen,
                              ),
                            )
                          : const Icon(Icons.cloud_done_rounded, color: AppColors.brandGreen),
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
                  ListTile(
                    leading: const Icon(Icons.bolt_rounded, color: Colors.white),
                    title: const Text("What's new"),
                    subtitle: const Text('Charts & new releases'),
                    onTap: () {
                      Navigator.pop(context);
                      onNavigateTab(3);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_rounded, color: Colors.white),
                    title: const Text('Recents'),
                    subtitle: Text('${library.recentlyPlayed.length} recently played'),
                    onTap: () {
                      Navigator.pop(context);
                      onNavigateTab(2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.arrow_circle_down_rounded, color: Colors.white),
                    title: const Text('Offline Downloads'),
                    subtitle: Text('${library.downloadedTracks.length} saved tracks'),
                    onTap: () {
                      Navigator.pop(context);
                      onNavigateTab(2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: Colors.white),
                    title: const Text('Settings and privacy'),
                    subtitle: const Text('Account, playback quality & storage'),
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  const LunarellysLogo(size: 20),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Lunarellys Music',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
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
