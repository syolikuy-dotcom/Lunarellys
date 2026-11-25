import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'state/auth_provider.dart';
import 'state/player_provider.dart';
import 'state/settings_provider.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.lunarellys.music.channel.audio',
    androidNotificationChannelName: 'Lunarellys Music Playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  final prefs = await SharedPreferences.getInstance();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF070707),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const LunarellysApp(),
    ),
  );
}

class LunarellysApp extends ConsumerWidget {
  const LunarellysApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dynamicColor = ref.watch(playerProvider.select((s) => s.dynamicColor));
    final useDynamic = ref.watch(settingsProvider.select((s) => s.dynamicAlbumColors));
    final onboardingDone = ref.watch(authProvider.select((s) => s.onboardingCompleted));

    return MaterialApp(
      title: 'Lunarellys',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(dynamicSeed: useDynamic ? dynamicColor : null),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        child: onboardingDone
            ? const MainShell(key: ValueKey('main_shell'))
            : const AuthScreen(key: ValueKey('auth_screen')),
      ),
    );
  }
}
