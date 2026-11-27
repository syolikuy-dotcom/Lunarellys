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
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/liquid_glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.lunarellys.music.channel.audio',
    androidNotificationChannelName: 'Archys Audio Playback',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();
  await LiquidGlassShaderEngine.ensureLoaded();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ArchysApp(),
    ),
  );
}

class ArchysApp extends ConsumerWidget {
  const ArchysApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingCompleted = ref.watch(
      authProvider.select((s) => s.onboardingCompleted),
    );
    final themePref = ref.watch(
      settingsProvider.select((s) => s.themePreference),
    );
    final dynamicAlbumColors = ref.watch(
      settingsProvider.select((s) => s.dynamicAlbumColors),
    );
    final dynamicColor = ref.watch(playerProvider.select((s) => s.dynamicColor));
    final accent = dynamicAlbumColors ? dynamicColor : null;

    final themeMode = switch (themePref) {
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
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.88, maxScaleFactor: 1.14),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: LaunchSplashGate(
        child: onboardingCompleted ? const MainShell() : const AuthScreen(),
      ),
    );
  }
}
