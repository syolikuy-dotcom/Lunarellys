import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';

class UserAvatarButton extends ConsumerWidget {
  final double size;
  final VoidCallback onTap;

  const UserAvatarButton({
    super.key,
    this.size = 34,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final picture = user?.picture ?? '';
    final initial = user?.initials ?? 'L';
    final isGoogle = auth.isSignedInGoogle;
    final ink = AppColors.inkOf(context);
    final pill = AppColors.pillOf(context);
    final isDark = AppColors.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isGoogle ? AppColors.horizonBlue : pill,
              shape: BoxShape.circle,
              border: Border.all(
                color: isGoogle
                    ? AppColors.horizonBlue.withAlpha(200)
                    : AppColors.borderOf(context),
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: picture.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: picture,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initialBadge(initial, isGoogle, ink, isDark),
                  )
                : _initialBadge(initial, isGoogle, ink, isDark),
          ),
          if (auth.isSyncing)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 12,
                height: 12,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialBadge(String initial, bool isGoogle, Color ink, bool isDark) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: isGoogle ? Colors.white : ink,
        ),
      ),
    );
  }
}
