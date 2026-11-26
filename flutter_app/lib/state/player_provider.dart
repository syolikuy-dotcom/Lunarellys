import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:palette_generator/palette_generator.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../models/music_models.dart';
import 'library_provider.dart';
import 'settings_provider.dart';

enum RepeatSetting { off, all, one }

class PlayerState {
  final MusicItem? currentTrack;
  final List<MusicItem> queue;
  final int currentIndex;
  final String playingContext;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final bool shuffle;
  final RepeatSetting repeat;
  final Color? dynamicColor;
  final LyricsResult? lyrics;
  final bool loadingLyrics;
  final MusicSongDetail? songDetail;
  final String? errorMessage;
  final Duration? sleepTimerRemaining;
  final double playbackSpeed;
  final double pitch;
  final double volume;
  final SoundStylePreset soundStyle;
  final bool queueLocked;
  final bool isLoadingRadio;
  final bool stopAfterCurrentTrack;

  const PlayerState({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = -1,
    this.playingContext = 'Antrean',
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.shuffle = false,
    this.repeat = RepeatSetting.off,
    this.dynamicColor,
    this.lyrics,
    this.loadingLyrics = false,
    this.songDetail,
    this.errorMessage,
    this.sleepTimerRemaining,
    this.playbackSpeed = 1.0,
    this.pitch = 1.0,
    this.volume = 0.85,
    this.soundStyle = SoundStylePreset.normal,
    this.queueLocked = false,
    this.isLoadingRadio = false,
    this.stopAfterCurrentTrack = false,
  });

  bool get hasNext =>
      queue.isNotEmpty &&
      (repeat == RepeatSetting.all || currentIndex + 1 < queue.length || shuffle);

  bool get hasPrevious => queue.isNotEmpty;

  PlayerState copyWith({
    MusicItem? currentTrack,
    List<MusicItem>? queue,
    int? currentIndex,
    String? playingContext,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    bool? shuffle,
    RepeatSetting? repeat,
    Color? dynamicColor,
    bool clearDynamicColor = false,
    LyricsResult? lyrics,
    bool clearLyrics = false,
    bool? loadingLyrics,
    MusicSongDetail? songDetail,
    bool clearSongDetail = false,
    String? errorMessage,
    bool clearError = false,
    Duration? sleepTimerRemaining,
    bool clearSleepTimer = false,
    double? playbackSpeed,
    double? pitch,
    double? volume,
    SoundStylePreset? soundStyle,
    bool? queueLocked,
    bool? isLoadingRadio,
    bool? stopAfterCurrentTrack,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playingContext: playingContext ?? this.playingContext,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      dynamicColor: clearDynamicColor ? null : (dynamicColor ?? this.dynamicColor),
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      loadingLyrics: loadingLyrics ?? this.loadingLyrics,
      songDetail: clearSongDetail ? null : (songDetail ?? this.songDetail),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sleepTimerRemaining:
          clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      soundStyle: soundStyle ?? this.soundStyle,
      queueLocked: queueLocked ?? this.queueLocked,
      isLoadingRadio: isLoadingRadio ?? this.isLoadingRadio,
      stopAfterCurrentTrack: stopAfterCurrentTrack ?? this.stopAfterCurrentTrack,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _sleepTimer;
  final Random _rng = Random();
  int _consecutiveErrors = 0;

  PlayerNotifier(this._ref) : super(const PlayerState()) {
    _restorePersistedQueue();
    _initAudio();
  }

  void _restorePersistedQueue() {
    try {
      final settings = _ref.read(settingsProvider);
      if (!settings.persistentQueue) return;
      final prefs = _ref.read(sharedPreferencesProvider);
      final raw = prefs.getString('persisted_queue_v1');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final rawQueue = decoded['queue'];
      if (rawQueue is! List) return;
      final queue = rawQueue
          .whereType<Map<String, dynamic>>()
          .map(MusicItem.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList();
      if (queue.isEmpty) return;
      final idx = ((decoded['currentIndex'] as num?)?.toInt() ?? 0).clamp(0, queue.length - 1);
      final track = queue[idx];
      final fallbackDur = track.durationSeconds != null
          ? Duration(seconds: track.durationSeconds!)
          : Duration.zero;
      final ctx = (decoded['playingContext'] ?? 'Antrean').toString();
      final speed = ((decoded['playbackSpeed'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0);
      final pitch = ((decoded['pitch'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 1.5);
      final vol = ((decoded['volume'] as num?)?.toDouble() ?? 0.85).clamp(0.0, 1.0);
      final style = SoundStylePreset.fromString(decoded['soundStyle']?.toString());
      final locked = decoded['queueLocked'] == true;
      state = state.copyWith(
        currentTrack: track,
        queue: queue,
        currentIndex: idx,
        playingContext: ctx,
        duration: fallbackDur,
        playbackSpeed: speed,
        pitch: pitch,
        volume: vol,
        soundStyle: style,
        queueLocked: locked,
      );
      unawaited(_player.setVolume(vol).catchError((_) {}));
      unawaited(_extractDynamicColor(track));
    } catch (_) {}
  }

  void _persistQueueState() {
    try {
      if (!_ref.read(settingsProvider).persistentQueue) return;
      final prefs = _ref.read(sharedPreferencesProvider);
      if (state.queue.isEmpty) {
        prefs.remove('persisted_queue_v1');
        return;
      }
      final payload = jsonEncode({
        'queue': state.queue.take(60).map((e) => e.toJson()).toList(),
        'currentIndex': state.currentIndex.clamp(0, min(59, state.queue.length - 1)),
        'playingContext': state.playingContext,
        'playbackSpeed': state.playbackSpeed,
        'pitch': state.pitch,
        'volume': state.volume,
        'soundStyle': state.soundStyle.key,
        'queueLocked': state.queueLocked,
      });
      prefs.setString('persisted_queue_v1', payload);
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _subs.add(session.becomingNoisyEventStream.listen((_) {
        _player.pause();
      }));
    } catch (_) {}

    _subs.add(_player.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    }));

    _subs.add(_player.processingStateStream.listen((proc) {
      final buffering = proc == ProcessingState.loading || proc == ProcessingState.buffering;
      state = state.copyWith(isBuffering: buffering);
      if (proc == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    }));

    _subs.add(_player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    }));

    _subs.add(_player.bufferedPositionStream.listen((buf) {
      state = state.copyWith(bufferedPosition: buf);
    }));

    _subs.add(_player.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    }));
  }

  Future<void> playTrack(
    MusicItem track, {
    List<MusicItem>? queue,
    String? contextName,
  }) async {
    if (track.id.isEmpty) return;

    List<MusicItem> nextQueue = List<MusicItem>.from(state.queue);
    int nextIndex = state.currentIndex;

    if (queue != null && queue.isNotEmpty) {
      nextQueue = queue.where((t) => t.id.isNotEmpty).toList();
      nextIndex = nextQueue.indexWhere((t) => t.id == track.id);
      if (nextIndex == -1) {
        nextQueue.insert(0, track);
        nextIndex = 0;
      }
    } else {
      final existingIdx = nextQueue.indexWhere((t) => t.id == track.id);
      if (existingIdx != -1) {
        nextIndex = existingIdx;
      } else {
        nextQueue.insert(0, track);
        nextIndex = 0;
      }
    }

    await _startTrackAt(
      track,
      nextQueue,
      nextIndex,
      contextName: contextName ?? track.album?.name ?? state.playingContext,
    );
  }

  Future<void> _startTrackAt(
    MusicItem track,
    List<MusicItem> queue,
    int index, {
    String? contextName,
  }) async {
    final fallbackDuration = track.durationSeconds != null
        ? Duration(seconds: track.durationSeconds!)
        : Duration.zero;

    state = state.copyWith(
      currentTrack: track,
      queue: queue,
      currentIndex: index,
      playingContext: contextName ?? track.album?.name ?? 'Mix ${track.title}',
      position: Duration.zero,
      duration: fallbackDuration,
      isBuffering: true,
      clearLyrics: true,
      loadingLyrics: true,
      clearSongDetail: true,
      clearError: true,
    );
    _persistQueueState();

    unawaited(_ref.read(libraryProvider.notifier).recordPlay(track));
    unawaited(_extractDynamicColor(track));
    unawaited(_fetchLyrics(track));
    unawaited(_fetchSongDetail(track));

    final settings = _ref.read(settingsProvider);
    final api = _ref.read(apiClientProvider);

    try {
      final offline = _ref.read(libraryProvider).getDownloadedTrack(track.id);
      final thumbUrl = track.bestThumbUrl(size: 500);
      final mediaItem = MediaItem(
        id: track.id,
        album: track.album?.name ?? 'Lunarellys',
        title: track.title,
        artist: track.artistDisplay,
        duration: fallbackDuration > Duration.zero ? fallbackDuration : null,
        artUri: thumbUrl != null ? Uri.tryParse(thumbUrl) : null,
      );

      AudioSource source;
      if (offline?.localAudioPath != null && await File(offline!.localAudioPath!).exists()) {
        source = AudioSource.file(offline.localAudioPath!, tag: mediaItem);
      } else {
        final streamUrl = api.buildStreamUrl(track.id, quality: settings.audioQuality);
        source = AudioSource.uri(
          Uri.parse(streamUrl),
          headers: api.authHeaders,
          tag: mediaItem,
        );
      }

      await _player.setAudioSource(source);
      await _player.setVolume(state.volume).catchError((_) {});
      if (state.playbackSpeed != 1.0) {
        await _player.setSpeed(state.playbackSpeed).catchError((_) {});
      }
      if (state.pitch != 1.0) {
        await _player.setPitch(state.pitch).catchError((_) {});
      }
      await _player.play();
      _consecutiveErrors = 0;
    } catch (_) {
      _consecutiveErrors += 1;
      if (settings.autoSkipOnError && queue.length > 1 && _consecutiveErrors < 2) {
        state = state.copyWith(
          isBuffering: false,
          isPlaying: false,
          errorMessage: 'Lagu tidak tersedia — melompat ke berikutnya...',
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await skipNext();
        return;
      }
      state = state.copyWith(
        isBuffering: false,
        isPlaying: false,
        errorMessage: 'Tidak dapat memutar lagu ini sekarang. Coba lagu lain.',
      );
    }

    if (settings.autoRadio && queue.length <= index + 1) {
      unawaited(_appendRadioTracks(track.id));
    }
  }

  Future<void> _extractDynamicColor(MusicItem track) async {
    if (!_ref.read(settingsProvider).dynamicAlbumColors) {
      state = state.copyWith(clearDynamicColor: true);
      return;
    }
    final url = track.bestThumbUrl(size: 300);
    if (url == null) {
      state = state.copyWith(clearDynamicColor: true);
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url),
        maximumColorCount: 8,
      );
      if (state.currentTrack?.id != track.id) return;
      final picked = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color;
      if (picked != null) {
        final hsl = HSLColor.fromColor(picked);
        final balanced = hsl
            .withSaturation(hsl.saturation.clamp(0.28, 0.72))
            .withLightness(hsl.lightness.clamp(0.38, 0.58))
            .toColor();
        state = state.copyWith(dynamicColor: balanced);
      } else {
        state = state.copyWith(clearDynamicColor: true);
      }
    } catch (_) {
      if (state.currentTrack?.id == track.id) {
        state = state.copyWith(dynamicColor: AppColors.horizonBlue);
      }
    }
  }

  Future<void> _fetchLyrics(MusicItem track) async {
    try {
      final res = await _ref.read(apiClientProvider).getLyrics(
            track.id,
            title: track.title,
            artist: track.artistDisplay,
            durationSeconds: track.durationSeconds,
          );
      if (state.currentTrack?.id != track.id) return;
      state = state.copyWith(lyrics: res, loadingLyrics: false);
    } catch (_) {
      if (state.currentTrack?.id == track.id) {
        state = state.copyWith(loadingLyrics: false);
      }
    }
  }

  Future<void> refreshLyrics() async {
    final track = state.currentTrack;
    if (track == null) return;
    state = state.copyWith(loadingLyrics: true, clearLyrics: true);
    await _fetchLyrics(track);
  }

  Future<void> _fetchSongDetail(MusicItem track) async {
    try {
      final detail = await _ref.read(apiClientProvider).getSongDetail(track.id);
      if (state.currentTrack?.id != track.id) return;
      state = state.copyWith(songDetail: detail);
    } catch (_) {}
  }

  Future<void> _appendRadioTracks(String seedId) async {
    try {
      final radio = await _ref.read(apiClientProvider).getRadioQueue(seedId);
      if (state.currentTrack?.id != seedId || radio.isEmpty) return;
      final existing = state.queue.map((e) => e.id).toSet();
      final additions = radio.where((t) => !existing.contains(t.id)).toList();
      if (additions.isNotEmpty) {
        state = state.copyWith(queue: [...state.queue, ...additions]);
        _persistQueueState();
      }
    } catch (_) {}
  }

  Future<void> _handleTrackCompleted() async {
    if (state.stopAfterCurrentTrack) {
      await _player.pause();
      await _player.seek(Duration.zero);
      state = state.copyWith(stopAfterCurrentTrack: false, clearSleepTimer: true);
      return;
    }
    if (state.repeat == RepeatSetting.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    await skipNext();
  }

  Future<void> togglePlayPause() async {
    final track = state.currentTrack;
    if (track == null) return;
    if (_player.processingState == ProcessingState.idle && !_player.playing) {
      await _startTrackAt(
        track,
        state.queue,
        state.currentIndex.clamp(0, state.queue.length - 1),
        contextName: state.playingContext,
      );
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> skipNext() async {
    if (state.queue.isEmpty) return;
    int nextIdx;
    if (state.shuffle && state.queue.length > 1) {
      do {
        nextIdx = _rng.nextInt(state.queue.length);
      } while (nextIdx == state.currentIndex);
    } else {
      nextIdx = state.currentIndex + 1;
      if (nextIdx >= state.queue.length) {
        if (state.repeat == RepeatSetting.all) {
          nextIdx = 0;
        } else {
          await _player.pause();
          return;
        }
      }
    }
    await _startTrackAt(state.queue[nextIdx], state.queue, nextIdx, contextName: state.playingContext);
  }

  Future<void> skipPrevious() async {
    if (state.queue.isEmpty) return;
    if (state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prevIdx = state.currentIndex > 0 ? state.currentIndex - 1 : state.queue.length - 1;
    await _startTrackAt(state.queue[prevIdx], state.queue, prevIdx, contextName: state.playingContext);
  }

  void toggleShuffle() {
    state = state.copyWith(shuffle: !state.shuffle);
  }

  void cycleRepeat() {
    final next = RepeatSetting.values[(state.repeat.index + 1) % RepeatSetting.values.length];
    state = state.copyWith(repeat: next);
  }

  void toggleQueueLock() {
    state = state.copyWith(queueLocked: !state.queueLocked);
    _persistQueueState();
  }

  void playNextInQueue(MusicItem track) {
    final list = List<MusicItem>.from(state.queue);
    if (list.isEmpty) {
      playTrack(track);
      return;
    }
    final insertAt = (state.currentIndex + 1).clamp(0, list.length);
    list.insert(insertAt, track);
    state = state.copyWith(queue: list);
    _persistQueueState();
  }

  void addToQueue(MusicItem track) {
    if (state.currentTrack == null) {
      playTrack(track);
      return;
    }
    state = state.copyWith(queue: [...state.queue, track]);
    _persistQueueState();
  }

  void removeFromQueue(int index) {
    if (state.queueLocked) return;
    if (index < 0 || index >= state.queue.length || index == state.currentIndex) return;
    final list = List<MusicItem>.from(state.queue)..removeAt(index);
    final newIdx = index < state.currentIndex ? state.currentIndex - 1 : state.currentIndex;
    state = state.copyWith(queue: list, currentIndex: newIdx);
    _persistQueueState();
  }

  Future<void> playShuffled(List<MusicItem> tracks, {String? contextName}) async {
    final playable = tracks.where((t) => t.id.isNotEmpty && t.isPlayable).toList();
    if (playable.isEmpty) return;
    playable.shuffle(_rng);
    state = state.copyWith(shuffle: true);
    await playTrack(playable.first, queue: playable, contextName: contextName);
  }

  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    await _player.setVolume(clamped).catchError((_) {});
    state = state.copyWith(volume: clamped);
    _persistQueueState();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    await _player.setSpeed(clamped).catchError((_) {});
    state = state.copyWith(playbackSpeed: clamped);
    _persistQueueState();
  }

  Future<void> setPitch(double pitch) async {
    final clamped = pitch.clamp(0.5, 1.5);
    await _player.setPitch(clamped).catchError((_) {});
    state = state.copyWith(pitch: clamped);
    _persistQueueState();
  }

  Future<void> setSoundStyle(SoundStylePreset style) async {
    await _player.setSpeed(style.speed).catchError((_) {});
    await _player.setPitch(style.pitch).catchError((_) {});
    state = state.copyWith(
      soundStyle: style,
      playbackSpeed: style.speed,
      pitch: style.pitch,
    );
    _persistQueueState();
  }

  Future<void> resetTempoPitch() async {
    await setSoundStyle(SoundStylePreset.normal);
  }

  Future<void> startRadio(MusicItem seed) async {
    state = state.copyWith(isLoadingRadio: true);
    try {
      final radio = await _ref.read(apiClientProvider).getRadioQueue(seed.id);
      final combined = [
        seed,
        ...radio.where((t) => t.id != seed.id),
      ];
      state = state.copyWith(isLoadingRadio: false);
      await playTrack(seed, queue: combined, contextName: 'Mix ${seed.title}');
    } catch (_) {
      state = state.copyWith(isLoadingRadio: false);
      await playTrack(seed, contextName: 'Mix ${seed.title}');
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (state.queueLocked) return;
    if (oldIndex < 0 || oldIndex >= state.queue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= state.queue.length) return;
    final list = List<MusicItem>.from(state.queue);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    var curIdx = state.currentIndex;
    if (oldIndex == curIdx) {
      curIdx = newIndex;
    } else if (oldIndex < curIdx && newIndex >= curIdx) {
      curIdx -= 1;
    } else if (oldIndex > curIdx && newIndex <= curIdx) {
      curIdx += 1;
    }
    state = state.copyWith(queue: list, currentIndex: curIdx);
    _persistQueueState();
  }

  void clearUpcomingQueue() {
    if (state.queueLocked) return;
    final cur = state.currentTrack;
    if (cur == null) {
      state = state.copyWith(queue: const [], currentIndex: -1);
      _persistQueueState();
      return;
    }
    state = state.copyWith(queue: [cur], currentIndex: 0);
    _persistQueueState();
  }

  void setSleepAfterTrack(bool enabled) {
    _sleepTimer?.cancel();
    state = state.copyWith(
      stopAfterCurrentTrack: enabled,
      clearSleepTimer: true,
    );
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null) {
      state = state.copyWith(clearSleepTimer: true, stopAfterCurrentTrack: false);
      return;
    }
    state = state.copyWith(sleepTimerRemaining: duration, stopAfterCurrentTrack: false);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final rem = state.sleepTimerRemaining;
      if (rem == null || rem.inSeconds <= 1) {
        timer.cancel();
        _player.pause();
        state = state.copyWith(clearSleepTimer: true, stopAfterCurrentTrack: false);
      } else {
        state = state.copyWith(sleepTimerRemaining: Duration(seconds: rem.inSeconds - 1));
      }
    });
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});
