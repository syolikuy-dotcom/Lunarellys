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
  flat('flat', 'Datar (Flat)', 'Permukaan iOS bersih & ringan tanpa efek kaca'),
  glass(
    'glass',
    'Liquid Glass',
    'Permukaan kaca iOS adaptif dengan efek buram lembut',
  );

  final String key;
  final String label;
  final String description;
  const AppAppearanceStyle(this.key, this.label, this.description);

  static AppAppearanceStyle fromString(String? raw) {
    return AppAppearanceStyle.values.firstWhere(
      (s) => s.key == raw,
      orElse: () => AppAppearanceStyle.flat,
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
  nightcore('nightcore', 'Nightcore', 'Energi tinggi (+30% kecepatan)', 1.30, 1.20),
  lofi('lofi', 'Lo-fi', 'Tempo santai hangat & lembut', 0.92, 0.95),
  eightD('8d', '8D', 'Nuansa spasial imersif seimbang', 0.98, 1.0),
  concert('concert', 'Konser', 'Gema aula konser lebar & vokal hangat', 0.97, 0.98);

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

enum DynamicIslandPreset {
  classicBlack('classic', 'Klasik Hitam', 'OLED hitam pekat khas iPhone'),
  ultraGlass('glass', 'Kaca Clear', 'Liquid Glass ultra bening & tajam'),
  dynamicCover('dynamic', 'Dinamis', 'Otomatis ikuti warna sampul lagu'),
  iosBlue('ios_blue', 'Biru iOS', 'Aksen safir cerah khas Apple'),
  aurora('aurora', 'Aurora', 'Bias spektrum ungu-biru neon'),
  minimalLight('minimal_light', 'Minimal Putih', 'Pil terang bersih kontras tinggi');

  final String key;
  final String label;
  final String description;
  const DynamicIslandPreset(this.key, this.label, this.description);

  static DynamicIslandPreset fromString(String? raw) {
    return DynamicIslandPreset.values.firstWhere(
      (p) => p.key == raw,
      orElse: () => DynamicIslandPreset.classicBlack,
    );
  }
}

class AppIconStyle {
  final String key;
  final String label;
  final String androidAlias;
  final Color bgTop;
  final Color bgBottom;
  final Color primary;
  final Color accent;
  final bool hasInnerBox;

  const AppIconStyle({
    required this.key,
    required this.label,
    required this.androidAlias,
    required this.bgTop,
    required this.bgBottom,
    required this.primary,
    required this.accent,
    this.hasInnerBox = false,
  });

  static const List<AppIconStyle> presets = [
    AppIconStyle(
      key: 'bawaan',
      label: 'Bawaan',
      androidAlias: 'com.lunarellys.music.IconBawaan',
      bgTop: Color(0xFF0E1726),
      bgBottom: Color(0xFF070C14),
      primary: Color(0xFFF8FAFC),
      accent: Color(0xFF60A5FA),
    ),
    AppIconStyle(
      key: 'malam',
      label: 'Malam',
      androidAlias: 'com.lunarellys.music.IconMalam',
      bgTop: Color(0xFF08090C),
      bgBottom: Color(0xFF000000),
      primary: Color(0xFFFFFFFF),
      accent: Color(0xFF94A3B8),
    ),
    AppIconStyle(
      key: 'kaca',
      label: 'Kaca',
      androidAlias: 'com.lunarellys.music.IconKaca',
      bgTop: Color(0xFFE6EEF9),
      bgBottom: Color(0xFFC9D9EE),
      primary: Color(0xFF0F172A),
      accent: Color(0xFF2563EB),
      hasInnerBox: true,
    ),
    AppIconStyle(
      key: 'emas',
      label: 'Emas',
      androidAlias: 'com.lunarellys.music.IconEmas',
      bgTop: Color(0xFF2B2212),
      bgBottom: Color(0xFF140F07),
      primary: Color(0xFFFDE68A),
      accent: Color(0xFFF59E0B),
    ),
    AppIconStyle(
      key: 'hutan',
      label: 'Hutan',
      androidAlias: 'com.lunarellys.music.IconHutan',
      bgTop: Color(0xFF0F3D2E),
      bgBottom: Color(0xFF072119),
      primary: Color(0xFFECFDF5),
      accent: Color(0xFF34D399),
    ),
    AppIconStyle(
      key: 'samudra',
      label: 'Samudra',
      androidAlias: 'com.lunarellys.music.IconSamudra',
      bgTop: Color(0xFF0C4A6E),
      bgBottom: Color(0xFF082F49),
      primary: Color(0xFFF0F9FF),
      accent: Color(0xFF38BDF8),
    ),
    AppIconStyle(
      key: 'senja',
      label: 'Senja',
      androidAlias: 'com.lunarellys.music.IconSenja',
      bgTop: Color(0xFFF97316),
      bgBottom: Color(0xFF9D174D),
      primary: Color(0xFFFFF7ED),
      accent: Color(0xFFFDE047),
    ),
    AppIconStyle(
      key: 'piringan',
      label: 'Piringan',
      androidAlias: 'com.lunarellys.music.IconPiringan',
      bgTop: Color(0xFF1E1B2E),
      bgBottom: Color(0xFF110F1B),
      primary: Color(0xFFF1F5F9),
      accent: Color(0xFFA78BFA),
      hasInnerBox: true,
    ),
    AppIconStyle(
      key: 'neon',
      label: 'Neon',
      androidAlias: 'com.lunarellys.music.IconNeon',
      bgTop: Color(0xFF050816),
      bgBottom: Color(0xFF0D1B2A),
      primary: Color(0xFF22D3EE),
      accent: Color(0xFFF472B6),
    ),
    AppIconStyle(
      key: 'gema',
      label: 'Gema',
      androidAlias: 'com.lunarellys.music.IconGema',
      bgTop: Color(0xFF3B0764),
      bgBottom: Color(0xFF1E1B4B),
      primary: Color(0xFFF5F3FF),
      accent: Color(0xFFC084FC),
    ),
    AppIconStyle(
      key: 'bintang',
      label: 'Bintang',
      androidAlias: 'com.lunarellys.music.IconBintang',
      bgTop: Color(0xFF172554),
      bgBottom: Color(0xFF090D16),
      primary: Color(0xFFFEF08A),
      accent: Color(0xFF60A5FA),
    ),
    AppIconStyle(
      key: 'aurora',
      label: 'Aurora',
      androidAlias: 'com.lunarellys.music.IconAurora',
      bgTop: Color(0xFF065F46),
      bgBottom: Color(0xFF312E81),
      primary: Color(0xFFF8FAFC),
      accent: Color(0xFF5EEAD4),
    ),
    AppIconStyle(
      key: 'sakura',
      label: 'Sakura',
      androidAlias: 'com.lunarellys.music.IconSakura',
      bgTop: Color(0xFFFBCFE8),
      bgBottom: Color(0xFFF472B6),
      primary: Color(0xFF500724),
      accent: Color(0xFFFFFFFF),
      hasInnerBox: true,
    ),
    AppIconStyle(
      key: 'mono',
      label: 'Mono',
      androidAlias: 'com.lunarellys.music.IconMono',
      bgTop: Color(0xFFF8FAFC),
      bgBottom: Color(0xFFE2E8F0),
      primary: Color(0xFF0F172A),
      accent: Color(0xFF475569),
    ),
    AppIconStyle(
      key: 'kopi',
      label: 'Kopi',
      androidAlias: 'com.lunarellys.music.IconKopi',
      bgTop: Color(0xFF451A03),
      bgBottom: Color(0xFF271206),
      primary: Color(0xFFFEF3C7),
      accent: Color(0xFFD97706),
    ),
    AppIconStyle(
      key: 'ruby',
      label: 'Ruby',
      androidAlias: 'com.lunarellys.music.IconRuby',
      bgTop: Color(0xFF9F1239),
      bgBottom: Color(0xFF4C0519),
      primary: Color(0xFFFFF1F2),
      accent: Color(0xFFFB7185),
    ),
    AppIconStyle(
      key: 'zamrud',
      label: 'Zamrud',
      androidAlias: 'com.lunarellys.music.IconZamrud',
      bgTop: Color(0xFF047857),
      bgBottom: Color(0xFF022C22),
      primary: Color(0xFFECFDF5),
      accent: Color(0xFF6EE7B7),
    ),
    AppIconStyle(
      key: 'siber',
      label: 'Siber',
      androidAlias: 'com.lunarellys.music.IconSiber',
      bgTop: Color(0xFF111827),
      bgBottom: Color(0xFF030712),
      primary: Color(0xFFA3E635),
      accent: Color(0xFF38BDF8),
    ),
    AppIconStyle(
      key: 'pastel',
      label: 'Pastel',
      androidAlias: 'com.lunarellys.music.IconPastel',
      bgTop: Color(0xFFDDD6FE),
      bgBottom: Color(0xFFBFDBFE),
      primary: Color(0xFF1E293B),
      accent: Color(0xFF6366F1),
      hasInnerBox: true,
    ),
    AppIconStyle(
      key: 'baja',
      label: 'Baja',
      androidAlias: 'com.lunarellys.music.IconBaja',
      bgTop: Color(0xFF475569),
      bgBottom: Color(0xFF1E293B),
      primary: Color(0xFFF8FAFC),
      accent: Color(0xFF94A3B8),
    ),
  ];

  static AppIconStyle byKey(String? key) {
    return presets.firstWhere(
      (e) => e.key == key,
      orElse: () => presets.first,
    );
  }
}

const List<String> kLyricsSources = [
  'Auto Terbaik',
  'Archys Sync',
  'LRCLIB Sync',
  'YouTube Music',
];

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
