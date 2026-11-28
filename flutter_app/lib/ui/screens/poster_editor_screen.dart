import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/music_models.dart';
import '../../services/device_permissions_service.dart';
import '../../state/library_provider.dart';
import '../../state/player_provider.dart';
import '../widgets/artwork_image.dart';
import '../widgets/lunarellys_logo.dart';

class PosterEditorScreen extends ConsumerStatefulWidget {
  final MusicItem? initialTrack;

  const PosterEditorScreen({super.key, this.initialTrack});

  @override
  ConsumerState<PosterEditorScreen> createState() => _PosterEditorScreenState();
}

class _PosterEditorScreenState extends ConsumerState<PosterEditorScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _posterKey = GlobalKey();
  late final AnimationController _animCtrl;

  String _ratio = '9:16';
  int _activeTab = 0; // 0: Foto, 1: Kartu, 2: Gaya kartu, 3: Gaya latar
  String _cardStyle = 'Liquid Glass';
  String _bgStyle = 'Siluet Gelap';
  String _qualityMode = 'HD';
  bool _cutoutSubject = true;
  bool _isAnimating = true;
  bool _saving = false;
  double _darkness = 0.36;
  double _blurAmount = 6.0;
  double _cardGlow = 0.45;
  String? _pickedImagePath;
  int _layoutSeed = 1;
  List<MusicItem> _selectedTracks = [];

  static const _ratios = ['9:16', '4:5', '1:1', '16:9'];
  static const _cardStyles = [
    'Liquid Glass',
    'Gelap OLED',
    'Putih Minimal',
    'Aurora Border',
  ];
  static const _bgStyles = [
    'Siluet Gelap',
    'Buram Sampul',
    'Mesh Gradasi',
    'Polos',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final player = ref.read(playerProvider);
      final library = ref.read(libraryProvider);
      final seen = <String>{};
      final picks = <MusicItem>[];
      void addTrack(MusicItem? item) {
        if (item == null || item.id.isEmpty || picks.length >= 5) return;
        if (seen.add(item.id)) picks.add(item);
      }

      addTrack(widget.initialTrack);
      addTrack(player.currentTrack);
      for (final t in player.queue) {
        addTrack(t);
      }
      for (final t in library.recentlyPlayed) {
        addTrack(t);
      }
      for (final t in library.likedSongs) {
        addTrack(t);
      }
      setState(() => _selectedTracks = picks);
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  double get _aspectValue {
    switch (_ratio) {
      case '1:1':
        return 1.0;
      case '4:5':
        return 0.8;
      case '16:9':
        return 16 / 9;
      case '9:16':
      default:
        return 9 / 16;
    }
  }

  void _randomizeDesign() {
    HapticFeedback.mediumImpact();
    setState(() {
      _layoutSeed = (_layoutSeed + 1) % 1000 + 1;
      _darkness = 0.25 + ((_layoutSeed * 13) % 40) / 100.0;
      _cardGlow = 0.30 + ((_layoutSeed * 19) % 55) / 100.0;
    });
  }

  void _resetAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _ratio = '9:16';
      _cardStyle = 'Liquid Glass';
      _bgStyle = 'Siluet Gelap';
      _qualityMode = 'HD';
      _cutoutSubject = true;
      _darkness = 0.36;
      _blurAmount = 6.0;
      _cardGlow = 0.45;
      _pickedImagePath = null;
      _layoutSeed = 1;
    });
  }

  Future<void> _pickPhoto() async {
    final path = await ref.read(devicePermissionsProvider.notifier).pickMediaImage();
    if (!mounted) return;
    if (path != null && path.isNotEmpty) {
      setState(() {
        _pickedImagePath = path;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada foto yang dipilih atau pemilih tidak tersedia'),
        ),
      );
    }
  }

  Future<File?> _capturePosterPng() async {
    final boundary = _posterKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final pixelRatio = _qualityMode == 'HD' ? 3.0 : 2.2;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/archys_poster_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _savePoster() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final tmp = await _capturePosterPng();
      if (tmp == null) throw Exception('Gagal merender poster');
      final docsDir = await getApplicationDocumentsDirectory();
      final saved = File(
        '${docsDir.path}/archys_poster_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tmp.copy(saved.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Poster $_qualityMode tersimpan (${saved.path.split('/').last})'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan poster: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sharePoster() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final tmp = await _capturePosterPng();
      if (tmp == null) throw Exception('Gagal merender poster');
      await Share.shareXFiles(
        [XFile(tmp.path)],
        text: 'Poster lagu dibuat di ${AppConfig.appName}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membagikan poster: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openTrackPicker() {
    final library = ref.read(libraryProvider);
    final player = ref.read(playerProvider);
    final seen = <String>{};
    final pool = <MusicItem>[];
    for (final item in [
      if (player.currentTrack != null) player.currentTrack!,
      ...player.queue,
      ...library.likedSongs,
      ...library.recentlyPlayed,
      ...library.top50Tracks,
    ]) {
      if (item.id.isNotEmpty && seen.add(item.id)) pool.add(item);
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = AppColors.isDark(context);
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141822) : Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(110),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pilih sampai 5 lagu (${_selectedTracks.length}/5)',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkOf(context),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Selesai'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: pool.isEmpty
                        ? Center(
                            child: Text(
                              'Putar atau sukai beberapa lagu terlebih dahulu',
                              style: TextStyle(
                                color: AppColors.subOf(context),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: pool.length,
                            itemBuilder: (_, i) {
                              final item = pool[i];
                              final selected = _selectedTracks.any(
                                (t) => t.id == item.id,
                              );
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: ArtworkImage(
                                  url: item.bestThumbUrl(size: 120),
                                  size: 42,
                                  radius: 8,
                                  preserveFull: true,
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkOf(context),
                                  ),
                                ),
                                subtitle: Text(
                                  item.artistDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Icon(
                                  selected
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.plus_circle,
                                  color: selected
                                      ? AppColors.iosBlue
                                      : AppColors.subOf(context),
                                ),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (selected) {
                                      _selectedTracks.removeWhere(
                                        (t) => t.id == item.id,
                                      );
                                    } else if (_selectedTracks.length < 5) {
                                      _selectedTracks.add(item);
                                    }
                                  });
                                  setModalState(() {});
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = ref.watch(playerProvider.select((s) => s.dynamicColor)) ??
        AppColors.iosBlue;
    final fg = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final primaryBtnBg = isDark ? Colors.white : const Color(0xFF111316);
    final primaryBtnFg = isDark ? Colors.black : Colors.white;
    final neutralPillBg = isDark ? const Color(0xFF23262C) : const Color(0xFFE7EAF0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111316) : const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            // Top studio bar (matching 78146: solid white Simpan pill + monochrome icons)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(CupertinoIcons.back, color: fg),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Poster lagu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atur ulang',
                    icon: Icon(CupertinoIcons.refresh, color: sub, size: 20),
                    onPressed: _resetAll,
                  ),
                  IconButton(
                    tooltip: 'Bagikan',
                    icon: Icon(CupertinoIcons.share, color: fg, size: 20),
                    onPressed: _sharePoster,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _savePoster,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBtnBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: _saving
                          ? CupertinoActivityIndicator(
                              radius: 8,
                              color: primaryBtnFg,
                            )
                          : Text(
                              'Simpan',
                              style: TextStyle(
                                color: primaryBtnFg,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Preview Stage
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: AspectRatio(
                    aspectRatio: _aspectValue,
                    child: RepaintBoundary(
                      key: _posterKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: _PosterCanvasPreview(
                          animation: _animCtrl,
                          isAnimating: _isAnimating,
                          tracks: _selectedTracks,
                          pickedImagePath: _pickedImagePath,
                          accent: accent,
                          cardStyle: _cardStyle,
                          bgStyle: _bgStyle,
                          cutoutSubject: _cutoutSubject,
                          darkness: _darkness,
                          blurAmount: _blurAmount,
                          cardGlow: _cardGlow,
                          seed: _layoutSeed,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Quick Actions Strip (Ratio, Play/Pause, Acak desain, Clarity — sleek neutral pills)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final idx = _ratios.indexOf(_ratio);
                        setState(() => _ratio = _ratios[(idx + 1) % _ratios.length]);
                      },
                      child: _actionChip(
                        isDark: isDark,
                        icon: CupertinoIcons.rectangle_expand_vertical,
                        label: _ratio == '9:16' ? '9:16 TikTok' : _ratio,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isAnimating = !_isAnimating;
                          if (_isAnimating) {
                            _animCtrl.repeat();
                          } else {
                            _animCtrl.stop();
                          }
                        });
                      },
                      child: _actionChip(
                        isDark: isDark,
                        icon: _isAnimating
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        label: _isAnimating ? '8 dtk' : 'Jeda',
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _randomizeDesign,
                      child: _actionChip(
                        isDark: isDark,
                        icon: CupertinoIcons.shuffle,
                        label: 'Acak desain',
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(
                          () => _qualityMode = _qualityMode == 'HD' ? 'Tajam' : 'HD',
                        );
                      },
                      child: _actionChip(
                        isDark: isDark,
                        icon: CupertinoIcons.wand_stars,
                        label: _qualityMode,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Control Panel (4 Tabs matching 78146 monochrome style)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16181C) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: (isDark ? Colors.white : Colors.black).withAlpha(16),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      for (final entry in const [
                        (0, 'Foto'),
                        (1, 'Kartu'),
                        (2, 'Gaya kartu'),
                        (3, 'Gaya latar'),
                      ])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeTab = entry.$1),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeTab == entry.$1
                                    ? primaryBtnBg
                                    : neutralPillBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                entry.$2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.2,
                                  fontWeight: _activeTab == entry.$1
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: _activeTab == entry.$1 ? primaryBtnFg : fg,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTabBody(isDark, primaryBtnBg, primaryBtnFg, neutralPillBg, fg, sub),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(
    bool isDark,
    Color primaryBtnBg,
    Color primaryBtnFg,
    Color neutralPillBg,
    Color fg,
    Color sub,
  ) {
    if (_activeTab == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    decoration: BoxDecoration(
                      color: neutralPillBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withAlpha(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.photo, size: 17, color: fg),
                        const SizedBox(width: 7),
                        Text(
                          _pickedImagePath != null ? 'Ganti foto' : 'Pilih foto',
                          style: TextStyle(
                            color: fg,
                            fontSize: 13.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: neutralPillBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withAlpha(18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Potong latar',
                      style: TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 6),
                    CupertinoSwitch(
                      value: _cutoutSubject,
                      activeTrackColor: primaryBtnBg,
                      thumbColor: primaryBtnFg,
                      onChanged: (v) => setState(() => _cutoutSubject = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _sliderRow(
            'Gelap',
            _darkness,
            0.0,
            0.85,
            '${(_darkness * 100).round()}%',
            primaryBtnBg,
            fg,
            sub,
            (v) => setState(() => _darkness = v),
          ),
          _sliderRow(
            'Kabur',
            _blurAmount / 24.0,
            0.0,
            1.0,
            '${((_blurAmount / 24.0) * 100).round()}%',
            primaryBtnBg,
            fg,
            sub,
            (v) => setState(() => _blurAmount = v * 24.0),
          ),
          _sliderRow(
            'Cahaya kartu',
            _cardGlow,
            0.0,
            1.0,
            '${(_cardGlow * 100).round()}%',
            primaryBtnBg,
            fg,
            sub,
            (v) => setState(() => _cardGlow = v),
          ),
        ],
      );
    }

    if (_activeTab == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedTracks.length} dari 5 lagu dipilih',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
              GestureDetector(
                onTap: _openTrackPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryBtnBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Pilih lagu',
                    style: TextStyle(
                      color: primaryBtnFg,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 58,
            child: _selectedTracks.isEmpty
                ? Center(
                    child: Text(
                      'Ketuk "Pilih lagu" untuk menambahkan kartu lagu',
                      style: TextStyle(fontSize: 12.5, color: sub),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedTracks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final t = _selectedTracks[i];
                      return Container(
                        width: 158,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: neutralPillBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            ArtworkImage(
                              url: t.bestThumbUrl(size: 100),
                              size: 38,
                              radius: 8,
                              preserveFull: true,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: fg,
                                    ),
                                  ),
                                  Text(
                                    t.artistDisplay,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10.5, color: sub),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _selectedTracks.removeAt(i)),
                              child: Icon(CupertinoIcons.xmark_circle_fill, size: 17, color: sub),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    if (_activeTab == 2) {
      return SizedBox(
        height: 66,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _cardStyles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _cardStyles[i];
            final selected = s == _cardStyle;
            return GestureDetector(
              onTap: () => setState(() => _cardStyle = s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? primaryBtnBg : neutralPillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? primaryBtnFg : fg,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _bgStyles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _bgStyles[i];
          final selected = s == _bgStyle;
          return GestureDetector(
            onTap: () => setState(() => _bgStyle = s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? primaryBtnBg : neutralPillBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? primaryBtnFg : fg,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    String readout,
    Color activeColor,
    Color fg,
    Color sub,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbColor: activeColor,
              activeTrackColor: activeColor,
              inactiveTrackColor: activeColor.withAlpha(42),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            readout,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sub),
          ),
        ),
      ],
    );
  }

  Widget _actionChip({
    required bool isDark,
    required IconData icon,
    required String label,
  }) {
    final bg = isDark ? const Color(0xFF23262C) : Colors.white;
    final fg = AppColors.inkOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withAlpha(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterCanvasPreview extends StatelessWidget {
  final Animation<double> animation;
  final bool isAnimating;
  final List<MusicItem> tracks;
  final String? pickedImagePath;
  final Color accent;
  final String cardStyle;
  final String bgStyle;
  final bool cutoutSubject;
  final double darkness;
  final double blurAmount;
  final double cardGlow;
  final int seed;

  const _PosterCanvasPreview({
    required this.animation,
    required this.isAnimating,
    required this.tracks,
    required this.pickedImagePath,
    required this.accent,
    required this.cardStyle,
    required this.bgStyle,
    required this.cutoutSubject,
    required this.darkness,
    required this.blurAmount,
    required this.cardGlow,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final primaryTrack = tracks.isNotEmpty ? tracks.first : null;
    final hasFile = pickedImagePath != null && File(pickedImagePath!).existsSync();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final phase = isAnimating ? animation.value * 2 * math.pi : 0.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Base (neutral studio dark gradient by default matching 78146)
            if (hasFile)
              Image.file(File(pickedImagePath!), fit: BoxFit.cover)
            else if (primaryTrack != null && bgStyle == 'Buram Sampul')
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: ArtworkImage(
                    url: primaryTrack.bestThumbUrl(size: 800),
                    size: 480,
                    radius: 0,
                  ),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: bgStyle == 'Polos'
                        ? [const Color(0xFF0C0E12), const Color(0xFF060709)]
                        : bgStyle == 'Mesh Gradasi'
                            ? [
                                Color.lerp(const Color(0xFF101926), accent, 0.32)!,
                                const Color(0xFF172231),
                                const Color(0xFF080B10),
                              ]
                            : const [
                                Color(0xFF151C24),
                                Color(0xFF1B242E),
                                Color(0xFF090B0E),
                              ],
                  ),
                ),
              ),

            // 2. Blur & Darkness Veil
            if (blurAmount > 0.5 && (hasFile || bgStyle == 'Buram Sampul'))
              BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: blurAmount,
                  sigmaY: blurAmount,
                ),
                child: const SizedBox.expand(),
              ),
            Container(
              color: Colors.black.withAlpha((darkness * 255).round().clamp(0, 230)),
            ),

            // 3. Studio Spotlight Silhouette Subject Layer when "Potong latar" is active
            if (cutoutSubject)
              CustomPaint(
                painter: _StudioSilhouetteHaloPainter(
                  accent: accent,
                  hasCustomPhoto: hasFile,
                ),
              ),

            // 4. Up to 5 portrait floating Liquid Glass mini-player cards matching 78146
            LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final h = box.maxHeight;
                final count = tracks.length.clamp(0, 5);
                return Stack(
                  children: [
                    for (var i = 0; i < count; i++)
                      _buildFloatingTrackCard(
                        track: tracks[i],
                        index: i,
                        w: w,
                        h: h,
                        phase: phase,
                      ),
                  ],
                );
              },
            ),

            // 5. Minimal Unboxed Archys Watermark at Bottom Center (matching 78146)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArchysHorizonLogo(size: 13, color: Colors.white.withAlpha(230)),
                    const SizedBox(width: 5),
                    Text(
                      AppConfig.appName,
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingTrackCard({
    required MusicItem track,
    required int index,
    required double w,
    required double h,
    required double phase,
  }) {
    // 2-top / 1-center / 2-bottom staggered portrait layout (matching 78146)
    const slots = [
      Offset(0.08, 0.08),
      Offset(0.57, 0.05),
      Offset(0.325, 0.26),
      Offset(0.09, 0.54),
      Offset(0.56, 0.51),
    ];
    const tilts = [-0.11, 0.11, 0.0, -0.07, 0.09];
    final slot = slots[index % slots.length];
    final cardWidth = (w * 0.345).clamp(68.0, 114.0);
    final seedShiftX = (((seed * (index + 3)) % 9) - 4) * 1.2;
    final seedShiftY = (((seed * (index + 5)) % 9) - 4) * 1.2;
    final floatDy = math.sin(phase + index * 1.15) * 4.5;
    final tilt = tilts[index % tilts.length] + ((seed % 3) - 1) * 0.018;

    final bool lightCard = cardStyle == 'Putih Minimal';
    final Color cardBg;
    final Color borderCol;
    switch (cardStyle) {
      case 'Putih Minimal':
        cardBg = Colors.white.withAlpha(232);
        borderCol = Colors.white;
        break;
      case 'Gelap OLED':
        cardBg = const Color(0xFF080A0E).withAlpha(236);
        borderCol = Colors.white.withAlpha(46);
        break;
      case 'Aurora Border':
        cardBg = const Color(0xFF0F172A).withAlpha(200);
        borderCol = const Color(0xFF5EEAD4).withAlpha(200);
        break;
      case 'Liquid Glass':
      default:
        cardBg = const Color(0xFF282E38).withAlpha(165);
        borderCol = Colors.white.withAlpha(96);
        break;
    }

    final textColor = lightCard ? const Color(0xFF0F172A) : Colors.white;
    final subColor = lightCard ? const Color(0xFF475569) : Colors.white70;
    final artSize = (cardWidth - 14).clamp(44.0, 96.0);
    final showSparkleRight = index == 0 || index == 1 || index == 3;

    return Positioned(
      left: (w * slot.dx + seedShiftX).clamp(6.0, math.max(6.0, w - cardWidth - 6.0)),
      top: (h * slot.dy + seedShiftY + floatDy).clamp(6.0, math.max(6.0, h - cardWidth * 1.45)),
      child: Transform.rotate(
        angle: tilt,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: cardWidth,
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: borderCol, width: 1.0),
                boxShadow: [
                  if (cardGlow > 0.04)
                    BoxShadow(
                      color: Colors.white.withAlpha((cardGlow * 70).round().clamp(0, 90)),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  BoxShadow(
                    color: Colors.black.withAlpha(110),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Micro mini-player header bar
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 2,
                        decoration: BoxDecoration(
                          color: subColor.withAlpha(110),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        CupertinoIcons.ellipsis,
                        size: 8,
                        color: subColor.withAlpha(160),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ArtworkImage(
                    url: track.bestThumbUrl(size: 200),
                    size: artSize,
                    radius: 7,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 8.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                  Text(
                    track.artistDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 6.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Micro progress line
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        value: 0.42 + (index * 0.11) % 0.4,
                        backgroundColor: subColor.withAlpha(46),
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.backward_fill, size: 7, color: textColor),
                      const SizedBox(width: 8),
                      Icon(CupertinoIcons.pause_fill, size: 8, color: textColor),
                      const SizedBox(width: 8),
                      Icon(CupertinoIcons.forward_fill, size: 7, color: textColor),
                    ],
                  ),
                ],
              ),
            ),
            if (cardGlow > 0.05)
              Positioned(
                top: -8,
                right: showSparkleRight ? -7 : null,
                left: showSparkleRight ? null : -7,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(18, 18),
                    painter: _SparkleStarPainter(
                      opacity: (0.45 + cardGlow * 0.55).clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SparkleStarPainter extends CustomPainter {
  final double opacity;
  const _SparkleStarPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.48;
    final ir = size.width * 0.11;
    final path = Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + ir * 0.5, cy - ir * 0.5, cx + r, cy)
      ..quadraticBezierTo(cx + ir * 0.5, cy + ir * 0.5, cx, cy + r)
      ..quadraticBezierTo(cx - ir * 0.5, cy + ir * 0.5, cx - r, cy)
      ..quadraticBezierTo(cx - ir * 0.5, cy - ir * 0.5, cx, cy - r)
      ..close();

    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.72,
      Paint()
        ..color = Colors.white.withAlpha((opacity * 120).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withAlpha((opacity * 255).round()),
    );
  }

  @override
  bool shouldRepaint(covariant _SparkleStarPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class _StudioSilhouetteHaloPainter extends CustomPainter {
  final Color accent;
  final bool hasCustomPhoto;

  const _StudioSilhouetteHaloPainter({
    required this.accent,
    required this.hasCustomPhoto,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.56;
    // Ambient studio backlight behind subject
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.44,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withAlpha(hasCustomPhoto ? 65 : 95),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.44),
        ),
    );

    if (!hasCustomPhoto) {
      // Crisp studio acoustic silhouette backdrop when user hasn't picked a photo yet
      final silPaint = Paint()
        ..color = Colors.black.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final headR = size.width * 0.14;
      canvas.drawCircle(Offset(cx, size.height * 0.36), headR, silPaint);
      final body = Path()
        ..moveTo(cx - size.width * 0.29, size.height)
        ..quadraticBezierTo(
          cx - size.width * 0.25,
          size.height * 0.52,
          cx,
          size.height * 0.50,
        )
        ..quadraticBezierTo(
          cx + size.width * 0.25,
          size.height * 0.52,
          cx + size.width * 0.29,
          size.height,
        )
        ..close();
      canvas.drawPath(body, silPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StudioSilhouetteHaloPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.hasCustomPhoto != hasCustomPhoto;
}
