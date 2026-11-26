import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../data/services/api_client.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main');
});

class AppSettingsState {
  final String serverUrl;
  final String apiKey;
  final AudioQuality audioQuality;
  final bool dynamicAlbumColors;
  final bool autoRadio;
  final PlayerBackgroundStyle playerBackgroundStyle;
  final bool miniPlayerDynamicBg;
  final PlayerSliderStyle sliderStyle;
  final bool autoSkipOnError;
  final bool persistentQueue;
  final AppLanguageOption appLanguage;

  const AppSettingsState({
    required this.serverUrl,
    required this.apiKey,
    required this.audioQuality,
    required this.dynamicAlbumColors,
    required this.autoRadio,
    required this.playerBackgroundStyle,
    required this.miniPlayerDynamicBg,
    required this.sliderStyle,
    required this.autoSkipOnError,
    required this.persistentQueue,
    required this.appLanguage,
  });

  AppSettingsState copyWith({
    String? serverUrl,
    String? apiKey,
    AudioQuality? audioQuality,
    bool? dynamicAlbumColors,
    bool? autoRadio,
    PlayerBackgroundStyle? playerBackgroundStyle,
    bool? miniPlayerDynamicBg,
    PlayerSliderStyle? sliderStyle,
    bool? autoSkipOnError,
    bool? persistentQueue,
    AppLanguageOption? appLanguage,
  }) {
    return AppSettingsState(
      serverUrl: serverUrl ?? this.serverUrl,
      apiKey: apiKey ?? this.apiKey,
      audioQuality: audioQuality ?? this.audioQuality,
      dynamicAlbumColors: dynamicAlbumColors ?? this.dynamicAlbumColors,
      autoRadio: autoRadio ?? this.autoRadio,
      playerBackgroundStyle: playerBackgroundStyle ?? this.playerBackgroundStyle,
      miniPlayerDynamicBg: miniPlayerDynamicBg ?? this.miniPlayerDynamicBg,
      sliderStyle: sliderStyle ?? this.sliderStyle,
      autoSkipOnError: autoSkipOnError ?? this.autoSkipOnError,
      persistentQueue: persistentQueue ?? this.persistentQueue,
      appLanguage: appLanguage ?? this.appLanguage,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(
          AppSettingsState(
            serverUrl: AppConfig.normalizeServerUrl(
              _prefs.getString('server_url') ?? AppConfig.defaultBaseUrl,
            ),
            apiKey: _prefs.getString('api_key') ?? AppConfig.defaultApiKey,
            audioQuality: AudioQuality.fromString(_prefs.getString('audio_quality')),
            dynamicAlbumColors: _prefs.getBool('dynamic_colors') ?? true,
            autoRadio: _prefs.getBool('auto_radio') ?? true,
            playerBackgroundStyle: PlayerBackgroundStyle.fromString(
              _prefs.getString('player_bg_style'),
            ),
            miniPlayerDynamicBg: _prefs.getBool('mini_player_dynamic_bg') ?? true,
            sliderStyle: PlayerSliderStyle.fromString(_prefs.getString('slider_style')),
            autoSkipOnError: _prefs.getBool('auto_skip_error') ?? true,
            persistentQueue: _prefs.getBool('persistent_queue') ?? true,
            appLanguage: AppLanguageOption.fromString(_prefs.getString('app_language')),
          ),
        );

  Future<void> setServerConfig({required String url, required String apiKey}) async {
    final clean = url.trim().isEmpty
        ? AppConfig.defaultBaseUrl
        : AppConfig.normalizeServerUrl(url);
    final cleanKey = apiKey.trim();
    await _prefs.setString('server_url', clean);
    await _prefs.setString('api_key', cleanKey);
    state = state.copyWith(serverUrl: clean, apiKey: cleanKey);
  }

  Future<void> resetServerConfig() async {
    await _prefs.remove('server_url');
    await _prefs.remove('api_key');
    state = state.copyWith(
      serverUrl: AppConfig.defaultBaseUrl,
      apiKey: AppConfig.defaultApiKey,
    );
  }

  Future<void> setAudioQuality(AudioQuality quality) async {
    await _prefs.setString('audio_quality', quality.apiValue);
    state = state.copyWith(audioQuality: quality);
  }

  Future<void> setDynamicColors(bool enabled) async {
    await _prefs.setBool('dynamic_colors', enabled);
    state = state.copyWith(dynamicAlbumColors: enabled);
  }

  Future<void> setAutoRadio(bool enabled) async {
    await _prefs.setBool('auto_radio', enabled);
    state = state.copyWith(autoRadio: enabled);
  }

  Future<void> setPlayerBackgroundStyle(PlayerBackgroundStyle style) async {
    await _prefs.setString('player_bg_style', style.key);
    state = state.copyWith(playerBackgroundStyle: style);
  }

  Future<void> setMiniPlayerDynamicBg(bool enabled) async {
    await _prefs.setBool('mini_player_dynamic_bg', enabled);
    state = state.copyWith(miniPlayerDynamicBg: enabled);
  }

  Future<void> setSliderStyle(PlayerSliderStyle style) async {
    await _prefs.setString('slider_style', style.key);
    state = state.copyWith(sliderStyle: style);
  }

  Future<void> setAutoSkipOnError(bool enabled) async {
    await _prefs.setBool('auto_skip_error', enabled);
    state = state.copyWith(autoSkipOnError: enabled);
  }

  Future<void> setPersistentQueue(bool enabled) async {
    await _prefs.setBool('persistent_queue', enabled);
    if (!enabled) {
      await _prefs.remove('persisted_queue_v1');
    }
    state = state.copyWith(persistentQueue: enabled);
  }

  Future<void> setAppLanguage(AppLanguageOption lang) async {
    await _prefs.setString('app_language', lang.code);
    state = state.copyWith(appLanguage: lang);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettingsState>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});

final apiClientProvider = Provider<MusicApiClient>((ref) {
  final settings = ref.watch(settingsProvider);
  return MusicApiClient(baseUrl: settings.serverUrl, apiKey: settings.apiKey);
});
