import 'dart:ui';

class AppConfig {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'http://nodedenisrealbaik.sinar.bonus.smasnug.web.id:4686',
  );

  static const String defaultApiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static const String appName = 'Archys';
  static const String appVersion = '4.3.6';
  static const String appBuildTag = 'universal';
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

enum AppAppearanceStyle {
  glass(
    'glass',
    'Liquid Glass',
    'Permukaan kaca adaptif dengan efek buram lembut',
  ),
  flat('flat', 'Datar (Flat)', 'Permukaan bersih minimalis tanpa blur');

  final String key;
  final String label;
  final String description;
  const AppAppearanceStyle(this.key, this.label, this.description);

  static AppAppearanceStyle fromString(String? raw) {
    return AppAppearanceStyle.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => AppAppearanceStyle.glass,
    );
  }
}

enum AppThemePreference {
  light('light', 'Terang', 'Latar putih editorial bersih'),
  dark('dark', 'Gelap', 'Tampilan gelap nyaman di malam hari'),
  system('system', 'Sistem', 'Ikuti tema perangkat');

  final String key;
  final String label;
  final String description;
  const AppThemePreference(this.key, this.label, this.description);

  static AppThemePreference fromString(String? raw) {
    return AppThemePreference.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => AppThemePreference.light,
    );
  }
}

enum SoundStylePreset {
  normal('normal', 'Normal', 'Audio asli tanpa modifikasi', 1.0, 1.0),
  spedUp('sped_up', 'Sped up', 'Tempo lebih cepat (+22%) & nada naik', 1.22, 1.12),
  slowedReverb('slowed', 'Slowed + reverb', 'Tempo lambat (-16%) & nuansa dalam', 0.84, 0.88),
  lofi('lofi', 'Lo-fi', 'Tempo santai hangat & lembut', 0.92, 0.95),
  eightD('8d', '8D', 'Nuansa spasial imersif seimbang', 0.98, 1.0),
  nightcore('nightcore', 'Nightcore', 'Energi tinggi (+30% kecepatan)', 1.30, 1.20);

  final String key;
  final String label;
  final String description;
  final double speed;
  final double pitch;

  const SoundStylePreset(
    this.key,
    this.label,
    this.description,
    this.speed,
    this.pitch,
  );

  static SoundStylePreset fromString(String? raw) {
    return SoundStylePreset.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => SoundStylePreset.normal,
    );
  }
}

enum AudioQuality {
  high('high', 'Tinggi (Bitrate Terbaik)'),
  medium('medium', 'Sedang (Seimbang)'),
  low('low', 'Rendah (Hemat Kuota)');

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
  blur('blur', 'Blur', 'Atmosfer sampul album lembut'),
  classic('classic', 'Klasik', 'Gradien adaptif dari warna album'),
  glowAnimated('glow', 'Glow Animasi', 'Aura warna album berdenyut halus'),
  liveMesh('mesh', 'Live Mesh', 'Gradien cairan multi-titik');

  final String key;
  final String label;
  final String description;
  const PlayerBackgroundStyle(this.key, this.label, this.description);

  static PlayerBackgroundStyle fromString(String? raw) {
    return PlayerBackgroundStyle.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => PlayerBackgroundStyle.classic,
    );
  }
}

enum MiniPlayerBackgroundStyle {
  blur('blur', 'Kaca Buram', 'Pil kaca buram transparan'),
  dynamic('dynamic', 'Dinamis', 'Sedikit diwarnai sampul lagu aktif'),
  glowAnimated('glow', 'Glow Animasi', 'Sorotan tepi lembut'),
  liveMesh('mesh', 'Live Mesh', 'Mesh warna adaptif halus');

  final String key;
  final String label;
  final String description;
  const MiniPlayerBackgroundStyle(this.key, this.label, this.description);

  static MiniPlayerBackgroundStyle fromString(String? raw, {bool fallbackDynamic = true}) {
    if (raw == null || raw.isEmpty) {
      return fallbackDynamic ? MiniPlayerBackgroundStyle.blur : MiniPlayerBackgroundStyle.blur;
    }
    return MiniPlayerBackgroundStyle.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => MiniPlayerBackgroundStyle.blur,
    );
  }
}

enum PlayerSliderStyle {
  standard('default', 'Standar'),
  wavy('wavy', 'Bergelombang'),
  slim('slim', 'Ramping'),
  squiggly('squiggly', 'Squiggly');

  final String key;
  final String label;
  const PlayerSliderStyle(this.key, this.label);

  static PlayerSliderStyle fromString(String? raw) {
    return PlayerSliderStyle.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => PlayerSliderStyle.standard,
    );
  }
}

enum AppLanguageOption {
  system('system', 'Default Indonesia / Sistem', 'Bahasa Indonesia sebagai standar'),
  id('id', 'Bahasa Indonesia', 'Indonesia'),
  en('en', 'English', 'English (International)');

  final String code;
  final String label;
  final String subtitle;
  const AppLanguageOption(this.code, this.label, this.subtitle);

  static AppLanguageOption fromString(String? raw) {
    return AppLanguageOption.values.firstWhere(
      (l) => l.code == raw,
      orElse: () => AppLanguageOption.id,
    );
  }

  bool get isIndonesian {
    if (this == AppLanguageOption.id) return true;
    if (this == AppLanguageOption.en) return false;
    final sys = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return sys == 'id' || sys != 'en';
  }
}

class AppStrings {
  final bool id;
  const AppStrings._(this.id);

  factory AppStrings.of(AppLanguageOption opt) => AppStrings._(opt.isIndonesian);

  String greeting(int hour) {
    if (id) {
      if (hour < 11) return 'Selamat pagi';
      if (hour < 15) return 'Selamat siang';
      if (hour < 19) return 'Selamat sore';
      return 'Selamat malam';
    }
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String get navHome => id ? 'Beranda' : 'Home';
  String get navSearch => id ? 'Cari' : 'Search';
  String get navLibrary => id ? 'Pustaka' : 'Library';
  String get navYou => id ? 'Kamu' : 'You';

  String get speedDial => id ? 'Andalanmu' : 'Speed dial';
  String get quickPicks => id ? 'Pilihan cepat' : 'Quick picks';
  String get playAll => id ? 'Putar semua' : 'Play all';
  String get moodAndGenres => id ? 'Suasana dan genre' : 'Moods & genres';
  String get newReleases => id ? 'Rilis baru' : 'New releases';

  String get searchHint =>
      id ? 'Cari lagu, album, artis...' : 'Search songs, albums, artists...';
  String get searchLocalHint =>
      id ? 'Cari di perangkat...' : 'Search on device...';
  String get browseAll => id ? 'Jelajahi semua' : 'Browse all';
  String get recentSearches => id ? 'Pencarian terakhir' : 'Recent searches';
  String get topResult => id ? 'Hasil teratas' : 'Top result';
  String get songs => id ? 'Lagu' : 'Songs';

  String get yourLibrary => id ? 'Pustaka' : 'Library';
  String get collections => id ? 'Koleksi' : 'Collections';
  String get likedSongs => id ? 'Disukai' : 'Liked';
  String get downloaded => id ? 'Diunduh' : 'Downloaded';
  String get cached => id ? 'Tersimpan di cache' : 'Cached';
  String get onDevice => id ? 'Di perangkat' : 'On device';
  String get myTop50 => id ? 'Teratas saya 50' : 'My Top 50';
  String get uploaded => id ? 'Diunggah' : 'Uploaded';
  String get createPlaylist => id ? 'Buat playlist' : 'Create playlist';

  String get history => id ? 'Riwayat' : 'History';
  String get statsRecap => id ? 'Statistik dan recap' : 'Stats & recap';
  String get listenTogether => id ? 'Dengar bersama' : 'Listen together';
  String get recognizeSong => id ? 'Kenali lagu' : 'Recognize song';
  String get equalizer => id ? 'Ekualiser' : 'Equalizer';
  String get settings => id ? 'Pengaturan' : 'Settings';
  String get about => id ? 'Tentang' : 'About';

  String get nowPlaying => id ? 'Sedang diputar' : 'Now playing';
  String get lyrics => id ? 'Lirik' : 'Lyrics';
  String get queue => id ? 'Antrean' : 'Queue';
  String get resyncLyrics => id ? 'Sinkron ulang' : 'Resync';
}
