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

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isGoogle ? AppColors.surfaceHigh : AppColors.brandGreen,
              shape: BoxShape.circle,
              border: Border.all(
                color: isGoogle ? AppColors.brandGreen.withAlpha(180) : Colors.transparent,
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: picture.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: picture,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initialBadge(initial, isGoogle),
                  )
                : _initialBadge(initial, isGoogle),
          ),
          if (auth.isSyncing)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 12,
                height: 12,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: AppColors.brandGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialBadge(String initial, bool isGoogle) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.44,
          fontWeight: FontWeight.w800,
          color: isGoogle ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
