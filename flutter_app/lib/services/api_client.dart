import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../core/config/app_config.dart';
import '../models/music_models.dart';

class MusicApiClient {
  final String baseUrl;
  final String apiKey;
  late final Dio _dio;

  MusicApiClient({
    required String baseUrl,
    this.apiKey = '',
  }) : baseUrl = AppConfig.normalizeServerUrl(baseUrl) {
    _dio = Dio(
      BaseOptions(
        baseUrl: this.baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Accept': 'application/json',
          if (apiKey.trim().isNotEmpty) 'X-API-Key': apiKey.trim(),
        },
      ),
    );
  }

  Map<String, String> get authHeaders => {
        if (apiKey.trim().isNotEmpty) 'X-API-Key': apiKey.trim(),
      };

  String buildStreamUrl(String trackId, {AudioQuality quality = AudioQuality.high}) {
    return '$baseUrl/api/music/proxy-stream?id=${Uri.encodeComponent(trackId)}&quality=${quality.apiValue}&format=mp4';
  }

  String buildArtworkProxyUrl(String rawUrl) {
    return '$baseUrl/api/music/artwork?url=${Uri.encodeComponent(rawUrl)}';
  }

  String buildGoogleLoginUrl() {
    return '$baseUrl/api/auth/google/start?platform=flutter';
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
        throw const MusicApiException('Server returned an unexpected HTML page instead of JSON.');
      }
    }
    return <String, dynamic>{};
  }

  MusicApiException _toApiError(Object err) {
    if (err is MusicApiException) return err;
    if (err is DioException) {
      final status = err.response?.statusCode;
      final raw = err.response?.data;
      if (raw is Map) {
        final msg = (raw['error'] ?? raw['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) {
          return MusicApiException(msg, statusCode: status);
        }
      } else if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.startsWith('{')) {
          try {
            final parsed = jsonDecode(trimmed);
            if (parsed is Map && (parsed['error'] != null || parsed['message'] != null)) {
              return MusicApiException(
                (parsed['error'] ?? parsed['message']).toString(),
                statusCode: status,
              );
            }
          } catch (_) {}
        }
        if (status != null) {
          return MusicApiException('Server responded with status HTTP $status', statusCode: status);
        }
      }
      if (err.type == DioExceptionType.connectionTimeout ||
          err.type == DioExceptionType.receiveTimeout) {
        return const MusicApiException('Connection timed out. Please check your internet or node server.');
      }
      return MusicApiException(
        err.message ?? 'Network request failed. Please try again.',
        statusCode: status,
      );
    }
    return MusicApiException(err.toString());
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: headers != null ? Options(headers: headers) : null,
      );
      final map = _asMap(res.data);
      if (map['success'] == false) {
        throw MusicApiException(
          (map['error'] ?? map['message'] ?? 'Request failed').toString(),
          statusCode: res.statusCode,
        );
      }
      return map;
    } catch (err) {
      throw _toApiError(err);
    }
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method, headers: headers),
      );
      final map = _asMap(res.data);
      if (map['success'] == false) {
        throw MusicApiException(
          (map['error'] ?? map['message'] ?? 'Request failed').toString(),
          statusCode: res.statusCode,
        );
      }
      return map;
    } catch (err) {
      throw _toApiError(err);
    }
  }

  List<MusicSection> _parseSections(dynamic raw) {
    if (raw is! List) return const [];
    final out = <MusicSection>[];
    for (final s in raw) {
      if (s is Map) {
        final sec = MusicSection.fromJson(Map<String, dynamic>.from(s));
        if (sec.items.isNotEmpty) out.add(sec);
      }
    }
    return out;
  }

  Future<List<MusicSection>> getHome() async {
    final data = await _getJson('/api/music/home');
    return _parseSections(data['sections']);
  }

  Future<List<MusicMood>> getMoods() async {
    final data = await _getJson('/api/music/moods');
    final raw = data['moods'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => MusicMood.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => m.name.isNotEmpty && m.browseId.isNotEmpty)
        .toList();
  }

  Future<List<MusicSection>> getMoodPlaylists(String browseId, String params) async {
    final data = await _getJson(
      '/api/music/mood',
      query: {'browseId': browseId, 'params': params},
    );
    return _parseSections(data['sections']);
  }

  Future<List<MusicSection>> getExplore() async {
    final data = await _getJson('/api/music/explore');
    return _parseSections(data['sections']);
  }

  Future<List<MusicSection>> getCharts() async {
    final data = await _getJson('/api/music/charts');
    return _parseSections(data['sections']);
  }

  Future<List<String>> getSuggestions(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    final data = await _getJson('/api/music/suggestions', query: {'q': clean});
    final raw = data['suggestions'];
    if (raw is! List) return const [];
    final out = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        out.add(item.trim());
      } else if (item is Map) {
        final text = (item['query'] ?? item['text'] ?? item['title'] ?? '').toString().trim();
        if (text.isNotEmpty) out.add(text);
      }
    }
    return out;
  }

  Future<SearchResponseModel> search(
    String query, {
    String filter = 'all',
    String? continuation,
  }) async {
    final data = await _getJson(
      '/api/music/search',
      query: {
        'q': query.trim(),
        'filter': filter,
        if (continuation != null && continuation.isNotEmpty) 'continuation': continuation,
      },
    );
    return SearchResponseModel.fromJson(data);
  }

  Future<MusicArtistDetail> getArtist(String id) async {
    final data = await _getJson('/api/music/artist', query: {'id': id});
    final raw = data['artist'];
    if (raw is Map) {
      return MusicArtistDetail.fromJson(Map<String, dynamic>.from(raw));
    }
    return MusicArtistDetail.fromJson(data);
  }

  Future<MusicAlbumDetail> getAlbum(String id, {String? continuation}) async {
    final data = await _getJson(
      '/api/music/album',
      query: {
        'id': id,
        if (continuation != null && continuation.isNotEmpty) 'continuation': continuation,
      },
    );
    final raw = data['album'];
    if (raw is Map) {
      return MusicAlbumDetail.fromJson(Map<String, dynamic>.from(raw));
    }
    return MusicAlbumDetail.fromJson(data);
  }

  Future<MusicPlaylistDetail> getPlaylist(String id, {String? continuation}) async {
    final data = await _getJson(
      '/api/music/playlist',
      query: {
        'id': id,
        if (continuation != null && continuation.isNotEmpty) 'continuation': continuation,
      },
    );
    final raw = data['playlist'];
    if (raw is Map) {
      return MusicPlaylistDetail.fromJson(Map<String, dynamic>.from(raw));
    }
    return MusicPlaylistDetail.fromJson(data);
  }

  Future<MusicSongDetail> getSongDetail(String id) async {
    final data = await _getJson(
      '/api/music/song',
      query: {'id': id, 'lyrics': 'false'},
    );
    final raw = data['song'];
    if (raw is Map) {
      return MusicSongDetail.fromJson(Map<String, dynamic>.from(raw));
    }
    return MusicSongDetail.fromJson(data);
  }

  Future<LyricsResult> getLyrics(
    String id, {
    String? title,
    String? artist,
    int? durationSeconds,
  }) async {
    final data = await _getJson(
      '/api/music/lyrics',
      query: {
        'id': id,
        if (title != null && title.isNotEmpty) 'title': title,
        if (artist != null && artist.isNotEmpty) 'artist': artist,
        if (durationSeconds != null) 'duration': durationSeconds,
      },
    );
    return LyricsResult.fromJson(data);
  }

  Future<List<({String? romanized, String? translated})>> getLyricsAssist({
    required List<String> lines,
    required String targetLang,
    required bool romanize,
    required bool translate,
  }) async {
    if (lines.isEmpty || (!romanize && !translate)) return const [];
    final data = await _sendJson(
      'POST',
      '/api/music/lyrics-assist',
      body: {
        'lines': lines.take(120).toList(),
        'targetLang': targetLang,
        'romanize': romanize,
        'translate': translate,
      },
    );
    final raw = data['lines'];
    if (raw is! List) return const [];
    return raw.map((item) {
      if (item is Map) {
        final r = item['romanized']?.toString().trim();
        final t = item['translated']?.toString().trim();
        return (
          romanized: (r == null || r.isEmpty) ? null : r,
          translated: (t == null || t.isEmpty) ? null : t,
        );
      }
      return (romanized: null, translated: null);
    }).toList();
  }

  Future<List<MusicItem>> getRadioQueue(String id) async {
    final data = await _getJson('/api/music/radio', query: {'id': id});
    final raw = data['tracks'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((t) => MusicItem.fromJson(Map<String, dynamic>.from(t)))
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  Future<String> downloadTrackOffline(
    MusicItem track, {
    required AudioQuality quality,
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/offline_audio');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath = '${folder.path}/$safeId.m4a';
    final url = buildStreamUrl(track.id, quality: quality);
    try {
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: onProgress,
        options: Options(headers: authHeaders),
      );
      return filePath;
    } catch (err) {
      throw _toApiError(err);
    }
  }

  Future<AuthStatus> getAuthStatus() async {
    final data = await _getJson('/api/auth/status');
    return AuthStatus.fromJson(data);
  }

  Future<({String token, AuthUser user})> createYtmSession({
    String? email,
    String? name,
    String? picture,
    String? accountKey,
  }) async {
    final data = await _sendJson(
      'POST',
      '/api/auth/ytm-session',
      body: {
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (picture != null && picture.trim().isNotEmpty) 'picture': picture.trim(),
        if (accountKey != null && accountKey.trim().isNotEmpty)
          'accountKey': accountKey.trim(),
      },
    );
    final token = (data['token'] ?? '').toString();
    final rawUser = data['user'];
    final user = rawUser is Map
        ? AuthUser.fromJson(Map<String, dynamic>.from(rawUser))
        : AuthUser.fromJson(data);
    return (token: token, user: user);
  }

  Future<AuthUser> getCurrentUser(String token) async {
    final data = await _getJson(
      '/api/auth/me',
      headers: {'Authorization': 'Bearer $token'},
    );
    final raw = data['user'];
    if (raw is Map) {
      return AuthUser.fromJson(Map<String, dynamic>.from(raw));
    }
    return AuthUser.fromJson(data);
  }

  Future<CloudLibrarySnapshot> pullCloudLibrary(String token) async {
    final data = await _getJson(
      '/api/user/sync',
      headers: {'Authorization': 'Bearer $token'},
    );
    final raw = data['library'];
    if (raw is Map) {
      return CloudLibrarySnapshot.fromJson(Map<String, dynamic>.from(raw));
    }
    return CloudLibrarySnapshot.fromJson(data);
  }

  Future<CloudLibrarySnapshot> pushCloudLibrary(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final data = await _sendJson(
      'PUT',
      '/api/user/sync',
      body: payload,
      headers: {'Authorization': 'Bearer $token'},
    );
    final raw = data['library'];
    if (raw is Map) {
      return CloudLibrarySnapshot.fromJson(Map<String, dynamic>.from(raw));
    }
    return CloudLibrarySnapshot.fromJson(data);
  }

  Future<NodeProbeResult> probeNode({
    String? overrideBaseUrl,
    String? overrideApiKey,
  }) async {
    final targetUrl = (overrideBaseUrl != null && overrideBaseUrl.trim().isNotEmpty)
        ? AppConfig.normalizeServerUrl(overrideBaseUrl)
        : baseUrl;
    final key = (overrideApiKey ?? apiKey).trim();
    final tempDio = Dio(
      BaseOptions(
        baseUrl: targetUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
          if (key.isNotEmpty) 'X-API-Key': key,
        },
      ),
    );
    try {
      final res = await tempDio.get<dynamic>('/api/node/info');
      final map = _asMap(res.data);
      return NodeProbeResult(
        ok: true,
        service: (map['service'] ?? 'Archys').toString(),
        version: (map['version'] ?? AppConfig.appVersion).toString(),
        region: (map['region'] ?? 'ID').toString(),
        googleOAuthConfigured: map['googleOAuthConfigured'] == true,
        message: 'Online (${map['status'] ?? 'ok'})',
      );
    } catch (err) {
      final apiErr = _toApiError(err);
      return NodeProbeResult(
        ok: false,
        message: apiErr.message,
      );
    }
  }

  Future<Map<String, dynamic>> verifyAdminAndFetchStats({
    required String passcode,
    String? overrideBaseUrl,
    String? overrideApiKey,
  }) async {
    final targetUrl = (overrideBaseUrl != null && overrideBaseUrl.trim().isNotEmpty)
        ? AppConfig.normalizeServerUrl(overrideBaseUrl)
        : baseUrl;
    final key = (overrideApiKey ?? apiKey).trim();
    final tempDio = Dio(
      BaseOptions(
        baseUrl: targetUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Accept': 'application/json',
          'X-Admin-Passcode': passcode,
          if (key.isNotEmpty) 'X-API-Key': key,
        },
      ),
    );
    try {
      await tempDio.post<dynamic>('/api/admin/verify');
      final stats = await tempDio.get<dynamic>('/api/admin/stats');
      return _asMap(stats.data);
    } catch (err) {
      throw _toApiError(err);
    }
  }

  Future<RemoteNodeConfig> fetchRemoteNodeConfig({String? bootstrapUrl}) async {
    final targetUrl = (bootstrapUrl != null && bootstrapUrl.trim().isNotEmpty)
        ? AppConfig.normalizeServerUrl(bootstrapUrl)
        : AppConfig.defaultBaseUrl;
    final tempDio = Dio(
      BaseOptions(
        baseUrl: targetUrl,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {'Accept': 'application/json'},
      ),
    );
    try {
      final res = await tempDio.get<dynamic>('/api/node/config');
      final map = _asMap(res.data);
      if (map['success'] == false) {
        throw MusicApiException(
          (map['error'] ?? 'Failed to read remote node config').toString(),
          statusCode: res.statusCode,
        );
      }
      return RemoteNodeConfig.fromJson(map);
    } catch (err) {
      throw _toApiError(err);
    }
  }

  /// Cek passcode admin ke salah satu server kandidat. Mengembalikan true jika
  /// salah satu server menerima passcode. Tidak pernah melempar error.
  Future<bool> verifyAdminPasscode({
    required String passcode,
    List<String> candidateUrls = const [],
  }) async {
    final pass = passcode.trim();
    if (pass.isEmpty) return false;
    final urls = <String>{
      for (final u in candidateUrls)
        if (u.trim().isNotEmpty) AppConfig.normalizeServerUrl(u),
      if (baseUrl.trim().isNotEmpty) AppConfig.normalizeServerUrl(baseUrl),
      AppConfig.defaultBaseUrl,
      if (AppConfig.pterodactylExampleUrl != AppConfig.defaultBaseUrl)
        AppConfig.pterodactylExampleUrl,
    };
    for (final url in urls) {
      try {
        final dio = Dio(
          BaseOptions(
            baseUrl: url,
            connectTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 8),
            headers: {
              'Accept': 'application/json',
              'X-Admin-Passcode': pass,
              if (apiKey.trim().isNotEmpty) 'X-API-Key': apiKey.trim(),
            },
          ),
        );
        final res = await dio.post<dynamic>(
          '/api/admin/verify',
          options: Options(validateStatus: (c) => c != null && c < 500),
        );
        if ((res.statusCode ?? 0) == 200 && _asMap(res.data)['success'] != false) {
          return true;
        }
      } catch (_) {
        // coba kandidat berikutnya
      }
    }
    return false;
  }

  Future<RemoteNodeConfig> publishRemoteNodeConfig({
    required String passcode,
    required String serverUrl,
    String apiKey = '',
    bool reset = false,
    String note = '',
    String? bootstrapUrl,
  }) async {
    // Config global harus ditulis ke server Lunarellys yang benar-benar jalan.
    // Dulu selalu ke AppConfig.defaultBaseUrl (bukan node yang diketik admin),
    // itulah penyebab HTTP 405. Sekarang urutan target: bootstrap -> URL node
    // yang diketik -> server aktif -> default.
    final candidates = <String>[];
    void addCandidate(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final n = AppConfig.normalizeServerUrl(raw);
      if (!candidates.contains(n)) candidates.add(n);
    }

    addCandidate(bootstrapUrl);
    addCandidate(serverUrl);
    addCandidate(baseUrl);
    addCandidate(AppConfig.defaultBaseUrl);

    final payload = reset
        ? <String, dynamic>{'reset': true}
        : <String, dynamic>{
            'serverUrl': AppConfig.normalizeServerUrl(serverUrl),
            'apiKey': apiKey.trim(),
            if (note.trim().isNotEmpty) 'note': note.trim(),
          };

    MusicApiException? lastError;
    for (final target in candidates) {
      try {
        return await _publishTo(target, passcode.trim(), payload);
      } catch (err) {
        final apiErr = _toApiError(err);
        lastError = apiErr;
        // Passcode salah = berhenti, jangan coba server lain.
        if (apiErr.statusCode == 403) break;
      }
    }
    throw lastError ??
        const MusicApiException('Gagal menyimpan konfigurasi node global');
  }

  Future<RemoteNodeConfig> _publishTo(
    String targetUrl,
    String passcode,
    Map<String, dynamic> payload,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: targetUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Admin-Passcode': passcode,
          if (apiKey.trim().isNotEmpty) 'X-API-Key': apiKey.trim(),
        },
      ),
    );

    // Pastikan target memang node Lunarellys (bukan nginx / panel / halaman lain).
    // Jika server melakukan redirect (mis. http -> https, HTTP 301/302),
    // gunakan origin hasil redirect untuk request berikutnya agar tidak kena 302.
    var resolvedBase = targetUrl;
    try {
      final probe = await dio.get<dynamic>('/api/node/info');
      final pm = _asMap(probe.data);
      if (pm['success'] != true) {
        throw const MusicApiException(
          'URL ini bukan server Archys. Cek alamat & port (contoh :4686).',
        );
      }
      final real = probe.realUri;
      if (real.hasScheme && real.host.isNotEmpty) {
        final portPart = real.hasPort &&
                !((real.scheme == 'http' && real.port == 80) ||
                    (real.scheme == 'https' && real.port == 443))
            ? ':${real.port}'
            : '';
        resolvedBase = '${real.scheme}://${real.host}$portPart';
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      throw MusicApiException(
        code != null
            ? 'URL ini bukan server Archys (HTTP $code). Cek alamat & port.'
            : 'Tidak bisa terhubung ke $targetUrl',
        statusCode: code,
      );
    }

    // Coba /api/admin/node-config/publish (POST) dulu karena lebih tahan proxy,
    // lalu fallback PUT -> POST -> PATCH ke /api/admin/node-config.
    // Redirect (301/302/307/308) diikuti manual agar method + body tetap utuh.
    final attempts = <({String method, String path})>[
      (method: 'POST', path: '/api/admin/node-config/publish'),
      (method: 'PUT', path: '/api/admin/node-config'),
      (method: 'POST', path: '/api/admin/node-config'),
      (method: 'PATCH', path: '/api/admin/node-config'),
    ];
    Response<dynamic>? res;
    for (final attempt in attempts) {
      var url = '$resolvedBase${attempt.path}';
      for (var hop = 0; hop < 5; hop++) {
        res = await dio.request<dynamic>(
          url,
          data: payload,
          options: Options(
            method: attempt.method,
            followRedirects: false,
            validateStatus: (code) => code != null && code < 500,
          ),
        );
        final code = res.statusCode ?? 0;
        if (code >= 300 && code < 400) {
          final loc = res.headers.value('location');
          if (loc == null || loc.isEmpty) break;
          url = Uri.parse(url).resolve(loc).toString();
          continue;
        }
        break;
      }
      final code = res?.statusCode ?? 0;
      if (code == 405 || code == 404) continue; // coba method / path berikutnya
      break;
    }

    final code = res?.statusCode ?? 0;
    if (res == null || code >= 400 || code >= 300) {
      final body = _asMap(res?.data);
      final msg = (body['error'] ?? body['message'] ?? '').toString().trim();
      if (code == 403) {
        throw MusicApiException(
          msg.isNotEmpty && msg != 'forbidden' ? msg : 'Admin Passcode salah',
          statusCode: 403,
        );
      }
      if (code == 405 || code == 404) {
        throw MusicApiException(
          'Proxy/server menolak metode ini (HTTP $code). Coba pakai HTTPS atau update & restart node server.',
          statusCode: code,
        );
      }
      throw MusicApiException(
        msg.isNotEmpty ? msg : 'Server membalas HTTP $code',
        statusCode: code,
      );
    }
    final map = _asMap(res.data);
    if (map['success'] == false) {
      throw MusicApiException(
        (map['error'] ?? 'Gagal menyimpan konfigurasi node global').toString(),
        statusCode: res.statusCode,
      );
    }
    return RemoteNodeConfig.fromJson(map);
  }

  Future<ListenTogetherRoom> createListenTogetherRoom(String hostName) async {
    final data = await _sendJson(
      'POST',
      '/api/listen-together/host',
      body: {'hostName': hostName},
    );
    return ListenTogetherRoom.fromJson(data);
  }

  Future<ListenTogetherRoom> joinListenTogetherRoom(
    String roomCode,
    String memberName,
  ) async {
    final data = await _sendJson(
      'POST',
      '/api/listen-together/join',
      body: {
        'roomCode': roomCode.trim().toUpperCase(),
        'memberName': memberName,
      },
    );
    return ListenTogetherRoom.fromJson(data);
  }

  Future<ListenTogetherRoom> getListenTogetherState(String roomCode) async {
    final data = await _getJson(
      '/api/listen-together/state',
      query: {'code': roomCode.trim().toUpperCase()},
    );
    return ListenTogetherRoom.fromJson(data);
  }

  Future<void> syncListenTogetherRoom({
    required String roomCode,
    required String hostToken,
    required MusicItem? track,
    required bool isPlaying,
    required int positionMs,
  }) async {
    await _sendJson(
      'POST',
      '/api/listen-together/sync',
      body: {
        'roomCode': roomCode.trim().toUpperCase(),
        'hostToken': hostToken,
        'track': track?.toJson(),
        'isPlaying': isPlaying,
        'positionMs': positionMs,
      },
    );
  }
}
