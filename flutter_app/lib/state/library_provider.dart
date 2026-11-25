import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/music_models.dart';
import '../data/services/api_client.dart';
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
  final List<String> searchHistory;
  final Map<String, double> downloadProgress;

  const LibraryState({
    this.likedSongs = const [],
    this.recentlyPlayed = const [],
    this.downloadedTracks = const [],
    this.playlists = const [],
    this.followedArtists = const [],
    this.savedAlbums = const [],
    this.savedPlaylists = const [],
    this.searchHistory = const [],
    this.downloadProgress = const {},
  });

  bool isLiked(String id) => likedSongs.any((t) => t.id == id);
  bool isDownloaded(String id) => downloadedTracks.any((t) => t.id == id);
  bool isArtistFollowed(String id) => followedArtists.any((a) => a.id == id);
  bool isAlbumSaved(String id) => savedAlbums.any((a) => a.id == id);
  bool isPlaylistSaved(String id) => savedPlaylists.any((p) => p.id == id);

  MusicItem? getDownloadedTrack(String id) {
    for (final t in downloadedTracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  LibraryState copyWith({
    List<MusicItem>? likedSongs,
    List<MusicItem>? recentlyPlayed,
    List<MusicItem>? downloadedTracks,
    List<UserPlaylist>? playlists,
    List<MusicItem>? followedArtists,
    List<MusicItem>? savedAlbums,
    List<MusicItem>? savedPlaylists,
    List<String>? searchHistory,
    Map<String, double>? downloadProgress,
  }) {
    return LibraryState(
      likedSongs: likedSongs ?? this.likedSongs,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      downloadedTracks: downloadedTracks ?? this.downloadedTracks,
      playlists: playlists ?? this.playlists,
      followedArtists: followedArtists ?? this.followedArtists,
      savedAlbums: savedAlbums ?? this.savedAlbums,
      savedPlaylists: savedPlaylists ?? this.savedPlaylists,
      searchHistory: searchHistory ?? this.searchHistory,
      downloadProgress: downloadProgress ?? this.downloadProgress,
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

  void _load() {
    state = LibraryState(
      likedSongs: _decodeTracks('lib_liked'),
      recentlyPlayed: _decodeTracks('lib_recent'),
      downloadedTracks: _decodeTracks('lib_downloads'),
      playlists: _decodePlaylists('lib_playlists'),
      followedArtists: _decodeTracks('lib_artists'),
      savedAlbums: _decodeTracks('lib_albums'),
      savedPlaylists: _decodeTracks('lib_saved_playlists'),
      searchHistory: _prefs.getStringList('lib_search_history') ?? const [],
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

  Future<void> syncWithCloud({String? tokenOverride}) async {
    final token = tokenOverride ?? _ref.read(authProvider).sessionToken;
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

      state = state.copyWith(
        likedSongs: mergedLiked,
        playlists: mergedPlaylists,
        followedArtists: mergedArtists,
        savedAlbums: mergedAlbums,
        savedPlaylists: mergedSavedPl,
        recentlyPlayed: mergedRecent,
      );

      await Future.wait([
        _saveTracks('lib_liked', mergedLiked),
        _savePlaylists(),
        _saveTracks('lib_artists', mergedArtists),
        _saveTracks('lib_albums', mergedAlbums),
        _saveTracks('lib_saved_playlists', mergedSavedPl),
        _saveTracks('lib_recent', mergedRecent),
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
    final token = _ref.read(authProvider).sessionToken;
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

  Future<void> recordPlay(MusicItem track) async {
    final updated = [track, ...state.recentlyPlayed.where((t) => t.id != track.id)].take(40).toList();
    state = state.copyWith(recentlyPlayed: updated);
    await _saveTracks('lib_recent', updated);
    _scheduleCloudPush();
  }

  Future<void> addSearchHistory(String query) async {
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

  Future<void> createPlaylist(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final pl = UserPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: clean,
      tracks: const [],
    );
    state = state.copyWith(playlists: [...state.playlists, pl]);
    await _savePlaylists();
    _scheduleCloudPush();
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
