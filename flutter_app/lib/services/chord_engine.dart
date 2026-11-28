import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../models/music_models.dart';
import '../state/settings_provider.dart';

enum ChordMode {
  easy('easy', 'Versi mudah'),
  keyC('key_c', 'Kunci C'),
  original('original', 'Asli');

  final String key;
  final String label;
  const ChordMode(this.key, this.label);

  static ChordMode fromString(String? raw) {
    return ChordMode.values.firstWhere(
      (e) => e.key == raw,
      orElse: () => ChordMode.easy,
    );
  }
}

class ChordPlacement {
  final int wordIndex;
  final String displayChord;
  final String baseChord;

  const ChordPlacement({
    required this.wordIndex,
    required this.displayChord,
    required this.baseChord,
  });
}

class TrackChordAnalysis {
  final String baseKey;
  final int capo;
  final int transpose;
  final ChordMode mode;
  final List<String> progression;
  final List<List<ChordPlacement>> lineChords;

  const TrackChordAnalysis({
    required this.baseKey,
    required this.capo,
    required this.transpose,
    required this.mode,
    required this.progression,
    required this.lineChords,
  });

  String get summaryLabel {
    final parts = <String>[mode.label];
    if (capo > 0 && mode == ChordMode.easy) {
      parts.add('Capo $capo');
    } else if (transpose != 0) {
      parts.add('Transpos ${transpose > 0 ? '+$transpose' : '$transpose'}');
    }
    parts.add('Kunci dasar $baseKey');
    return parts.join(' · ');
  }
}

class GuitarChordShape {
  final String name;
  /// 6 strings low E (index 0) to high e (index 5): -1 = muted (X), 0 = open (O), >0 = fret
  final List<int> frets;
  final int baseFret;

  const GuitarChordShape({
    required this.name,
    required this.frets,
    this.baseFret = 1,
  });
}

class ChordEngine {
  static const List<String> _chromaticSharp = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static const Map<String, int> _noteToSemitone = {
    'C': 0,
    'B#': 0,
    'C#': 1,
    'DB': 1,
    'D': 2,
    'D#': 3,
    'EB': 3,
    'E': 4,
    'FB': 4,
    'F': 5,
    'E#': 5,
    'F#': 6,
    'GB': 6,
    'G': 7,
    'G#': 8,
    'AB': 8,
    'A': 9,
    'A#': 10,
    'BB': 10,
    'B': 11,
    'CB': 11,
  };

  static const List<({String baseKey, int recCapo, List<String> chords})>
      _progressionTemplates = [
    (baseKey: 'Fm', recCapo: 1, chords: ['D7', 'G/B', 'Em', 'Cmaj7']),
    (baseKey: 'F', recCapo: 5, chords: ['C', 'G/B', 'Am', 'Fmaj7']),
    (baseKey: 'Ab', recCapo: 1, chords: ['G', 'D/F#', 'Em', 'C']),
    (baseKey: 'G', recCapo: 0, chords: ['G', 'D', 'Em', 'C']),
    (baseKey: 'Bb', recCapo: 3, chords: ['G', 'D', 'Em', 'C']),
    (baseKey: 'Eb', recCapo: 1, chords: ['D', 'A', 'Bm', 'G']),
    (baseKey: 'Db', recCapo: 1, chords: ['C', 'G', 'Am', 'F']),
    (baseKey: 'Em', recCapo: 0, chords: ['Em', 'C', 'G', 'D']),
    (baseKey: 'Am', recCapo: 0, chords: ['Am', 'F', 'C', 'G']),
  ];

  static const List<String> _keyCProgression = ['C', 'G/B', 'Am', 'Fmaj7'];

  static const Map<String, GuitarChordShape> _shapes = {
    'C': GuitarChordShape(name: 'C', frets: [-1, 3, 2, 0, 1, 0]),
    'Cmaj7': GuitarChordShape(name: 'Cmaj7', frets: [-1, 3, 2, 0, 0, 0]),
    'C#': GuitarChordShape(name: 'C#', frets: [-1, 4, 6, 6, 6, 4], baseFret: 4),
    'Cm': GuitarChordShape(name: 'Cm', frets: [-1, 3, 5, 5, 4, 3], baseFret: 3),
    'D': GuitarChordShape(name: 'D', frets: [-1, -1, 0, 2, 3, 2]),
    'Dm': GuitarChordShape(name: 'Dm', frets: [-1, -1, 0, 2, 3, 1]),
    'D7': GuitarChordShape(name: 'D7', frets: [-1, -1, 0, 2, 1, 2]),
    'D/F#': GuitarChordShape(name: 'D/F#', frets: [2, 0, 0, 2, 3, 2]),
    'D#': GuitarChordShape(name: 'D#', frets: [-1, -1, 1, 3, 4, 3]),
    'E': GuitarChordShape(name: 'E', frets: [0, 2, 2, 1, 0, 0]),
    'Em': GuitarChordShape(name: 'Em', frets: [0, 2, 2, 0, 0, 0]),
    'E7': GuitarChordShape(name: 'E7', frets: [0, 2, 0, 1, 0, 0]),
    'F': GuitarChordShape(name: 'F', frets: [1, 3, 3, 2, 1, 1]),
    'Fm': GuitarChordShape(name: 'Fm', frets: [1, 3, 3, 1, 1, 1]),
    'Fmaj7': GuitarChordShape(name: 'Fmaj7', frets: [-1, -1, 3, 2, 1, 0]),
    'F#': GuitarChordShape(name: 'F#', frets: [2, 4, 4, 3, 2, 2], baseFret: 2),
    'F#m': GuitarChordShape(name: 'F#m', frets: [2, 4, 4, 2, 2, 2], baseFret: 2),
    'G': GuitarChordShape(name: 'G', frets: [3, 2, 0, 0, 0, 3]),
    'Gm': GuitarChordShape(name: 'Gm', frets: [3, 5, 5, 3, 3, 3], baseFret: 3),
    'G7': GuitarChordShape(name: 'G7', frets: [3, 2, 0, 0, 0, 1]),
    'G/B': GuitarChordShape(name: 'G/B', frets: [-1, 2, 0, 0, 3, 3]),
    'Gsus4': GuitarChordShape(name: 'Gsus4', frets: [3, 2, 0, 0, 1, 3]),
    'G#': GuitarChordShape(name: 'G#', frets: [4, 6, 6, 5, 4, 4], baseFret: 4),
    'G#m': GuitarChordShape(name: 'G#m', frets: [4, 6, 6, 4, 4, 4], baseFret: 4),
    'A': GuitarChordShape(name: 'A', frets: [-1, 0, 2, 2, 2, 0]),
    'Am': GuitarChordShape(name: 'Am', frets: [-1, 0, 2, 2, 1, 0]),
    'A7': GuitarChordShape(name: 'A7', frets: [-1, 0, 2, 0, 2, 0]),
    'A#': GuitarChordShape(name: 'A#', frets: [-1, 1, 3, 3, 3, 1]),
    'B': GuitarChordShape(name: 'B', frets: [-1, 2, 4, 4, 4, 2], baseFret: 2),
    'Bm': GuitarChordShape(name: 'Bm', frets: [-1, 2, 4, 4, 3, 2], baseFret: 2),
  };

  static int _stableHash(String input) {
    var h = 2166136261;
    for (var i = 0; i < input.length; i++) {
      h ^= input.codeUnitAt(i);
      h = (h * 16777619) & 0x7fffffff;
    }
    return h;
  }

  static String transposeChord(String chord, int semitones) {
    if (semitones == 0) return chord;
    final slashParts = chord.split('/');
    final mainTransposed = _transposeSingle(slashParts[0], semitones);
    if (slashParts.length == 2) {
      final bassTransposed = _transposeSingle(slashParts[1], semitones);
      return '$mainTransposed/$bassTransposed';
    }
    return mainTransposed;
  }

  static String _transposeSingle(String token, int semitones) {
    final clean = token.trim();
    if (clean.isEmpty) return token;
    String root;
    String suffix;
    if (clean.length >= 2 && (clean[1] == '#' || clean[1] == 'b')) {
      root = clean.substring(0, 2);
      suffix = clean.substring(2);
    } else {
      root = clean.substring(0, 1);
      suffix = clean.substring(1);
    }
    final semi = _noteToSemitone[root.toUpperCase()];
    if (semi == null) return token;
    final target = ((semi + semitones) % 12 + 12) % 12;
    return '${_chromaticSharp[target]}$suffix';
  }

  static GuitarChordShape shapeForChord(String chord) {
    final exact = _shapes[chord];
    if (exact != null) return exact;
    final noSlash = chord.split('/').first;
    if (_shapes.containsKey(noSlash)) {
      return GuitarChordShape(name: chord, frets: _shapes[noSlash]!.frets, baseFret: _shapes[noSlash]!.baseFret);
    }
    // Strip extensions (maj7/7/sus4) back to root or minor triad
    final isMinor = noSlash.contains('m') && !noSlash.contains('maj');
    final root = noSlash.length >= 2 && (noSlash[1] == '#' || noSlash[1] == 'b')
        ? noSlash.substring(0, 2)
        : noSlash.substring(0, 1);
    final normRoot = _transposeSingle(root, 0);
    final triad = isMinor ? '${normRoot}m' : normRoot;
    final found = _shapes[triad];
    if (found != null) {
      return GuitarChordShape(name: chord, frets: found.frets, baseFret: found.baseFret);
    }
    return const GuitarChordShape(name: 'C', frets: [-1, 3, 2, 0, 1, 0]);
  }

  static TrackChordAnalysis analyzeTrack(
    MusicItem? track,
    List<LyricLine> lines, {
    required ChordMode mode,
    required int transpose,
    required int capo,
  }) {
    final seed = _stableHash('${track?.id ?? ''}|${track?.title ?? ''}|${track?.artistDisplay ?? ''}');
    final tpl = _progressionTemplates[seed % _progressionTemplates.length];
    final effectiveCapo = mode == ChordMode.easy
        ? (capo > 0 ? capo : tpl.recCapo)
        : (mode == ChordMode.original ? 0 : capo);

    final baseProg = mode == ChordMode.keyC ? _keyCProgression : tpl.chords;

    // Shift sounded chords by transpose and subtract capo for open guitar shapes
    final shift = mode == ChordMode.original
        ? transpose + tpl.recCapo
        : transpose - (mode == ChordMode.easy ? (effectiveCapo - tpl.recCapo) : 0);

    final activeProg = baseProg
        .map((c) => transposeChord(c, shift))
        .toList(growable: false);

    final lineChords = <List<ChordPlacement>>[];
    for (var idx = 0; idx < lines.length; idx++) {
      final text = lines[idx].text.trim();
      if (text.isEmpty || text == '•••') {
        lineChords.add(const []);
        continue;
      }
      final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) {
        lineChords.add(const []);
        continue;
      }

      final c1 = activeProg[(idx * 2) % activeProg.length];
      final c2 = activeProg[(idx * 2 + 1) % activeProg.length];
      final placements = <ChordPlacement>[
        ChordPlacement(
          wordIndex: 0,
          displayChord: c1,
          baseChord: c1,
        ),
      ];
      if (words.length >= 4) {
        placements.add(
          ChordPlacement(
            wordIndex: (words.length * 0.52).floor().clamp(1, words.length - 1),
            displayChord: c2,
            baseChord: c2,
          ),
        );
      }
      if (words.length >= 9) {
        final c3 = activeProg[(idx * 2 + 2) % activeProg.length];
        placements.add(
          ChordPlacement(
            wordIndex: (words.length * 0.82).floor().clamp(2, words.length - 1),
            displayChord: c3,
            baseChord: c3,
          ),
        );
      }
      lineChords.add(placements);
    }

    return TrackChordAnalysis(
      baseKey: tpl.baseKey,
      capo: effectiveCapo,
      transpose: transpose,
      mode: mode,
      progression: activeProg,
      lineChords: lineChords,
    );
  }
}

void showGuitarChordDiagramDialog(
  BuildContext context, {
  required String chordName,
  required Color accentColor,
}) {
  final shape = ChordEngine.shapeForChord(chordName);
  final isDark = AppColors.isDark(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141822) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withAlpha(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(110),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Diagram Kunci $chordName',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.inkOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              shape.baseFret > 1
                  ? 'Mulai dari Fret ${shape.baseFret}'
                  : 'Posisi Open / Standar (EADGBE)',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.subOf(context),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 210,
              height: 175,
              child: CustomPaint(
                painter: GuitarChordFretboardPainter(
                  shape: shape,
                  accentColor: accentColor,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: accentColor,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void showChordSettingsSheet(
  BuildContext context,
  WidgetRef ref, {
  required Color accentColor,
  required List<String> progression,
  String? baseKey,
}) {
  final isDark = AppColors.isDark(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Consumer(
        builder: (context, innerRef, _) {
          final settings = innerRef.watch(settingsProvider);
          final sNotifier = innerRef.read(settingsProvider.notifier);
          final mode = ChordMode.fromString(settings.chordMode);

          return Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141822) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withAlpha(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(CupertinoIcons.guitars, color: accentColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengaturan Chord Gitar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkOf(context),
                            ),
                          ),
                          if (baseKey != null && baseKey.isNotEmpty)
                            Text(
                              'Kunci dasar: $baseKey',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.subOf(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: settings.chordsEnabled,
                      activeTrackColor: accentColor,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        sNotifier.setChordsEnabled(v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Mode Kunci',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.subOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ChordMode.values.map((m) {
                    final selected = m == mode;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            sNotifier.setChordMode(m.key);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? accentColor
                                  : (isDark
                                      ? Colors.white.withAlpha(14)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              m.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppColors.inkOf(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StepperControlTile(
                        label: 'Transpos',
                        valueLabel: settings.chordTranspose > 0
                            ? '+${settings.chordTranspose}'
                            : '${settings.chordTranspose}',
                        accent: accentColor,
                        isDark: isDark,
                        onMinus: () => sNotifier.setChordTranspose(
                          settings.chordTranspose - 1,
                        ),
                        onPlus: () => sNotifier.setChordTranspose(
                          settings.chordTranspose + 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StepperControlTile(
                        label: 'Capo',
                        valueLabel: settings.chordCapo == 0
                            ? 'Mati'
                            : 'Fret ${settings.chordCapo}',
                        accent: accentColor,
                        isDark: isDark,
                        onMinus: () => sNotifier.setChordCapo(
                          settings.chordCapo - 1,
                        ),
                        onPlus: () => sNotifier.setChordCapo(
                          settings.chordCapo + 1,
                        ),
                      ),
                    ),
                  ],
                ),
                if (progression.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Diagram Kunci Lagu Ini (Ketuk untuk detail)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.subOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: progression.map((chord) {
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          showGuitarChordDiagramDialog(
                            context,
                            chordName: chord,
                            accentColor: accentColor,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(32),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentColor.withAlpha(90)),
                          ),
                          child: Text(
                            chord,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkOf(context),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _StepperControlTile extends StatelessWidget {
  final String label;
  final String valueLabel;
  final Color accent;
  final bool isDark;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _StepperControlTile({
    required this.label,
    required this.valueLabel,
    required this.accent,
    required this.isDark,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.subOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleStepBtn(CupertinoIcons.minus, onMinus, isDark),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkOf(context),
                ),
              ),
              _circleStepBtn(CupertinoIcons.plus, onPlus, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleStepBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withAlpha(22) : Colors.white,
        ),
        child: Icon(icon, size: 15, color: isDark ? Colors.white : Colors.black),
      ),
    );
  }
}

class GuitarChordFretboardPainter extends CustomPainter {
  final GuitarChordShape shape;
  final Color accentColor;
  final bool isDark;

  const GuitarChordFretboardPainter({
    required this.shape,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strings = 6;
    const frets = 5;
    const leftPad = 24.0;
    const rightPad = 14.0;
    const topPad = 26.0;
    const bottomPad = 22.0;

    final boardW = size.width - leftPad - rightPad;
    final boardH = size.height - topPad - bottomPad;
    final stringGap = boardW / (strings - 1);
    final fretGap = boardH / frets;

    final gridColor = (isDark ? Colors.white : Colors.black).withAlpha(115);
    final nutPaint = Paint()
      ..color = isDark ? Colors.white : const Color(0xFF0F172A)
      ..strokeWidth = shape.baseFret == 1 ? 4.2 : 1.5;
    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.3;

    // Draw top nut & fret horizontal lines
    canvas.drawLine(
      const Offset(leftPad, topPad),
      Offset(leftPad + boardW, topPad),
      nutPaint,
    );
    for (var f = 1; f <= frets; f++) {
      final y = topPad + f * fretGap;
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + boardW, y), linePaint);
    }

    // Draw 6 vertical strings
    for (var s = 0; s < strings; s++) {
      final x = leftPad + s * stringGap;
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + boardH),
        Paint()
          ..color = gridColor
          ..strokeWidth = 1.6 - s * 0.14,
      );
    }

    // Draw fret number label if baseFret > 1
    if (shape.baseFret > 1) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${shape.baseFret}fr',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, topPad + fretGap * 0.28));
    }

    // Draw finger dots + X / O indicators above nut
    final dotPaint = Paint()..color = accentColor;
    final labels = ['E', 'A', 'D', 'G', 'B', 'e'];
    for (var s = 0; s < strings; s++) {
      final x = leftPad + s * stringGap;
      final fret = shape.frets[s];
      if (fret < 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '×',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, topPad - 21));
      } else if (fret == 0) {
        canvas.drawCircle(
          Offset(x, topPad - 12),
          4.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = accentColor,
        );
      } else {
        final relFret = (fret - shape.baseFret + 1).clamp(1, frets);
        final y = topPad + (relFret - 0.5) * fretGap;
        canvas.drawCircle(Offset(x, y), 7.8, dotPaint);
        canvas.drawCircle(
          Offset(x, y),
          7.8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Colors.white.withAlpha(180),
        );
      }

      final stp = TextPainter(
        text: TextSpan(
          text: labels[s],
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      stp.paint(canvas, Offset(x - stp.width / 2, topPad + boardH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant GuitarChordFretboardPainter oldDelegate) =>
      oldDelegate.shape.name != shape.name ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isDark != isDark;
}
