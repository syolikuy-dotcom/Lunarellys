import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../services/api_client.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main');
});

class AppSettingsState {
  final String serverUrl;
  final String apiKey;
  final bool serverManualOverride;
  final AudioQuality audioQuality;
  final bool dynamicAlbumColors;
  final bool autoRadio;
  final AppAppearanceStyle appearanceStyle;
  final double liquidGlassOpacity;
  final AppThemePreference themePreference;
  final PlayerBackgroundStyle playerBackgroundStyle;
  final MiniPlayerBackgroundStyle miniPlayerBackgroundStyle;
  final bool miniPlayerDynamicBg;
  final PlayerSliderStyle sliderStyle;
  final bool autoSkipOnError;
  final bool persistentQueue;
  final AppLanguageOption appLanguage;
  final int lyricsOffsetMs;
  final bool showIntervalIndicator;
  final bool aiTranslateLyrics;
  final bool agentPositionSync;
  final bool romanizeLyrics;
  final String lyricsSourceName;
  final int defaultSleepMinutes;
  final bool pauseWatchHistory;
  final bool pauseSearchHistory;
  final bool androidAutoEnabled;
  final bool spotifyConnected;
  final String spotifyDisplayName;
  final bool eqEnabled;
  final String eqPreset;
  final List<double> eqBands;
  final Map<String, List<double>> customEqPresets;
  final String eqHeadphoneProfile;
  final bool showStreakOnHome;
  final bool dynamicIslandEnabled;
  final bool dynamicIslandAlwaysVisible;
  final bool dynamicIslandSystemOverlay;
  final String dynamicIslandPosition;
  final bool lockScreenLyricsEnabled;
  final bool hapticsEnabled;
  final String appIconKey;
  final DynamicIslandPreset dynamicIslandPreset;
  final int dynamicIslandAccentValue;
  final double dynamicIslandScale;
  final double dynamicIslandYOffset;
  final bool dynamicIslandShowLyrics;
  final bool chordsEnabled;
  final String chordMode; // 'easy' | 'key_c' | 'original'
  final int chordTranspose;
  final int chordCapo;

  const AppSettingsState({
    required this.serverUrl,
    required this.apiKey,
    this.serverManualOverride = false,
    required this.audioQuality,
    required this.dynamicAlbumColors,
    required this.autoRadio,
    this.appearanceStyle = AppAppearanceStyle.flat,
    this.liquidGlassOpacity = 0.26,
    this.themePreference = AppThemePreference.light,
    required this.playerBackgroundStyle,
    this.miniPlayerBackgroundStyle = MiniPlayerBackgroundStyle.blur,
    required this.miniPlayerDynamicBg,
    required this.sliderStyle,
    required this.autoSkipOnError,
    required this.persistentQueue,
    required this.appLanguage,
    this.lyricsOffsetMs = 0,
    this.showIntervalIndicator = true,
    this.aiTranslateLyrics = false,
    this.agentPositionSync = false,
    this.romanizeLyrics = true,
    this.lyricsSourceName = 'Auto Terbaik',
    this.defaultSleepMinutes = 30,
    this.pauseWatchHistory = false,
    this.pauseSearchHistory = false,
    this.androidAutoEnabled = true,
    this.spotifyConnected = false,
    this.spotifyDisplayName = '',
    this.eqEnabled = false,
    this.eqPreset = 'Datar',
    this.eqBands = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.customEqPresets = const {},
    this.eqHeadphoneProfile = 'Bawaan',
    this.showStreakOnHome = true,
    this.dynamicIslandEnabled = false,
    this.dynamicIslandAlwaysVisible = true,
    this.dynamicIslandSystemOverlay = true,
    this.dynamicIslandPosition = 'below',
    this.lockScreenLyricsEnabled = false,
    this.hapticsEnabled = true,
    this.appIconKey = 'bawaan',
    this.dynamicIslandPreset = DynamicIslandPreset.classicBlack,
    this.dynamicIslandAccentValue = 0,
    this.dynamicIslandScale = 1.0,
    this.dynamicIslandYOffset = 0.0,
    this.dynamicIslandShowLyrics = true,
    this.chordsEnabled = false,
    this.chordMode = 'easy',
    this.chordTranspose = 0,
    this.chordCapo = 1,
  });

  AppSettingsState copyWith({
    String? serverUrl,
    String? apiKey,
    bool? serverManualOverride,
    AudioQuality? audioQuality,
    bool? dynamicAlbumColors,
    bool? autoRadio,
    AppAppearanceStyle? appearanceStyle,
    double? liquidGlassOpacity,
    AppThemePreference? themePreference,
    PlayerBackgroundStyle? playerBackgroundStyle,
    MiniPlayerBackgroundStyle? miniPlayerBackgroundStyle,
    bool? miniPlayerDynamicBg,
    PlayerSliderStyle? sliderStyle,
    bool? autoSkipOnError,
    bool? persistentQueue,
    AppLanguageOption? appLanguage,
    int? lyricsOffsetMs,
    bool? showIntervalIndicator,
    bool? aiTranslateLyrics,
    bool? agentPositionSync,
    bool? romanizeLyrics,
    String? lyricsSourceName,
    int? defaultSleepMinutes,
    bool? pauseWatchHistory,
    bool? pauseSearchHistory,
    bool? androidAutoEnabled,
    bool? spotifyConnected,
    String? spotifyDisplayName,
    bool? eqEnabled,
    String? eqPreset,
    List<double>? eqBands,
    Map<String, List<double>>? customEqPresets,
    String? eqHeadphoneProfile,
    bool? showStreakOnHome,
    bool? dynamicIslandEnabled,
    bool? dynamicIslandAlwaysVisible,
    bool? dynamicIslandSystemOverlay,
    String? dynamicIslandPosition,
    bool? lockScreenLyricsEnabled,
    bool? hapticsEnabled,
    String? appIconKey,
    DynamicIslandPreset? dynamicIslandPreset,
    int? dynamicIslandAccentValue,
    double? dynamicIslandScale,
    double? dynamicIslandYOffset,
    bool? dynamicIslandShowLyrics,
    bool? chordsEnabled,
    String? chordMode,
    int? chordTranspose,
    int? chordCapo,
  }) {
    return AppSettingsState(
      serverUrl: serverUrl ?? this.serverUrl,
      apiKey: apiKey ?? this.apiKey,
      serverManualOverride: serverManualOverride ?? this.serverManualOverride,
      audioQuality: audioQuality ?? this.audioQuality,
      dynamicAlbumColors: dynamicAlbumColors ?? this.dynamicAlbumColors,
      autoRadio: autoRadio ?? this.autoRadio,
      appearanceStyle: appearanceStyle ?? this.appearanceStyle,
      liquidGlassOpacity: liquidGlassOpacity ?? this.liquidGlassOpacity,
      themePreference: themePreference ?? this.themePreference,
      playerBackgroundStyle: playerBackgroundStyle ?? this.playerBackgroundStyle,
      miniPlayerBackgroundStyle:
          miniPlayerBackgroundStyle ?? this.miniPlayerBackgroundStyle,
      miniPlayerDynamicBg: miniPlayerDynamicBg ?? this.miniPlayerDynamicBg,
      sliderStyle: sliderStyle ?? this.sliderStyle,
      autoSkipOnError: autoSkipOnError ?? this.autoSkipOnError,
      persistentQueue: persistentQueue ?? this.persistentQueue,
      appLanguage: appLanguage ?? this.appLanguage,
      lyricsOffsetMs: lyricsOffsetMs ?? this.lyricsOffsetMs,
      showIntervalIndicator:
          showIntervalIndicator ?? this.showIntervalIndicator,
      aiTranslateLyrics: aiTranslateLyrics ?? this.aiTranslateLyrics,
      agentPositionSync: agentPositionSync ?? this.agentPositionSync,
      romanizeLyrics: romanizeLyrics ?? this.romanizeLyrics,
      lyricsSourceName: lyricsSourceName ?? this.lyricsSourceName,
      defaultSleepMinutes: defaultSleepMinutes ?? this.defaultSleepMinutes,
      pauseWatchHistory: pauseWatchHistory ?? this.pauseWatchHistory,
      pauseSearchHistory: pauseSearchHistory ?? this.pauseSearchHistory,
      androidAutoEnabled: androidAutoEnabled ?? this.androidAutoEnabled,
      spotifyConnected: spotifyConnected ?? this.spotifyConnected,
      spotifyDisplayName: spotifyDisplayName ?? this.spotifyDisplayName,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqPreset: eqPreset ?? this.eqPreset,
      eqBands: eqBands ?? this.eqBands,
      customEqPresets: customEqPresets ?? this.customEqPresets,
      eqHeadphoneProfile: eqHeadphoneProfile ?? this.eqHeadphoneProfile,
      showStreakOnHome: showStreakOnHome ?? this.showStreakOnHome,
      dynamicIslandEnabled: dynamicIslandEnabled ?? this.dynamicIslandEnabled,
      dynamicIslandAlwaysVisible:
          dynamicIslandAlwaysVisible ?? this.dynamicIslandAlwaysVisible,
      dynamicIslandSystemOverlay:
          dynamicIslandSystemOverlay ?? this.dynamicIslandSystemOverlay,
      dynamicIslandPosition:
          dynamicIslandPosition ?? this.dynamicIslandPosition,
      lockScreenLyricsEnabled:
          lockScreenLyricsEnabled ?? this.lockScreenLyricsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      appIconKey: appIconKey ?? this.appIconKey,
      dynamicIslandPreset: dynamicIslandPreset ?? this.dynamicIslandPreset,
      dynamicIslandAccentValue:
          dynamicIslandAccentValue ?? this.dynamicIslandAccentValue,
      dynamicIslandScale: dynamicIslandScale ?? this.dynamicIslandScale,
      dynamicIslandYOffset: dynamicIslandYOffset ?? this.dynamicIslandYOffset,
      dynamicIslandShowLyrics:
          dynamicIslandShowLyrics ?? this.dynamicIslandShowLyrics,
      chordsEnabled: chordsEnabled ?? this.chordsEnabled,
      chordMode: chordMode ?? this.chordMode,
      chordTranspose: chordTranspose ?? this.chordTranspose,
      chordCapo: chordCapo ?? this.chordCapo,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettingsState> {
  final SharedPreferences _prefs;

  static List<double> _loadEqBands(SharedPreferences prefs) {
    final raw = prefs.getStringList('eq_bands');
    if (raw == null || raw.length != 5) return const [0.0, 0.0, 0.0, 0.0, 0.0];
    return raw.map((e) => (double.tryParse(e) ?? 0.0).clamp(-12.5, 12.5)).toList();
  }

  static Map<String, List<double>> _loadCustomEqPresets(SharedPreferences prefs) {
    try {
      final raw = prefs.getString('eq_custom_presets');
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final out = <String, List<double>>{};
      decoded.forEach((key, val) {
        if (val is List && val.length == 5) {
          out[key.toString()] = val
              .map((n) => ((n as num?)?.toDouble() ?? 0.0).clamp(-12.5, 12.5))
              .toList();
        }
      });
      return out;
    } catch (_) {
      return const {};
    }
  }

  SettingsNotifier(this._prefs)
      : super(
          AppSettingsState(
            serverUrl: AppConfig.normalizeServerUrl(
              _prefs.getString('server_url') ?? AppConfig.defaultBaseUrl,
            ),
            apiKey: _prefs.getString('api_key') ?? AppConfig.defaultApiKey,
            serverManualOverride: _prefs.getBool('server_manual_override') ?? false,
            audioQuality: AudioQuality.fromString(_prefs.getString('audio_quality')),
            dynamicAlbumColors: _prefs.getBool('dynamic_colors') ?? true,
            autoRadio: _prefs.getBool('auto_radio') ?? true,
            appearanceStyle: AppAppearanceStyle.fromString(_prefs.getString('appearance_style')),
            liquidGlassOpacity: (_prefs.getDouble('liquid_glass_opacity') ?? 0.48).clamp(0.0, 1.0),
            themePreference: AppThemePreference.fromString(_prefs.getString('theme_preference')),
            playerBackgroundStyle: PlayerBackgroundStyle.fromString(
              _prefs.getString('player_bg_style'),
            ),
            miniPlayerBackgroundStyle: MiniPlayerBackgroundStyle.fromString(
              _prefs.getString('mini_player_bg_style'),
              fallbackDynamic: _prefs.getBool('mini_player_dynamic_bg') ?? false,
            ),
            miniPlayerDynamicBg: (_prefs.getString('mini_player_bg_style') ?? 'blur') != 'blur',
            sliderStyle: PlayerSliderStyle.fromString(_prefs.getString('slider_style')),
            autoSkipOnError: _prefs.getBool('auto_skip_error') ?? true,
            persistentQueue: _prefs.getBool('persistent_queue') ?? true,
            appLanguage: AppLanguageOption.fromString(_prefs.getString('app_language')),
            lyricsOffsetMs: (_prefs.getInt('lyrics_offset_ms') ?? 0).clamp(-3000, 3000),
            showIntervalIndicator: _prefs.getBool('lyrics_interval_indicator') ?? true,
            aiTranslateLyrics: _prefs.getBool('lyrics_ai_translate') ?? false,
            agentPositionSync: _prefs.getBool('lyrics_agent_sync') ?? false,
            romanizeLyrics: _prefs.getBool('lyrics_romanize') ?? true,
            lyricsSourceName: _prefs.getString('lyrics_source_name') ?? 'Auto Terbaik',
            defaultSleepMinutes: (_prefs.getInt('default_sleep_minutes') ?? 30).clamp(5, 120),
            pauseWatchHistory: _prefs.getBool('pause_watch_history') ?? false,
            pauseSearchHistory: _prefs.getBool('pause_search_history') ?? false,
            androidAutoEnabled: _prefs.getBool('android_auto_enabled') ?? true,
            spotifyConnected: _prefs.getBool('spotify_connected') ?? false,
            spotifyDisplayName: _prefs.getString('spotify_display_name') ?? '',
            eqEnabled: _prefs.getBool('eq_enabled') ?? false,
            eqPreset: _prefs.getString('eq_preset') ?? 'Datar',
            eqBands: _loadEqBands(_prefs),
            customEqPresets: _loadCustomEqPresets(_prefs),
            eqHeadphoneProfile: _prefs.getString('eq_headphone_profile') ?? 'Bawaan',
            showStreakOnHome: _prefs.getBool('show_streak_home') ?? true,
            dynamicIslandEnabled: _prefs.getBool('dynamic_island_enabled') ?? false,
            dynamicIslandAlwaysVisible:
                _prefs.getBool('dynamic_island_always_visible') ?? true,
            dynamicIslandSystemOverlay:
                _prefs.getBool('dynamic_island_system_overlay') ?? true,
            dynamicIslandPosition:
                _prefs.getString('dynamic_island_position') ?? 'below',
            lockScreenLyricsEnabled:
                _prefs.getBool('lock_screen_lyrics_enabled') ?? false,
            hapticsEnabled: _prefs.getBool('haptics_enabled') ?? true,
            appIconKey: _prefs.getString('app_icon_key') ?? 'bawaan',
            dynamicIslandPreset: DynamicIslandPreset.fromString(
              _prefs.getString('dynamic_island_preset'),
            ),
            dynamicIslandAccentValue:
                _prefs.getInt('dynamic_island_accent_value') ?? 0,
            dynamicIslandScale:
                (_prefs.getDouble('dynamic_island_scale') ?? 1.0).clamp(0.8, 1.25),
            dynamicIslandYOffset:
                (_prefs.getDouble('dynamic_island_y_offset') ?? 0.0).clamp(-12.0, 36.0),
            dynamicIslandShowLyrics:
                _prefs.getBool('dynamic_island_show_lyrics') ?? true,
            chordsEnabled: _prefs.getBool('chords_enabled') ?? false,
            chordMode: _prefs.getString('chord_mode') ?? 'easy',
            chordTranspose: (_prefs.getInt('chord_transpose') ?? 0).clamp(-6, 6),
            chordCapo: (_prefs.getInt('chord_capo') ?? 1).clamp(0, 7),
          ),
        ) {
    unawaited(syncRemoteNodeConfig());
  }

  Future<bool> syncRemoteNodeConfig({bool force = false}) async {
    if (!force && state.serverManualOverride) return false;
    // Bootstrap: node tersimpan -> default build -> preset node. Yang pertama
    // menjawab /api/node/config dipakai.
    final bootstraps = <String>[];
    for (final raw in [state.serverUrl, AppConfig.defaultBaseUrl, AppConfig.pterodactylExampleUrl]) {
      final n = AppConfig.normalizeServerUrl(raw);
      if (!bootstraps.contains(n)) bootstraps.add(n);
    }
    for (final boot in bootstraps) {
      try {
        final client = MusicApiClient(baseUrl: boot);
        final remote = await client.fetchRemoteNodeConfig(bootstrapUrl: boot);
        if (!mounted) return false;
        final resolvedUrl = remote.serverUrl.isNotEmpty
            ? AppConfig.normalizeServerUrl(remote.serverUrl)
            : boot;
        final resolvedKey = remote.apiKey.trim();
        await _prefs.setString('server_url', resolvedUrl);
        await _prefs.setString('api_key', resolvedKey);
        await _prefs.setBool('server_manual_override', false);
        if (resolvedUrl != state.serverUrl ||
            resolvedKey != state.apiKey ||
            state.serverManualOverride) {
          state = state.copyWith(
            serverUrl: resolvedUrl,
            apiKey: resolvedKey,
            serverManualOverride: false,
          );
        }
        return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Future<void> setServerConfig({
    required String url,
    required String apiKey,
    bool manualOverride = true,
  }) async {
    final clean = url.trim().isEmpty
        ? AppConfig.defaultBaseUrl
        : AppConfig.normalizeServerUrl(url);
    final cleanKey = apiKey.trim();
    await _prefs.setString('server_url', clean);
    await _prefs.setString('api_key', cleanKey);
    await _prefs.setBool('server_manual_override', manualOverride);
    state = state.copyWith(
      serverUrl: clean,
      apiKey: cleanKey,
      serverManualOverride: manualOverride,
    );
  }

  Future<void> resetServerConfig() async {
    await _prefs.remove('server_url');
    await _prefs.remove('api_key');
    await _prefs.setBool('server_manual_override', false);
    state = state.copyWith(
      serverUrl: AppConfig.defaultBaseUrl,
      apiKey: AppConfig.defaultApiKey,
      serverManualOverride: false,
    );
    await syncRemoteNodeConfig(force: true);
  }

  Future<void> setAppearanceStyle(AppAppearanceStyle style) async {
    await _prefs.setString('appearance_style', style.key);
    state = state.copyWith(appearanceStyle: style);
  }

  Future<void> setLiquidGlassOpacity(double opacity) async {
    final clamped = opacity.clamp(0.0, 1.0);
    await _prefs.setDouble('liquid_glass_opacity', clamped);
    state = state.copyWith(liquidGlassOpacity: clamped);
  }

  Future<void> setThemePreference(AppThemePreference pref) async {
    await _prefs.setString('theme_preference', pref.key);
    state = state.copyWith(themePreference: pref);
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

  Future<void> setMiniPlayerBackgroundStyle(MiniPlayerBackgroundStyle style) async {
    await _prefs.setString('mini_player_bg_style', style.key);
    await _prefs.setBool('mini_player_dynamic_bg', style != MiniPlayerBackgroundStyle.blur);
    state = state.copyWith(
      miniPlayerBackgroundStyle: style,
      miniPlayerDynamicBg: style != MiniPlayerBackgroundStyle.blur,
    );
  }

  Future<void> setMiniPlayerDynamicBg(bool enabled) async {
    final style = enabled ? MiniPlayerBackgroundStyle.dynamic : MiniPlayerBackgroundStyle.blur;
    await setMiniPlayerBackgroundStyle(style);
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

  Future<void> setLyricsOffsetMs(int offsetMs) async {
    final clamped = offsetMs.clamp(-3000, 3000);
    await _prefs.setInt('lyrics_offset_ms', clamped);
    state = state.copyWith(lyricsOffsetMs: clamped);
  }

  Future<void> setShowIntervalIndicator(bool enabled) async {
    await _prefs.setBool('lyrics_interval_indicator', enabled);
    state = state.copyWith(showIntervalIndicator: enabled);
  }

  Future<void> setAiTranslateLyrics(bool enabled) async {
    await _prefs.setBool('lyrics_ai_translate', enabled);
    state = state.copyWith(aiTranslateLyrics: enabled);
  }

  Future<void> setAgentPositionSync(bool enabled) async {
    await _prefs.setBool('lyrics_agent_sync', enabled);
    state = state.copyWith(agentPositionSync: enabled);
  }

  Future<void> setRomanizeLyrics(bool enabled) async {
    await _prefs.setBool('lyrics_romanize', enabled);
    state = state.copyWith(romanizeLyrics: enabled);
  }

  Future<void> setLyricsSourceName(String name) async {
    await _prefs.setString('lyrics_source_name', name);
    state = state.copyWith(lyricsSourceName: name);
  }

  Future<void> setDefaultSleepMinutes(int minutes) async {
    final clamped = minutes.clamp(5, 120);
    await _prefs.setInt('default_sleep_minutes', clamped);
    state = state.copyWith(defaultSleepMinutes: clamped);
  }

  Future<void> setPauseWatchHistory(bool enabled) async {
    await _prefs.setBool('pause_watch_history', enabled);
    state = state.copyWith(pauseWatchHistory: enabled);
  }

  Future<void> setPauseSearchHistory(bool enabled) async {
    await _prefs.setBool('pause_search_history', enabled);
    state = state.copyWith(pauseSearchHistory: enabled);
  }

  Future<void> setAndroidAutoEnabled(bool enabled) async {
    await _prefs.setBool('android_auto_enabled', enabled);
    state = state.copyWith(androidAutoEnabled: enabled);
  }

  Future<void> setSpotifyConnection({required bool connected, String displayName = ''}) async {
    await _prefs.setBool('spotify_connected', connected);
    await _prefs.setString('spotify_display_name', displayName);
    state = state.copyWith(spotifyConnected: connected, spotifyDisplayName: displayName);
  }

  Future<void> setEqEnabled(bool enabled) async {
    await _prefs.setBool('eq_enabled', enabled);
    state = state.copyWith(eqEnabled: enabled);
  }

  Future<void> setEqPreset(String preset, List<double> bands) async {
    final clamped = bands.map((b) => b.clamp(-12.5, 12.5)).toList();
    await _prefs.setString('eq_preset', preset);
    await _prefs.setStringList('eq_bands', clamped.map((b) => b.toStringAsFixed(1)).toList());
    state = state.copyWith(eqPreset: preset, eqBands: clamped);
  }

  Future<void> setEqBand(int index, double value) async {
    if (index < 0 || index >= 5) return;
    final next = List<double>.from(state.eqBands);
    next[index] = value.clamp(-12.5, 12.5);
    await _prefs.setString('eq_preset', 'Kustom');
    await _prefs.setStringList('eq_bands', next.map((b) => b.toStringAsFixed(1)).toList());
    state = state.copyWith(eqPreset: 'Kustom', eqBands: next);
  }

  Future<void> saveCustomEqPreset(String name, List<double> bands) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || bands.length != 5) return;
    final clamped = bands.map((b) => b.clamp(-12.5, 12.5)).toList();
    final updated = Map<String, List<double>>.from(state.customEqPresets)
      ..[cleanName] = clamped;
    await _prefs.setString('eq_custom_presets', jsonEncode(updated));
    await _prefs.setString('eq_preset', cleanName);
    await _prefs.setStringList('eq_bands', clamped.map((b) => b.toStringAsFixed(1)).toList());
    state = state.copyWith(
      customEqPresets: updated,
      eqPreset: cleanName,
      eqBands: clamped,
    );
  }

  Future<void> deleteCustomEqPreset(String name) async {
    if (!state.customEqPresets.containsKey(name)) return;
    final updated = Map<String, List<double>>.from(state.customEqPresets)..remove(name);
    await _prefs.setString('eq_custom_presets', jsonEncode(updated));
    state = state.copyWith(
      customEqPresets: updated,
      eqPreset: state.eqPreset == name ? 'Kustom' : state.eqPreset,
    );
  }

  Future<void> setEqHeadphoneProfile(String profile) async {
    await _prefs.setString('eq_headphone_profile', profile);
    state = state.copyWith(eqHeadphoneProfile: profile);
  }

  Future<void> setShowStreakOnHome(bool enabled) async {
    await _prefs.setBool('show_streak_home', enabled);
    state = state.copyWith(showStreakOnHome: enabled);
  }

  Future<void> setDynamicIslandEnabled(bool enabled) async {
    await _prefs.setBool('dynamic_island_enabled', enabled);
    state = state.copyWith(dynamicIslandEnabled: enabled);
  }

  Future<void> setDynamicIslandAlwaysVisible(bool enabled) async {
    await _prefs.setBool('dynamic_island_always_visible', enabled);
    state = state.copyWith(dynamicIslandAlwaysVisible: enabled);
  }

  Future<void> setDynamicIslandSystemOverlay(bool enabled) async {
    await _prefs.setBool('dynamic_island_system_overlay', enabled);
    state = state.copyWith(dynamicIslandSystemOverlay: enabled);
  }

  Future<void> setDynamicIslandPosition(String position) async {
    final normalized = position == 'notch' ? 'notch' : 'below';
    await _prefs.setString('dynamic_island_position', normalized);
    state = state.copyWith(dynamicIslandPosition: normalized);
  }

  Future<void> setLockScreenLyricsEnabled(bool enabled) async {
    await _prefs.setBool('lock_screen_lyrics_enabled', enabled);
    state = state.copyWith(lockScreenLyricsEnabled: enabled);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    await _prefs.setBool('haptics_enabled', enabled);
    state = state.copyWith(hapticsEnabled: enabled);
  }

  Future<void> setAppIconKey(String key) async {
    await _prefs.setString('app_icon_key', key);
    state = state.copyWith(appIconKey: key);
  }

  Future<void> setDynamicIslandPreset(DynamicIslandPreset preset) async {
    await _prefs.setString('dynamic_island_preset', preset.key);
    state = state.copyWith(dynamicIslandPreset: preset);
  }

  Future<void> setDynamicIslandAccentValue(int colorValue) async {
    await _prefs.setInt('dynamic_island_accent_value', colorValue);
    state = state.copyWith(dynamicIslandAccentValue: colorValue);
  }

  Future<void> setDynamicIslandScale(double scale) async {
    final clamped = scale.clamp(0.8, 1.25);
    await _prefs.setDouble('dynamic_island_scale', clamped);
    state = state.copyWith(dynamicIslandScale: clamped);
  }

  Future<void> setDynamicIslandYOffset(double offset) async {
    final clamped = offset.clamp(-12.0, 36.0);
    await _prefs.setDouble('dynamic_island_y_offset', clamped);
    state = state.copyWith(dynamicIslandYOffset: clamped);
  }

  Future<void> setDynamicIslandShowLyrics(bool enabled) async {
    await _prefs.setBool('dynamic_island_show_lyrics', enabled);
    state = state.copyWith(dynamicIslandShowLyrics: enabled);
  }

  Future<void> setChordsEnabled(bool enabled) async {
    await _prefs.setBool('chords_enabled', enabled);
    state = state.copyWith(chordsEnabled: enabled);
  }

  Future<void> setChordMode(String mode) async {
    await _prefs.setString('chord_mode', mode);
    state = state.copyWith(chordMode: mode);
  }

  Future<void> setChordTranspose(int transpose) async {
    final clamped = transpose.clamp(-6, 6);
    await _prefs.setInt('chord_transpose', clamped);
    state = state.copyWith(chordTranspose: clamped);
  }

  Future<void> setChordCapo(int capo) async {
    final clamped = capo.clamp(0, 7);
    await _prefs.setInt('chord_capo', clamped);
    state = state.copyWith(chordCapo: clamped);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettingsState>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});

final apiClientProvider = Provider<MusicApiClient>((ref) {
  final creds = ref.watch(
    settingsProvider.select((s) => (s.serverUrl, s.apiKey)),
  );
  return MusicApiClient(baseUrl: creds.$1, apiKey: creds.$2);
});
