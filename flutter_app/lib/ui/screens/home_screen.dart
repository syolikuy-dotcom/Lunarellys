import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/music_models.dart';
import '../../data/services/api_client.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/animated_eq.dart';
import '../widgets/artwork_image.dart';
import '../widgets/media_card.dart';
import '../widgets/user_avatar_button.dart';
import 'detail_screens.dart';

final homeFeedProvider = FutureProvider<List<MusicSection>>((ref) async {
  return ref.watch(apiClientProvider).getHome();
});

final homeMoodsProvider = FutureProvider<List<MusicMood>>((ref) async {
  return ref.watch(apiClientProvider).getMoods().catchError((_) => <MusicMood>[]);
});

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenDrawer;
  const HomeScreen({super.key, required this.onOpenDrawer});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MusicMood? _selectedMood;
  Future<List<MusicSection>>? _moodSectionsFuture;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _selectMood(MusicMood? mood) {
    setState(() {
      _selectedMood = mood;
      if (mood == null) {
        _moodSectionsFuture = null;
      } else {
        _moodSectionsFuture = ref
            .read(apiClientProvider)
            .getMoodPlaylists(mood.browseId, mood.params);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);
    final moodsAsync = ref.watch(homeMoodsProvider);
    final library = ref.watch(libraryProvider);
    final recent = library.recentlyPlayed;
    final playerState = ref.watch(playerProvider);
    final ambient = playerState.dynamicColor ?? const Color(0xFF1A4D2E);

    final feedSections = feedAsync.valueOrNull ?? const <MusicSection>[];
    final playableFromFeed = feedSections
        .expand((s) => s.items)
        .where((i) => i.isPlayable)
        .toList();

    final rawShortcuts = recent.isNotEmpty
        ? recent.take(8).toList()
        : (feedSections.isNotEmpty ? feedSections.first.items.take(8).toList() : const <MusicItem>[]);
    final shufflePool = recent.isNotEmpty ? recent : playableFromFeed;
    final spotlightItem = playableFromFeed.isNotEmpty ? playableFromFeed.first : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: const Alignment(0.2, 0.35),
          colors: [
            ambient.withAlpha(62),
            AppColors.background,
          ],
        ),
      ),
      child: RefreshIndicator(
        color: AppColors.spotifyGreen,
        onRefresh: () async {
          if (_selectedMood != null) {
            _selectMood(_selectedMood);
            if (_moodSectionsFuture != null) {
              await _moodSectionsFuture;
            }
          } else {
            await ref.refresh(homeFeedProvider.future);
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              titleSpacing: 16,
              title: Row(
                children: [
                  UserAvatarButton(size: 34, onTap: widget.onOpenDrawer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _greeting(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                if (shufflePool.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded),
                    tooltip: 'Shuffle Quick Mix',
                    onPressed: () => ref
                        .read(playerProvider.notifier)
                        .playShuffled(shufflePool, contextName: 'Quick Mix'),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
            moodsAsync.when(
              data: (moods) {
                if (moods.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                final topMoods = moods.take(10).toList();
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                      scrollDirection: Axis.horizontal,
                      itemCount: topMoods.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          final selected = _selectedMood == null;
                          return ChoiceChip(
                            label: const Text('All'),
                            selected: selected,
                            onSelected: (_) => _selectMood(null),
                          );
                        }
                        final mood = topMoods[i - 1];
                        final selected = _selectedMood?.browseId == mood.browseId &&
                            _selectedMood?.params == mood.params;
                        return ChoiceChip(
                          label: Text(mood.name),
                          selected: selected,
                          onSelected: (_) => _selectMood(selected ? null : mood),
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            if (_selectedMood == null && rawShortcuts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rawShortcuts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      mainAxisExtent: 58,
                    ),
                    itemBuilder: (ctx, i) {
                      final item = rawShortcuts[i];
                      final isCurrent = playerState.currentTrack?.id == item.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _openShortcut(context, item, rawShortcuts),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.surfaceHigh
                                : AppColors.surfaceElevated.withAlpha(220),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            children: [
                              ArtworkImage(
                                url: item.bestThumbUrl(size: 160),
                                size: 58,
                                radius: 0,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      color: isCurrent
                                          ? AppColors.spotifyGreenBright
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: AnimatedEqualizer(
                                    color: AppColors.spotifyGreenBright,
                                    isPlaying: playerState.isPlaying,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_selectedMood == null && spotlightItem != null)
              SliverToBoxAdapter(
                child: _buildPickedForYouCard(context, spotlightItem, playableFromFeed, library),
              ),
            if (_selectedMood != null && _moodSectionsFuture != null)
              SliverToBoxAdapter(
                child: FutureBuilder<List<MusicSection>>(
                  future: _moodSectionsFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _buildLoading();
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text('Failed to load ${_selectedMood!.name}'),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: () => _selectMood(_selectedMood),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    final sections = snap.data ?? const <MusicSection>[];
                    if (sections.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No playlists found for this mood',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sections
                          .map((sec) => _buildSectionCarousel(
                                context,
                                sec,
                                fallbackTitle: _selectedMood!.name,
                              ))
                          .toList(),
                    );
                  },
                ),
              )
            else
              feedAsync.when(
                loading: () => SliverToBoxAdapter(child: _buildLoading()),
                error: (err, _) {
                  final safeMsg = err is MusicApiException
                      ? err.message
                      : 'Check your internet connection and tap Retry.';
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 42, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              "Couldn't load music right now",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              safeMsg,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: () => ref.invalidate(homeFeedProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                data: (sections) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) => _buildSectionCarousel(context, sections[index]),
                      childCount: sections.length,
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 132)),
          ],
        ),
      ),
    );
  }

  void _openShortcut(BuildContext context, MusicItem item, List<MusicItem> pool) {
    if (item.type == 'artist') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ArtistScreen(artistId: item.id)),
      );
    } else if (item.type == 'album' || item.type == 'single' || item.type == 'ep') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AlbumScreen(albumId: item.id)),
      );
    } else if (item.type == 'playlist') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlistId: item.id)),
      );
    } else {
      final playable = pool.where((e) => e.isPlayable).toList();
      ref.read(playerProvider.notifier).playTrack(
            item,
            queue: playable,
            contextName: 'Quick Picks',
          );
    }
  }

  Widget _buildPickedForYouCard(
    BuildContext context,
    MusicItem item,
    List<MusicItem> queue,
    LibraryState library,
  ) {
    final isLiked = library.isLiked(item.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Picked for you', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(playerProvider.notifier).playTrack(
                  item,
                  queue: queue,
                  contextName: 'Picked for you',
                ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ArtworkImage(
                    url: item.bestThumbUrl(size: 320),
                    size: 92,
                    radius: 8,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.album?.name.isNotEmpty == true
                              ? item.album!.name
                              : 'Recommended Track',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                isLiked
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 22,
                                color: isLiked ? AppColors.spotifyGreen : AppColors.textSecondary,
                              ),
                              onPressed: () =>
                                  ref.read(libraryProvider.notifier).toggleLike(item),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: AppColors.spotifyGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCarousel(
    BuildContext context,
    MusicSection sec, {
    String fallbackTitle = 'Made for you',
  }) {
    final title = sec.title.isEmpty ? fallbackTitle : sec.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
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
                contextLabel: title,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 160,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, __) => Container(
                        width: 148,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
}
