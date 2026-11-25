import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../data/services/api_client.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main');
});

class AppSettingsState {
  final String serverUrl;
  final String apiKey;
  final AudioQuality audioQuality;
  final bool dynamicAlbumColors;
  final bool autoRadio;

  const AppSettingsState({
    required this.serverUrl,
    required this.apiKey,
    required this.audioQuality,
    required this.dynamicAlbumColors,
    required this.autoRadio,
  });

  AppSettingsState copyWith({
    String? serverUrl,
    String? apiKey,
    AudioQuality? audioQuality,
    bool? dynamicAlbumColors,
    bool? autoRadio,
  }) {
    return AppSettingsState(
      serverUrl: serverUrl ?? this.serverUrl,
      apiKey: apiKey ?? this.apiKey,
      audioQuality: audioQuality ?? this.audioQuality,
      dynamicAlbumColors: dynamicAlbumColors ?? this.dynamicAlbumColors,
      autoRadio: autoRadio ?? this.autoRadio,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(
          AppSettingsState(
            serverUrl: _prefs.getString('server_url') ?? AppConfig.defaultBaseUrl,
            apiKey: _prefs.getString('api_key') ?? AppConfig.defaultApiKey,
            audioQuality: AudioQuality.fromString(_prefs.getString('audio_quality')),
            dynamicAlbumColors: _prefs.getBool('dynamic_colors') ?? true,
            autoRadio: _prefs.getBool('auto_radio') ?? true,
          ),
        );

  Future<void> setServerConfig({required String url, required String apiKey}) async {
    final clean = url.trim().isEmpty ? AppConfig.defaultBaseUrl : url.trim();
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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettingsState>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});

final apiClientProvider = Provider<MusicApiClient>((ref) {
  final settings = ref.watch(settingsProvider);
  return MusicApiClient(baseUrl: settings.serverUrl, apiKey: settings.apiKey);
});
