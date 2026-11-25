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
