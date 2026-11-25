import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
import '../../state/settings_provider.dart';
import '../widgets/media_card.dart';
import '../widgets/user_avatar_button.dart';
import 'detail_screens.dart';

class ExploreData {
  final List<MusicSection> explore;
  final List<MusicSection> charts;
  final List<MusicMood> moods;

  const ExploreData({
    required this.explore,
    required this.charts,
    required this.moods,
  });
}

final exploreProvider = FutureProvider<ExploreData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final results = await Future.wait([
    api.getExplore(),
    api.getCharts().catchError((_) => <MusicSection>[]),
    api.getMoods().catchError((_) => <MusicMood>[]),
  ]);
  return ExploreData(
    explore: results[0] as List<MusicSection>,
    charts: results[1] as List<MusicSection>,
    moods: results[2] as List<MusicMood>,
  );
});

class ExploreScreen extends ConsumerWidget {
  final VoidCallback onOpenDrawer;
  const ExploreScreen({super.key, required this.onOpenDrawer});

  static const _moodPalette = [
    Color(0xFF1E3264),
    Color(0xFF8D67AB),
    Color(0xFFBA5D07),
    Color(0xFF148A08),
    Color(0xFFE8115B),
    Color(0xFF503750),
    Color(0xFF0D73EC),
    Color(0xFFAF2896),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(exploreProvider);

    return RefreshIndicator(
      color: AppColors.spotifyGreen,
      onRefresh: () => ref.refresh(exploreProvider.future),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            titleSpacing: 16,
            title: Row(
              children: [
                UserAvatarButton(size: 34, onTap: onOpenDrawer),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Explore & Charts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          asyncData.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.spotifyGreen),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load Explore', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => ref.invalidate(exploreProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (data) {
              final allSections = [...data.explore, ...data.charts];
              return SliverList(
                delegate: SliverChildListDelegate([
                  if (data.moods.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text('Moods & Genres', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.moods.take(12).length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 82,
                        ),
                        itemBuilder: (ctx, i) {
                          final mood = data.moods[i];
                          final color = _moodPalette[i % _moodPalette.length];
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => MoodPlaylistsScreen(mood: mood),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                color: color,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      right: -12,
                                      bottom: -10,
                                      child: Transform.rotate(
                                        angle: math.pi / 7,
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withAlpha(55),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.music_note_rounded,
                                            color: Colors.white54,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 12, 46, 12),
                                      child: Text(
                                        mood.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          height: 1.2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  ...allSections.map(
                    (sec) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              sec.title.isEmpty ? 'Discover' : sec.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 238,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: sec.items.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (ctx, i) => MediaCard(
                                item: sec.items[i],
                                contextQueue: sec.items,
                                width: 148,
                                contextLabel: sec.title.isEmpty ? 'Explore' : sec.title,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 132),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}
