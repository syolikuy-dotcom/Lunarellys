import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

class LibraryState {
  final List<MusicItem> likedSongs;
  final List<MusicItem> recentlyPlayed;
  final List<MusicItem> downloadedTracks;
  final List<UserPlaylist> playlists;
  final List<MusicItem> followedArtists;
  final List<MusicItem> savedAlbums;
  final List<MusicItem> savedPlaylists;
  final List<MusicItem> pinnedSpeedDialItems;
  final List<String> searchHistory;
  final Map<String, double> downloadProgress;
  final Map<String, int> playCounts;
  final int totalListeningSeconds;
  final int currentStreak;
  final int longestStreak;
  final int totalActiveDays;
  final int streakRecoveryLeft;
  final String? lastStreakDate;

  const LibraryState({
    this.likedSongs = const [],
    this.recentlyPlayed = const [],
    this.downloadedTracks = const [],
    this.playlists = const [],
    this.followedArtists = const [],
    this.savedAlbums = const [],
    this.savedPlaylists = const [],
    this.pinnedSpeedDialItems = const [],
    this.searchHistory = const [],
    this.downloadProgress = const {},
    this.playCounts = const {},
    this.totalListeningSeconds = 0,
    this.currentStreak = 1,
    this.longestStreak = 1,
    this.totalActiveDays = 1,
    this.streakRecoveryLeft = 5,
    this.lastStreakDate,
  });

  bool isLiked(String id) => likedSongs.any((t) => t.id == id);
  bool isDownloaded(String id) => downloadedTracks.any((t) => t.id == id);
  bool isArtistFollowed(String id) => followedArtists.any((a) => a.id == id);
  bool isAlbumSaved(String id) => savedAlbums.any((a) => a.id == id);
  bool isPlaylistSaved(String id) => savedPlaylists.any((p) => p.id == id);
  bool isPinnedSpeedDial(String id) => pinnedSpeedDialItems.any((p) => p.id == id);

  MusicItem? getDownloadedTrack(String id) {
    for (final t in downloadedTracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<MusicItem> get top50Tracks {
    final byId = <String, MusicItem>{};
    for (final t in [...recentlyPlayed, ...likedSongs, ...downloadedTracks]) {
      byId.putIfAbsent(t.id, () => t);
    }
    final list = byId.values.toList();
    list.sort((a, b) => (playCounts[b.id] ?? 1).compareTo(playCounts[a.id] ?? 1));
    return list.take(50).toList();
  }

  LibraryState copyWith({
    List<MusicItem>? likedSongs,
    List<MusicItem>? recentlyPlayed,
    List<MusicItem>? downloadedTracks,
    List<UserPlaylist>? playlists,
    List<MusicItem>? followedArtists,
    List<MusicItem>? savedAlbums,
    List<MusicItem>? savedPlaylists,
    List<MusicItem>? pinnedSpeedDialItems,
    List<String>? searchHistory,
    Map<String, double>? downloadProgress,
    Map<String, int>? playCounts,
    int? totalListeningSeconds,
    int? currentStreak,
    int? longestStreak,
    int? totalActiveDays,
    int? streakRecoveryLeft,
    String? lastStreakDate,
  }) {
    return LibraryState(
      likedSongs: likedSongs ?? this.likedSongs,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      downloadedTracks: downloadedTracks ?? this.downloadedTracks,
      playlists: playlists ?? this.playlists,
      followedArtists: followedArtists ?? this.followedArtists,
      savedAlbums: savedAlbums ?? this.savedAlbums,
      savedPlaylists: savedPlaylists ?? this.savedPlaylists,
      pinnedSpeedDialItems: pinnedSpeedDialItems ?? this.pinnedSpeedDialItems,
      searchHistory: searchHistory ?? this.searchHistory,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      playCounts: playCounts ?? this.playCounts,
      totalListeningSeconds: totalListeningSeconds ?? this.totalListeningSeconds,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
      streakRecoveryLeft: streakRecoveryLeft ?? this.streakRecoveryLeft,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
    );
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final SharedPreferences _prefs;
  final Ref _ref;
  Timer? _syncDebounce;

  LibraryNotifier(this._prefs, this._ref) : super(const LibraryState()) {
    _load();
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.sessionToken != next.sessionToken &&
          next.sessionToken != null &&
          next.sessionToken!.isNotEmpty) {
        unawaited(syncWithCloud(tokenOverride: next.sessionToken));
      }
    });
  }

  Map<String, int> _decodePlayCounts() {
    final raw = _prefs.getString('lib_play_counts');
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 1),
        );
      }
    } catch (_) {}
    return const {};
  }

  void _load() {
    state = LibraryState(
      likedSongs: _decodeTracks('lib_liked'),
      recentlyPlayed: _decodeTracks('lib_recent'),
      downloadedTracks: _decodeTracks('lib_downloads'),
      playlists: _decodePlaylists('lib_playlists'),
      followedArtists: _decodeTracks('lib_artists'),
      savedAlbums: _decodeTracks('lib_albums'),
      savedPlaylists: _decodeTracks('lib_saved_playlists'),
      pinnedSpeedDialItems: _decodeTracks('lib_pinned_speed_dial'),
      searchHistory: _prefs.getStringList('lib_search_history') ?? const [],
      playCounts: _decodePlayCounts(),
      totalListeningSeconds: _prefs.getInt('lib_listening_seconds') ?? 0,
      currentStreak: _prefs.getInt('lib_streak_current') ?? 1,
      longestStreak: _prefs.getInt('lib_streak_longest') ?? 1,
      totalActiveDays: _prefs.getInt('lib_streak_days') ?? 1,
      streakRecoveryLeft: _prefs.getInt('lib_streak_recovery') ?? 5,
      lastStreakDate: _prefs.getString('lib_streak_last_date'),
    );
  }

  List<MusicItem> _decodeTracks(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<Map<String, dynamic>>().map(MusicItem.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  List<UserPlaylist> _decodePlaylists(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<Map<String, dynamic>>().map(UserPlaylist.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveTracks(String key, List<MusicItem> list) async {
    await _prefs.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> _savePlaylists() async {
    await _prefs.setString(
      'lib_playlists',
      jsonEncode(state.playlists.map((e) => e.toJson()).toList()),
    );
  }

  void _scheduleCloudPush() {
    final auth = _ref.read(authProvider);
    if (!auth.isSignedInGoogle) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(pushCloudSnapshot());
    });
  }

  Map<String, dynamic> _toCloudPayload() => {
        'likedSongs': state.likedSongs.map((e) => e.toJson()).toList(),
        'playlists': state.playlists.map((e) => e.toJson()).toList(),
        'followedArtists': state.followedArtists.map((e) => e.toJson()).toList(),
        'savedAlbums': state.savedAlbums.map((e) => e.toJson()).toList(),
        'savedPlaylists': state.savedPlaylists.map((e) => e.toJson()).toList(),
        'recentlyPlayed': state.recentlyPlayed.map((e) => e.toJson()).toList(),
        'pinnedSpeedDial': state.pinnedSpeedDialItems.map((e) => e.toJson()).toList(),
        'streakData': {
          'currentStreak': state.currentStreak,
          'longestStreak': state.longestStreak,
          'totalActiveDays': state.totalActiveDays,
          'totalListeningSeconds': state.totalListeningSeconds,
          'lastStreakDate': state.lastStreakDate,
        },
      };

  List<MusicItem> _mergeItemLists(List<MusicItem> local, List<MusicItem> cloud) {
    final seen = <String>{};
    final merged = <MusicItem>[];
    for (final item in [...local, ...cloud]) {
      if (item.id.isEmpty || seen.contains(item.id)) continue;
      seen.add(item.id);
      merged.add(item);
    }
    return merged;
  }

  List<UserPlaylist> _mergePlaylists(List<UserPlaylist> local, List<UserPlaylist> cloud) {
    final byId = <String, UserPlaylist>{};
    for (final pl in cloud) {
      byId[pl.id] = pl;
    }
    for (final pl in local) {
      final existing = byId[pl.id];
      if (existing == null) {
        byId[pl.id] = pl;
      } else {
        byId[pl.id] = UserPlaylist(
          id: pl.id,
          name: pl.name,
          tracks: _mergeItemLists(pl.tracks, existing.tracks),
        );
      }
    }
    return byId.values.toList();
  }

  Future<String?> _resolveSyncToken({String? tokenOverride}) async {
    final auth = _ref.read(authProvider);
    final rawToken = tokenOverride ?? auth.sessionToken;
    if (rawToken == null || rawToken.isEmpty) return null;
    if (rawToken != 'ytm-local-session') return rawToken;

    final user = auth.user;
    if (user == null || user.isGuest) return null;
    try {
      final api = _ref.read(apiClientProvider);
      final session = await api.createYtmSession(
        email: user.email == 'YouTube Music Terhubung' ? null : user.email,
        name: user.name,
        picture: user.picture,
        accountKey: user.id,
      );
      if (session.token.isNotEmpty) {
        await _ref.read(authProvider.notifier).adoptSession(
              user: session.user,
              token: session.token,
            );
        return session.token;
      }
    } catch (_) {}
    return null;
  }

  Future<void> syncWithCloud({String? tokenOverride}) async {
    final token = await _resolveSyncToken(tokenOverride: tokenOverride);
    if (token == null || token.isEmpty) return;

    _ref.read(authProvider.notifier).setSyncStatus(syncing: true);
    try {
      final api = _ref.read(apiClientProvider);
      final cloud = await api.pullCloudLibrary(token);

      final mergedLiked = _mergeItemLists(state.likedSongs, cloud.likedSongs);
      final mergedPlaylists = _mergePlaylists(state.playlists, cloud.playlists);
      final mergedArtists = _mergeItemLists(state.followedArtists, cloud.followedArtists);
      final mergedAlbums = _mergeItemLists(state.savedAlbums, cloud.savedAlbums);
      final mergedSavedPl = _mergeItemLists(state.savedPlaylists, cloud.savedPlaylists);
      final mergedRecent = _mergeItemLists(state.recentlyPlayed, cloud.recentlyPlayed).take(40).toList();
      final mergedPinned = _mergeItemLists(state.pinnedSpeedDialItems, cloud.pinnedSpeedDial).take(27).toList();

      final cloudStreak = cloud.streakData;
      var nextCurrentStreak = state.currentStreak;
      var nextLongestStreak = state.longestStreak;
      var nextTotalDays = state.totalActiveDays;
      var nextListeningSec = state.totalListeningSeconds;
      var nextLastDate = state.lastStreakDate;
      if (cloudStreak != null) {
        final cCur = (cloudStreak['currentStreak'] as num?)?.toInt() ?? 0;
        final cLong = (cloudStreak['longestStreak'] as num?)?.toInt() ?? 0;
        final cDays = (cloudStreak['totalActiveDays'] as num?)?.toInt() ?? 0;
        final cSec = (cloudStreak['totalListeningSeconds'] as num?)?.toInt() ?? 0;
        final cDate = cloudStreak['lastStreakDate']?.toString();
        if (cDate != null && cDate.isNotEmpty && (nextLastDate == null || cDate.compareTo(nextLastDate) > 0)) {
          nextLastDate = cDate;
          nextCurrentStreak = cCur;
        }
        nextLongestStreak = math.max(nextLongestStreak, math.max(cLong, nextCurrentStreak));
        nextTotalDays = math.max(nextTotalDays, cDays);
        nextListeningSec = math.max(nextListeningSec, cSec);
      }

      state = state.copyWith(
        likedSongs: mergedLiked,
        playlists: mergedPlaylists,
        followedArtists: mergedArtists,
        savedAlbums: mergedAlbums,
        savedPlaylists: mergedSavedPl,
        recentlyPlayed: mergedRecent,
        pinnedSpeedDialItems: mergedPinned,
        currentStreak: nextCurrentStreak,
        longestStreak: nextLongestStreak,
        totalActiveDays: nextTotalDays,
        totalListeningSeconds: nextListeningSec,
        lastStreakDate: nextLastDate,
      );

      await Future.wait([
        _saveTracks('lib_liked', mergedLiked),
        _savePlaylists(),
        _saveTracks('lib_artists', mergedArtists),
        _saveTracks('lib_albums', mergedAlbums),
        _saveTracks('lib_saved_playlists', mergedSavedPl),
        _saveTracks('lib_recent', mergedRecent),
        _saveTracks('lib_pinned_speed_dial', mergedPinned),
        _prefs.setInt('lib_listening_seconds', nextListeningSec),
        _prefs.setInt('lib_streak_current', nextCurrentStreak),
        _prefs.setInt('lib_streak_longest', nextLongestStreak),
        _prefs.setInt('lib_streak_days', nextTotalDays),
        if (nextLastDate != null) _prefs.setString('lib_streak_last_date', nextLastDate),
      ]);

      final pushed = await api.pushCloudLibrary(token, _toCloudPayload());
      _ref.read(authProvider.notifier).setSyncStatus(
            syncing: false,
            lastSyncAt: pushed.updatedAt ?? DateTime.now().toIso8601String(),
          );
    } catch (_) {
      _ref.read(authProvider.notifier).setSyncStatus(syncing: false);
    }
  }

  Future<void> pushCloudSnapshot() async {
    final token = await _resolveSyncToken();
    if (token == null || token.isEmpty) return;
    _ref.read(authProvider.notifier).setSyncStatus(syncing: true);
    try {
      final res = await _ref.read(apiClientProvider).pushCloudLibrary(token, _toCloudPayload());
      _ref.read(authProvider.notifier).setSyncStatus(
            syncing: false,
            lastSyncAt: res.updatedAt ?? DateTime.now().toIso8601String(),
          );
    } catch (_) {
      _ref.read(authProvider.notifier).setSyncStatus(syncing: false);
    }
  }

  Future<void> toggleLike(MusicItem track) async {
    final exists = state.isLiked(track.id);
    final updated = exists
        ? state.likedSongs.where((t) => t.id != track.id).toList()
        : [track, ...state.likedSongs];
    state = state.copyWith(likedSongs: updated);
    await _saveTracks('lib_liked', updated);
    _scheduleCloudPush();
  }

  Future<void> toggleFollowArtist(MusicItem artist) async {
    final exists = state.isArtistFollowed(artist.id);
    final updated = exists
        ? state.followedArtists.where((a) => a.id != artist.id).toList()
        : [artist, ...state.followedArtists];
    state = state.copyWith(followedArtists: updated);
    await _saveTracks('lib_artists', updated);
    _scheduleCloudPush();
  }

  Future<void> toggleSaveAlbum(MusicItem album) async {
    final exists = state.isAlbumSaved(album.id);
    final updated = exists
        ? state.savedAlbums.where((a) => a.id != album.id).toList()
        : [album, ...state.savedAlbums];
    state = state.copyWith(savedAlbums: updated);
    await _saveTracks('lib_albums', updated);
    _scheduleCloudPush();
  }

  Future<void> toggleSavePlaylist(MusicItem playlist) async {
    final exists = state.isPlaylistSaved(playlist.id);
    final updated = exists
        ? state.savedPlaylists.where((p) => p.id != playlist.id).toList()
        : [playlist, ...state.savedPlaylists];
    state = state.copyWith(savedPlaylists: updated);
    await _saveTracks('lib_saved_playlists', updated);
    _scheduleCloudPush();
  }

  Future<void> togglePinSpeedDial(MusicItem item) async {
    final exists = state.isPinnedSpeedDial(item.id);
    final updated = exists
        ? state.pinnedSpeedDialItems.where((p) => p.id != item.id).toList()
        : [item, ...state.pinnedSpeedDialItems].take(27).toList();
    state = state.copyWith(pinnedSpeedDialItems: updated);
    await _saveTracks('lib_pinned_speed_dial', updated);
    _scheduleCloudPush();
  }

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> recordPlay(MusicItem track) async {
    final settings = _ref.read(settingsProvider);
    if (settings.pauseWatchHistory) return;

    final updated = [track, ...state.recentlyPlayed.where((t) => t.id != track.id)].take(40).toList();
    final counts = Map<String, int>.from(state.playCounts);
    counts[track.id] = (counts[track.id] ?? 0) + 1;
    final addedSec = (track.durationSeconds ?? 180).clamp(30, 900);
    final nextSec = state.totalListeningSeconds + addedSec;

    final now = DateTime.now();
    final todayStr = _dateKey(now);
    final lastStr = state.lastStreakDate;
    var nextStreak = state.currentStreak;
    var nextLongest = state.longestStreak;
    var nextDays = state.totalActiveDays;
    var nextRecovery = state.streakRecoveryLeft;

    if (lastStr == null || lastStr.isEmpty) {
      nextStreak = nextStreak < 1 ? 1 : nextStreak;
      nextLongest = nextLongest < nextStreak ? nextStreak : nextLongest;
      nextDays = nextDays < 1 ? 1 : nextDays;
    } else if (lastStr != todayStr) {
      final parsedLast = DateTime.tryParse(lastStr);
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final diffDays = parsedLast == null
          ? 2
          : todayMidnight.difference(DateTime(parsedLast.year, parsedLast.month, parsedLast.day)).inDays;
      nextDays += 1;
      if (diffDays == 1) {
        nextStreak += 1;
      } else if (diffDays == 2 && nextRecovery > 0) {
        nextRecovery -= 1;
        nextStreak += 1;
      } else if (diffDays > 1) {
        nextStreak = 1;
      }
      if (nextStreak > nextLongest) nextLongest = nextStreak;
    }

    state = state.copyWith(
      recentlyPlayed: updated,
      playCounts: counts,
      totalListeningSeconds: nextSec,
      currentStreak: nextStreak,
      longestStreak: nextLongest,
      totalActiveDays: nextDays,
      streakRecoveryLeft: nextRecovery,
      lastStreakDate: todayStr,
    );
    await _saveTracks('lib_recent', updated);
    await _prefs.setString('lib_play_counts', jsonEncode(counts));
    await _prefs.setInt('lib_listening_seconds', nextSec);
    await _prefs.setInt('lib_streak_current', nextStreak);
    await _prefs.setInt('lib_streak_longest', nextLongest);
    await _prefs.setInt('lib_streak_days', nextDays);
    await _prefs.setInt('lib_streak_recovery', nextRecovery);
    await _prefs.setString('lib_streak_last_date', todayStr);
    _scheduleCloudPush();
  }

  Future<void> addSearchHistory(String query) async {
    if (_ref.read(settingsProvider).pauseSearchHistory) return;
    final q = query.trim();
    if (q.isEmpty) return;
    final updated = [q, ...state.searchHistory.where((x) => x.toLowerCase() != q.toLowerCase())].take(15).toList();
    state = state.copyWith(searchHistory: updated);
    await _prefs.setStringList('lib_search_history', updated);
  }

  Future<void> removeSearchHistory(String query) async {
    final updated = state.searchHistory.where((x) => x != query).toList();
    state = state.copyWith(searchHistory: updated);
    await _prefs.setStringList('lib_search_history', updated);
  }

  Future<void> clearSearchHistory() async {
    state = state.copyWith(searchHistory: const []);
    await _prefs.remove('lib_search_history');
  }

  Future<UserPlaylist?> createPlaylist(
    String name, {
    List<MusicItem> initialTracks = const [],
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    final uniqueTracks = <String, MusicItem>{};
    for (final t in initialTracks) {
      uniqueTracks.putIfAbsent(t.id, () => t);
    }
    final pl = UserPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: clean,
      tracks: uniqueTracks.values.toList(),
    );
    state = state.copyWith(playlists: [...state.playlists, pl]);
    await _savePlaylists();
    _scheduleCloudPush();
    return pl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    state = state.copyWith(
      playlists: state.playlists.where((p) => p.id != playlistId).toList(),
    );
    await _savePlaylists();
    _scheduleCloudPush();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    final updated = state.playlists
        .map((p) => p.id == playlistId ? p.copyWith(name: clean) : p)
        .toList();
    state = state.copyWith(playlists: updated);
    await _savePlaylists();
    _scheduleCloudPush();
  }

  Future<void> clearHistory() async {
    state = state.copyWith(recentlyPlayed: const []);
    await _prefs.remove('lib_recent');
    _scheduleCloudPush();
  }

  Future<void> addTrackToPlaylist(String playlistId, MusicItem track) async {
    final updated = state.playlists.map((pl) {
      if (pl.id != playlistId) return pl;
      if (pl.tracks.any((t) => t.id == track.id)) return pl;
      return pl.copyWith(tracks: [...pl.tracks, track]);
    }).toList();
    state = state.copyWith(playlists: updated);
    await _savePlaylists();
    _scheduleCloudPush();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final updated = state.playlists.map((pl) {
      if (pl.id != playlistId) return pl;
      return pl.copyWith(tracks: pl.tracks.where((t) => t.id != trackId).toList());
    }).toList();
    state = state.copyWith(playlists: updated);
    await _savePlaylists();
    _scheduleCloudPush();
  }

  String exportBackupJson() {
    final payload = {
      'app': 'Archys',
      'exportedAt': DateTime.now().toIso8601String(),
      ..._toCloudPayload(),
      'pinnedSpeedDial': state.pinnedSpeedDialItems.map((e) => e.toJson()).toList(),
      'playCounts': state.playCounts,
      'totalListeningSeconds': state.totalListeningSeconds,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<int> importBackupJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Format cadangan JSON tidak valid');
    }
    final map = Map<String, dynamic>.from(decoded);
    List<MusicItem> parseItems(String key) {
      final list = map[key];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => MusicItem.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.id.isNotEmpty)
          .toList();
    }

    final rawPlaylists = map['playlists'];
    final importedPlaylists = <UserPlaylist>[];
    if (rawPlaylists is List) {
      for (final p in rawPlaylists) {
        if (p is Map) {
          importedPlaylists.add(UserPlaylist.fromJson(Map<String, dynamic>.from(p)));
        }
      }
    }

    final mergedLiked = _mergeItemLists(state.likedSongs, parseItems('likedSongs'));
    final mergedPlaylists = _mergePlaylists(state.playlists, importedPlaylists);
    final mergedArtists = _mergeItemLists(state.followedArtists, parseItems('followedArtists'));
    final mergedAlbums = _mergeItemLists(state.savedAlbums, parseItems('savedAlbums'));
    final mergedSavedPl = _mergeItemLists(state.savedPlaylists, parseItems('savedPlaylists'));
    final mergedRecent = _mergeItemLists(state.recentlyPlayed, parseItems('recentlyPlayed')).take(40).toList();
    final mergedPinned = _mergeItemLists(state.pinnedSpeedDialItems, parseItems('pinnedSpeedDial')).take(27).toList();

    state = state.copyWith(
      likedSongs: mergedLiked,
      playlists: mergedPlaylists,
      followedArtists: mergedArtists,
      savedAlbums: mergedAlbums,
      savedPlaylists: mergedSavedPl,
      recentlyPlayed: mergedRecent,
      pinnedSpeedDialItems: mergedPinned,
    );

    await Future.wait([
      _saveTracks('lib_liked', mergedLiked),
      _savePlaylists(),
      _saveTracks('lib_artists', mergedArtists),
      _saveTracks('lib_albums', mergedAlbums),
      _saveTracks('lib_saved_playlists', mergedSavedPl),
      _saveTracks('lib_recent', mergedRecent),
      _saveTracks('lib_pinned_speed_dial', mergedPinned),
    ]);
    _scheduleCloudPush();
    return mergedLiked.length + mergedPlaylists.length + mergedRecent.length;
  }

  Future<void> downloadTrack(MusicItem track) async {
    if (state.isDownloaded(track.id) || state.downloadProgress.containsKey(track.id)) return;
    final MusicApiClient api = _ref.read(apiClientProvider);
    final quality = _ref.read(settingsProvider).audioQuality;

    state = state.copyWith(
      downloadProgress: {...state.downloadProgress, track.id: 0.01},
    );

    try {
      final path = await api.downloadTrackOffline(
        track,
        quality: quality,
        onProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(
              downloadProgress: {...state.downloadProgress, track.id: received / total},
            );
          }
        },
      );
      final savedTrack = track.copyWith(localAudioPath: path);
      final updated = [savedTrack, ...state.downloadedTracks.where((t) => t.id != track.id)];
      final progressMap = Map<String, double>.from(state.downloadProgress)..remove(track.id);
      state = state.copyWith(downloadedTracks: updated, downloadProgress: progressMap);
      await _saveTracks('lib_downloads', updated);
    } catch (_) {
      final progressMap = Map<String, double>.from(state.downloadProgress)..remove(track.id);
      state = state.copyWith(downloadProgress: progressMap);
      rethrow;
    }
  }

  Future<void> removeDownload(String trackId) async {
    final target = state.getDownloadedTrack(trackId);
    if (target?.localAudioPath != null) {
      final file = File(target!.localAudioPath!);
      if (await file.exists()) {
        await file.delete().catchError((_) => file);
      }
    }
    final updated = state.downloadedTracks.where((t) => t.id != trackId).toList();
    state = state.copyWith(downloadedTracks: updated);
    await _saveTracks('lib_downloads', updated);
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    super.dispose();
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(ref.watch(sharedPreferencesProvider), ref);
});

final homePlayablePoolProvider = StateProvider<List<MusicItem>>((ref) => const []);

