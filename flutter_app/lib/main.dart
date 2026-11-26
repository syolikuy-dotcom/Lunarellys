import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
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
    androidNotificationChannelName: 'Lunarellys Audio Playback',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();

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
    final auth = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final dynamicColor = ref.watch(playerProvider.select((s) => s.dynamicColor));
    final accent = settings.dynamicAlbumColors ? dynamicColor : null;

    final themeMode = switch (settings.themePreference) {
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
      AppThemePreference.system => ThemeMode.system,
    };

    final isDarkActive = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkActive ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDarkActive ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(dynamicSeed: accent),
      darkTheme: AppTheme.darkTheme(dynamicSeed: accent),
      themeMode: themeMode,
      home: auth.onboardingCompleted ? const MainShell() : const AuthScreen(),
    );
  }
}
