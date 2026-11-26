class AppConfig {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ais-dev-unkf34ocfel2cyv35n5gmi-665995967660.asia-northeast1.run.app',
  );

  static const String defaultApiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static const String appName = 'Lunarellys';
  static const String appVersion = '1.2.0';
  static const String developerName = 'Ikhwan Romadon';
  static const String pterodactylExampleUrl =
      'http://nodedenisrealbaik.sinar.bonus.smasnug.web.id:4686';

  static String normalizeServerUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return defaultBaseUrl;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}

enum AudioQuality {
  high('high', 'High (Best Bitrate)'),
  medium('medium', 'Medium (Balanced)'),
  low('low', 'Low (Data Saver)');

  final String apiValue;
  final String label;
  const AudioQuality(this.apiValue, this.label);

  static AudioQuality fromString(String? raw) {
    return AudioQuality.values.firstWhere(
      (q) => q.apiValue == raw,
      orElse: () => AudioQuality.high,
    );
  }
}

enum PlayerBackgroundStyle {
  blur('blur', 'Blur', 'Soft frosted artwork atmosphere'),
  classic('classic', 'Classic', 'Editorial dark gradient backdrop'),
  glowAnimated('glow', 'Glow Animated', 'Subtle pulsing emerald & album aura'),
  liveMesh('mesh', 'Live Mesh', 'Fluid multi-point ambient mesh');

  final String key;
  final String label;
  final String description;
  const PlayerBackgroundStyle(this.key, this.label, this.description);

  static PlayerBackgroundStyle fromString(String? raw) {
    return PlayerBackgroundStyle.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => PlayerBackgroundStyle.glowAnimated,
    );
  }
}

enum PlayerSliderStyle {
  standard('default', 'Default'),
  wavy('wavy', 'Wavy'),
  slim('slim', 'Slim'),
  squiggly('squiggly', 'Squiggly');

  final String key;
  final String label;
  const PlayerSliderStyle(this.key, this.label);

  static PlayerSliderStyle fromString(String? raw) {
    return PlayerSliderStyle.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => PlayerSliderStyle.wavy,
    );
  }
}

enum AppLanguageOption {
  system('system', 'System Default', 'Follow system locale'),
  en('en', 'English', 'English (International)'),
  id('id', 'Bahasa Indonesia', 'Indonesia');

  final String code;
  final String label;
  final String subtitle;
  const AppLanguageOption(this.code, this.label, this.subtitle);

  static AppLanguageOption fromString(String? raw) {
    return AppLanguageOption.values.firstWhere(
      (l) => l.code == raw,
      orElse: () => AppLanguageOption.system,
    );
  }
}
