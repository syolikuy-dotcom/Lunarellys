import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'mini_player.dart';

void openNowPlayingSheet(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const NowPlayingScreen(),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved);
        return FadeTransition(
          opacity: Tween<double>(begin: 0.75, end: 1.0).animate(curved),
          child: SlideTransition(position: slide, child: child),
        );
      },
    ),
  );
}

/// Overlays the floating Liquid Glass MiniPlayer at the bottom of secondary
/// screens when a track is loaded, matching the reference screenshots.
class SubscreenMiniPlayerLayer extends ConsumerWidget {
  final Widget child;
  final double bottomOffset;

  const SubscreenMiniPlayerLayer({
    super.key,
    required this.child,
    this.bottomOffset = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack != null),
    );
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        child,
        if (hasTrack)
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomInset + bottomOffset,
            child: MiniPlayer(
              onTap: () => openNowPlayingSheet(context),
            ),
          ),
      ],
    );
  }
}
