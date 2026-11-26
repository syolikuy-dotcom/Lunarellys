import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/player_provider.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/lunarellys_drawer.dart';
import '../widgets/lunarellys_logo.dart';
import '../widgets/mini_player.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _selectTab(int idx) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = idx);
  }

  static const _navItems = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.search_rounded, Icons.search_rounded, 'Search'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Library'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final hasTrack = ref.watch(playerProvider.select((s) => s.currentTrack != null));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final screens = [
      HomeScreen(onOpenDrawer: _openDrawer),
      SearchScreen(onOpenDrawer: _openDrawer),
      LibraryScreen(onOpenDrawer: _openDrawer),
      ExploreScreen(onOpenDrawer: _openDrawer),
    ];

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: LunarellysDrawer(onNavigateTab: _selectTab),
      body: Row(
        children: [
          if (isWide)
            RepaintBoundary(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xCC111820),
                        const Color(0xE6090D12),
                      ],
                    ),
                    border: const Border(
                      right: BorderSide(color: AppColors.border, width: 1.0),
                    ),
                  ),
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    indicatorColor: Colors.white.withAlpha(24),
                    selectedIconTheme: const IconThemeData(color: AppColors.brandGreenBright),
                    unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
                    selectedLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _openDrawer,
                            child: const LunarellysLogo(size: 42),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            AppConfig.appName,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    destinations: _navItems
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Icon(item.$1),
                            selectedIcon: Icon(item.$2),
                            label: Text(item.$3),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            ),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: screens,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: isWide ? bottomInset + 6 : bottomInset + 78,
                  child: IgnorePointer(
                    ignoring: !hasTrack,
                    child: AnimatedSlide(
                      offset: hasTrack ? Offset.zero : const Offset(0, 1.3),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: hasTrack ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: const MiniPlayer(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: LiquidGlassCapsule(
                  blurSigma: 13,
                  padding: const EdgeInsets.all(5),
                  child: SizedBox(
                    height: 52,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = constraints.maxWidth / _navItems.length;
                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              left: itemWidth * _selectedIndex,
                              top: 0,
                              bottom: 0,
                              width: itemWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.brandGreenBright.withAlpha(34),
                                      AppColors.brandGreen.withAlpha(22),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.brandGreenBright.withAlpha(56),
                                    width: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: List.generate(_navItems.length, (i) {
                                final item = _navItems[i];
                                final selected = _selectedIndex == i;
                                return Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _selectTab(i),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AnimatedScale(
                                          scale: selected ? 1.08 : 1.0,
                                          duration: const Duration(milliseconds: 240),
                                          curve: Curves.easeOutCubic,
                                          child: Icon(
                                            selected ? item.$2 : item.$1,
                                            size: 22,
                                            color: selected
                                                ? AppColors.brandGreenBright
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: selected ? Colors.white : AppColors.textSecondary,
                                          ),
                                          child: Text(
                                            item.$3,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
