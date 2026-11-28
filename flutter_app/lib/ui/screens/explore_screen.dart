import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../state/settings_provider.dart';
import '../widgets/liquid_glass.dart';
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

class ExploreScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenDrawer;
  const ExploreScreen({super.key, required this.onOpenDrawer});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _chartsKey = GlobalKey();
  final GlobalKey _moodsKey = GlobalKey();

  static const _moodAccentPalette = [
    Color(0xFFF5B400),
    Color(0xFF12D88A),
    Color(0xFF38BDF8),
    Color(0xFFA855F7),
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
  ];

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(exploreProvider);

    final isGlass = ref.watch(
      settingsProvider.select((s) => s.appearanceStyle == AppAppearanceStyle.glass),
    );
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return LiquidGlassAmbientBackground(
      child: RefreshIndicator(
        color: AppColors.brandGreenBright,
        onRefresh: () => ref.refresh(exploreProvider.future),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 68,
              titleSpacing: 16,
              flexibleSpace: RepaintBoundary(
                child: isGlass
                    ? ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 6,
                            sigmaY: 6,
                            tileMode: TileMode.clamp,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x880E1218)
                                  : const Color(0xAEF6F7FB),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.borderOf(context).withAlpha(110),
                                  width: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardOf(context),
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.borderOf(context),
                              width: 0.7,
                            ),
                          ),
                        ),
                      ),
              ),
              title: Row(
                children: [
                  UserAvatarButton(size: 36, onTap: widget.onOpenDrawer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        Text(
                          'Rilis baru, tangga lagu & suasana',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            asyncData.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CupertinoActivityIndicator(radius: 13),
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
                return SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _QuickExploreCard(
                              icon: CupertinoIcons.sparkles,
                              label: 'New\nReleases',
                              accent: AppColors.iosGreen,
                              onTap: () => _scrollCtrl.animateTo(
                                0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickExploreCard(
                              icon: CupertinoIcons.chart_bar_fill,
                              label: 'Top\nCharts',
                              accent: AppColors.iosBlue,
                              onTap: () => _scrollToSection(_chartsKey),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickExploreCard(
                              icon: CupertinoIcons.music_note_2,
                              label: 'Moods &\nGenres',
                              accent: AppColors.iosOrange,
                              onTap: () => _scrollToSection(_moodsKey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...data.explore.map((sec) => _buildSectionCarousel(context, sec)),
                    if (data.moods.isNotEmpty) ...[
                      Padding(
                        key: _moodsKey,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Text(
                          'Moods & Genres',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.moods.take(14).length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 58,
                          ),
                          itemBuilder: (ctx, i) {
                            final mood = data.moods[i];
                            final stripColor = _moodAccentPalette[i % _moodAccentPalette.length];
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MoodPlaylistsScreen(mood: mood),
                                  ),
                                );
                              },
                              child: LiquidGlassSurface(
                                borderRadius: BorderRadius.circular(14),
                                useBackdropBlur: false,
                                chromaticAccent: stripColor,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        color: stripColor,
                                        borderRadius: const BorderRadius.horizontal(
                                          left: Radius.circular(14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: Text(
                                          mood.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                    if (data.charts.isNotEmpty)
                      Container(
                        key: _chartsKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: data.charts
                              .map((sec) => _buildSectionCarousel(context, sec, fallbackTitle: 'Charts'))
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 164),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCarousel(
    BuildContext context,
    MusicSection sec, {
    String fallbackTitle = 'Discover',
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
}

class _QuickExploreCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickExploreCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    return LiquidGlassTap(
      onTap: onTap,
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(20),
        useBackdropBlur: false,
        chromaticAccent: accent,
        padding: const EdgeInsets.all(13),
        child: SizedBox(
          height: 68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: accent),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
