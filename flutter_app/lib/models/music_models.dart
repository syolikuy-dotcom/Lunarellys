import 'package:flutter/material.dart';

class MusicThumbnail {
  final String url;
  final int? width;
  final int? height;

  const MusicThumbnail({
    required this.url,
    this.width,
    this.height,
  });

  factory MusicThumbnail.fromJson(Map<String, dynamic> json) {
    return MusicThumbnail(
      url: (json['url'] ?? '').toString(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };
}

class MusicRef {
  final String name;
  final String? id;

  const MusicRef({
    required this.name,
    this.id,
  });

  factory MusicRef.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final cleanId = rawId?.toString().trim();
    return MusicRef(
      name: (json['name'] ?? '').toString(),
      id: (cleanId?.isEmpty ?? true) ? null : cleanId,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (id != null) 'id': id,
      };
}

String? _pickBestThumbnailUrl(List<MusicThumbnail> thumbnails, {int size = 400}) {
  if (thumbnails.isEmpty) return null;
  String? best;
  var bestScore = -1;
  for (final t in thumbnails) {
    if (t.url.trim().isEmpty) continue;
    final score = (t.width ?? 0) * (t.height ?? 0);
    if (best == null || score >= bestScore) {
      best = t.url.trim();
      bestScore = score;
    }
  }
  if (best == null || best.isEmpty) return null;
  final target = size;
  if (best.contains('googleusercontent.com') || best.contains('yt3.ggpht.com')) {
    // Format: =w120-h120-..., =s120-..., atau =w120-h120
    var out = best.replaceAll(
      RegExp(r'=w\d+-h\d+[^&\s]*'),
      '=w$target-h$target-l90-rj',
    );
    if (out == best) {
      out = best.replaceAll(RegExp(r'=s\d+[^&\s]*'), '=s$target-l90-rj');
    }
    return out;
  }
  if (best.contains('i.ytimg.com') || best.contains('img.youtube.com')) {
    // Thumbnail video kecil (default/mqdefault/hqdefault) -> versi resolusi tinggi
    return best
        .replaceAllMapped(
          RegExp(r'/(default|mqdefault|hqdefault|sddefault)(\.jpg|\.webp)'),
          (m) => '/${size >= 400 ? 'sddefault' : 'mqdefault'}${m[2]}',
        )
        .replaceAll(RegExp(r'\?sqp=[^&]*(&rs=[^&]*)?'), '');
  }
  return best;
}

class MusicItem {
  final String id;
  final String title;
  final String type;
  final List<MusicRef> artists;
  final MusicRef? album;
  final String? duration;
  final int? durationSeconds;
  final bool explicit;
  final String subtitle;
  final List<MusicThumbnail> thumbnails;
  final String? localAudioPath;

  const MusicItem({
    required this.id,
    required this.title,
    this.type = 'song',
    this.artists = const [],
    this.album,
    this.duration,
    this.durationSeconds,
    this.explicit = false,
    this.subtitle = '',
    this.thumbnails = const [],
    this.localAudioPath,
  });

  bool get isPlayable =>
      type == 'song' ||
      type == 'video' ||
      type == 'episode' ||
      type == 'unknown' ||
      type.isEmpty;

  String get artistDisplay {
    final joined = artists.map((a) => a.name).where((n) => n.isNotEmpty).join(', ');
    if (joined.isNotEmpty) return joined;
    return subtitle.isNotEmpty ? subtitle : 'Unknown Artist';
  }

  String? bestThumbUrl({int size = 400}) => _pickBestThumbnailUrl(thumbnails, size: size);

  MusicItem copyWith({
    String? id,
    String? title,
    String? type,
    List<MusicRef>? artists,
    MusicRef? album,
    String? duration,
    int? durationSeconds,
    bool? explicit,
    String? subtitle,
    List<MusicThumbnail>? thumbnails,
    String? localAudioPath,
  }) {
    return MusicItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      explicit: explicit ?? this.explicit,
      subtitle: subtitle ?? this.subtitle,
      thumbnails: thumbnails ?? this.thumbnails,
      localAudioPath: localAudioPath ?? this.localAudioPath,
    );
  }

  factory MusicItem.fromJson(Map<String, dynamic> json) {
    final rawArtists = json['artists'];
    final parsedArtists = <MusicRef>[];
    if (rawArtists is List) {
      for (final a in rawArtists) {
        if (a is Map<String, dynamic>) {
          parsedArtists.add(MusicRef.fromJson(a));
        } else if (a is Map) {
          parsedArtists.add(MusicRef.fromJson(Map<String, dynamic>.from(a)));
        } else if (a != null && a.toString().trim().isNotEmpty) {
          parsedArtists.add(MusicRef(name: a.toString().trim()));
        }
      }
    }

    MusicRef? parsedAlbum;
    final rawAlbum = json['album'];
    if (rawAlbum is Map<String, dynamic>) {
      parsedAlbum = MusicRef.fromJson(rawAlbum);
    } else if (rawAlbum is Map) {
      parsedAlbum = MusicRef.fromJson(Map<String, dynamic>.from(rawAlbum));
    }

    final rawThumbs = json['thumbnails'];
    final parsedThumbs = <MusicThumbnail>[];
    if (rawThumbs is List) {
      for (final t in rawThumbs) {
        if (t is Map<String, dynamic>) {
          parsedThumbs.add(MusicThumbnail.fromJson(t));
        } else if (t is Map) {
          parsedThumbs.add(MusicThumbnail.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }

    return MusicItem(
      id: (json['id'] ?? json['videoId'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? 'Untitled').toString(),
      type: (json['type'] ?? 'song').toString().toLowerCase(),
      artists: parsedArtists,
      album: parsedAlbum,
      duration: json['duration']?.toString(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      explicit: json['explicit'] == true,
      subtitle: (json['subtitle'] ?? '').toString(),
      thumbnails: parsedThumbs,
      localAudioPath: json['localAudioPath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'artists': artists.map((a) => a.toJson()).toList(),
        if (album != null) 'album': album!.toJson(),
        if (duration != null) 'duration': duration,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        'explicit': explicit,
        'subtitle': subtitle,
        'thumbnails': thumbnails.map((t) => t.toJson()).toList(),
        if (localAudioPath != null) 'localAudioPath': localAudioPath,
      };
}

List<MusicItem> _parseMusicItemList(dynamic raw) {
  if (raw is! List) return const [];
  final out = <MusicItem>[];
  for (final entry in raw) {
    if (entry is Map<String, dynamic>) {
      final item = MusicItem.fromJson(entry);
      if (item.id.isNotEmpty) out.add(item);
    } else if (entry is Map) {
      final item = MusicItem.fromJson(Map<String, dynamic>.from(entry));
      if (item.id.isNotEmpty) out.add(item);
    }
  }
  return out;
}

class MusicSection {
  final String title;
  final List<MusicItem> items;
  final String? continuation;

  const MusicSection({
    required this.title,
    this.items = const [],
    this.continuation,
  });

  factory MusicSection.fromJson(Map<String, dynamic> json) {
    return MusicSection(
      title: (json['title'] ?? '').toString(),
      items: _parseMusicItemList(json['items']),
      continuation: json['continuation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
        if (continuation != null) 'continuation': continuation,
      };
}

class MusicMood {
  final String name;
  final String browseId;
  final String params;

  const MusicMood({
    required this.name,
    required this.browseId,
    required this.params,
  });

  factory MusicMood.fromJson(Map<String, dynamic> json) {
    return MusicMood(
      name: (json['name'] ?? json['title'] ?? 'Mood').toString(),
      browseId: (json['browseId'] ?? '').toString(),
      params: (json['params'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'browseId': browseId,
        'params': params,
      };
}

class SearchResponseModel {
  final MusicItem? topResult;
  final List<MusicItem> results;
  final String? continuation;

  const SearchResponseModel({
    this.topResult,
    this.results = const [],
    this.continuation,
  });

  factory SearchResponseModel.fromJson(Map<String, dynamic> json) {
    MusicItem? top;
    final rawTop = json['topResult'];
    if (rawTop is Map<String, dynamic>) {
      final parsed = MusicItem.fromJson(rawTop);
      if (parsed.id.isNotEmpty) top = parsed;
    } else if (rawTop is Map) {
      final parsed = MusicItem.fromJson(Map<String, dynamic>.from(rawTop));
      if (parsed.id.isNotEmpty) top = parsed;
    }
    return SearchResponseModel(
      topResult: top,
      results: _parseMusicItemList(json['results']),
      continuation: json['continuation']?.toString(),
    );
  }
}

class MusicArtistDetail {
  final String id;
  final String name;
  final String description;
  final String? subscribers;
  final List<MusicThumbnail> thumbnails;
  final List<MusicSection> sections;

  const MusicArtistDetail({
    required this.id,
    required this.name,
    this.description = '',
    this.subscribers,
    this.thumbnails = const [],
    this.sections = const [],
  });

  String? bestThumbUrl({int size = 600}) => _pickBestThumbnailUrl(thumbnails, size: size);

  MusicItem toMusicItem() => MusicItem(
        id: id,
        title: name,
        type: 'artist',
        subtitle: subscribers ?? 'Artist',
        thumbnails: thumbnails,
      );

  factory MusicArtistDetail.fromJson(Map<String, dynamic> json) {
    final rawThumbs = json['thumbnails'];
    final thumbs = <MusicThumbnail>[];
    if (rawThumbs is List) {
      for (final t in rawThumbs) {
        if (t is Map) thumbs.add(MusicThumbnail.fromJson(Map<String, dynamic>.from(t)));
      }
    }
    final rawSections = json['sections'];
    final sections = <MusicSection>[];
    if (rawSections is List) {
      for (final s in rawSections) {
        if (s is Map) {
          final sec = MusicSection.fromJson(Map<String, dynamic>.from(s));
          if (sec.items.isNotEmpty) sections.add(sec);
        }
      }
    }
    return MusicArtistDetail(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? 'Artist').toString(),
      description: (json['description'] ?? '').toString(),
      subscribers: json['subscribers']?.toString(),
      thumbnails: thumbs,
      sections: sections,
    );
  }
}

class MusicAlbumDetail {
  final String id;
  final String type;
  final String title;
  final int? year;
  final int? trackCount;
  final String? duration;
  final String description;
  final List<MusicRef> artists;
  final List<MusicThumbnail> thumbnails;
  final List<MusicItem> tracks;
  final List<MusicSection> sections;
  final String? continuation;

  const MusicAlbumDetail({
    required this.id,
    this.type = 'album',
    required this.title,
    this.year,
    this.trackCount,
    this.duration,
    this.description = '',
    this.artists = const [],
    this.thumbnails = const [],
    this.tracks = const [],
    this.sections = const [],
    this.continuation,
  });

  String? bestThumbUrl({int size = 600}) => _pickBestThumbnailUrl(thumbnails, size: size);

  MusicItem toMusicItem() => MusicItem(
        id: id,
        title: title,
        type: type,
        artists: artists,
        duration: duration,
        subtitle: artists.map((a) => a.name).join(', '),
        thumbnails: thumbnails,
      );

  factory MusicAlbumDetail.fromJson(Map<String, dynamic> json) {
    final rawArtists = json['artists'];
    final artists = <MusicRef>[];
    if (rawArtists is List) {
      for (final a in rawArtists) {
        if (a is Map) artists.add(MusicRef.fromJson(Map<String, dynamic>.from(a)));
      }
    }
    final rawThumbs = json['thumbnails'];
    final thumbs = <MusicThumbnail>[];
    if (rawThumbs is List) {
      for (final t in rawThumbs) {
        if (t is Map) thumbs.add(MusicThumbnail.fromJson(Map<String, dynamic>.from(t)));
      }
    }
    final rawSections = json['sections'];
    final sections = <MusicSection>[];
    if (rawSections is List) {
      for (final s in rawSections) {
        if (s is Map) sections.add(MusicSection.fromJson(Map<String, dynamic>.from(s)));
      }
    }
    return MusicAlbumDetail(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'album').toString(),
      title: (json['title'] ?? 'Album').toString(),
      year: (json['year'] as num?)?.toInt(),
      trackCount: (json['trackCount'] as num?)?.toInt(),
      duration: json['duration']?.toString(),
      description: (json['description'] ?? '').toString(),
      artists: artists,
      thumbnails: thumbs,
      tracks: _parseMusicItemList(json['tracks']),
      sections: sections,
      continuation: json['continuation']?.toString(),
    );
  }
}

class MusicPlaylistDetail {
  final String id;
  final String title;
  final String? author;
  final String? duration;
  final int? trackCount;
  final String description;
  final List<MusicThumbnail> thumbnails;
  final List<MusicItem> tracks;
  final String? continuation;

  const MusicPlaylistDetail({
    required this.id,
    required this.title,
    this.author,
    this.duration,
    this.trackCount,
    this.description = '',
    this.thumbnails = const [],
    this.tracks = const [],
    this.continuation,
  });

  String? bestThumbUrl({int size = 600}) => _pickBestThumbnailUrl(thumbnails, size: size);

  MusicItem toMusicItem() => MusicItem(
        id: id,
        title: title,
        type: 'playlist',
        duration: duration,
        subtitle: author ?? '${tracks.length} songs',
        thumbnails: thumbnails,
      );

  factory MusicPlaylistDetail.fromJson(Map<String, dynamic> json) {
    final rawThumbs = json['thumbnails'];
    final thumbs = <MusicThumbnail>[];
    if (rawThumbs is List) {
      for (final t in rawThumbs) {
        if (t is Map) thumbs.add(MusicThumbnail.fromJson(Map<String, dynamic>.from(t)));
      }
    }
    return MusicPlaylistDetail(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Playlist').toString(),
      author: json['author']?.toString(),
      duration: json['duration']?.toString(),
      trackCount: (json['trackCount'] as num?)?.toInt(),
      description: (json['description'] ?? '').toString(),
      thumbnails: thumbs,
      tracks: _parseMusicItemList(json['tracks']),
      continuation: json['continuation']?.toString(),
    );
  }
}

class LyricLine {
  final int? timeMs;
  final String text;
  final String? romanized;
  final String? translated;

  const LyricLine({
    this.timeMs,
    required this.text,
    this.romanized,
    this.translated,
  });

  LyricLine copyWith({
    int? timeMs,
    String? text,
    String? romanized,
    String? translated,
  }) {
    return LyricLine(
      timeMs: timeMs ?? this.timeMs,
      text: text ?? this.text,
      romanized: romanized ?? this.romanized,
      translated: translated ?? this.translated,
    );
  }

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      timeMs: (json['timeMs'] as num?)?.toInt(),
      text: (json['text'] ?? '').toString(),
      romanized: json['romanized']?.toString(),
      translated: json['translated']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (timeMs != null) 'timeMs': timeMs,
        'text': text,
        if (romanized != null) 'romanized': romanized,
        if (translated != null) 'translated': translated,
      };
}

class LyricsResult {
  final String id;
  final bool synced;
  final List<LyricLine> lines;
  final String? plain;
  final String? source;

  const LyricsResult({
    this.id = '',
    this.synced = false,
    this.lines = const [],
    this.plain,
    this.source,
  });

  LyricsResult copyWith({
    String? id,
    bool? synced,
    List<LyricLine>? lines,
    String? plain,
    String? source,
  }) {
    return LyricsResult(
      id: id ?? this.id,
      synced: synced ?? this.synced,
      lines: lines ?? this.lines,
      plain: plain ?? this.plain,
      source: source ?? this.source,
    );
  }

  factory LyricsResult.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final parsedLines = <LyricLine>[];
    if (rawLines is List) {
      for (final l in rawLines) {
        if (l is Map) {
          final item = LyricLine.fromJson(Map<String, dynamic>.from(l));
          if (item.text.trim().isNotEmpty) parsedLines.add(item);
        } else if (l is String && l.trim().isNotEmpty) {
          parsedLines.add(LyricLine(text: l.trim()));
        }
      }
    }
    if (parsedLines.isEmpty && json['plain'] is String) {
      for (final line in (json['plain'] as String).split(RegExp(r'\r?\n'))) {
        if (line.trim().isNotEmpty) {
          parsedLines.add(LyricLine(text: line.trim()));
        }
      }
    }
    return LyricsResult(
      id: (json['id'] ?? '').toString(),
      synced: json['synced'] == true,
      lines: parsedLines,
      plain: json['plain']?.toString(),
      source: json['source']?.toString(),
    );
  }
}

class MusicSongDetail {
  final String id;
  final String title;
  final List<MusicRef> artists;
  final MusicRef? album;
  final int? durationSeconds;
  final List<MusicThumbnail> thumbnails;
  final LyricsResult? lyrics;
  final List<MusicItem> related;
  final List<MusicItem> upNext;

  const MusicSongDetail({
    required this.id,
    required this.title,
    this.artists = const [],
    this.album,
    this.durationSeconds,
    this.thumbnails = const [],
    this.lyrics,
    this.related = const [],
    this.upNext = const [],
  });

  factory MusicSongDetail.fromJson(Map<String, dynamic> json) {
    final rawArtists = json['artists'];
    final artists = <MusicRef>[];
    if (rawArtists is List) {
      for (final a in rawArtists) {
        if (a is Map) artists.add(MusicRef.fromJson(Map<String, dynamic>.from(a)));
      }
    }
    MusicRef? album;
    if (json['album'] is Map) {
      album = MusicRef.fromJson(Map<String, dynamic>.from(json['album'] as Map));
    }
    final rawThumbs = json['thumbnails'];
    final thumbs = <MusicThumbnail>[];
    if (rawThumbs is List) {
      for (final t in rawThumbs) {
        if (t is Map) thumbs.add(MusicThumbnail.fromJson(Map<String, dynamic>.from(t)));
      }
    }
    LyricsResult? lyrics;
    if (json['lyrics'] is Map) {
      lyrics = LyricsResult.fromJson(Map<String, dynamic>.from(json['lyrics'] as Map));
    }
    return MusicSongDetail(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      artists: artists,
      album: album,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      thumbnails: thumbs,
      lyrics: lyrics,
      related: _parseMusicItemList(json['related']),
      upNext: _parseMusicItemList(json['upNext']),
    );
  }
}

class UserPlaylist {
  final String id;
  final String name;
  final List<MusicItem> tracks;

  const UserPlaylist({
    required this.id,
    required this.name,
    this.tracks = const [],
  });

  UserPlaylist copyWith({
    String? id,
    String? name,
    List<MusicItem>? tracks,
  }) {
    return UserPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
    );
  }

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Playlist').toString(),
      tracks: _parseMusicItemList(json['tracks']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String picture;
  final bool isGuest;

  const AuthUser({
    required this.id,
    required this.name,
    this.email = '',
    this.picture = '',
    this.isGuest = false,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'L';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Listener').toString(),
      email: (json['email'] ?? '').toString(),
      picture: (json['picture'] ?? '').toString(),
      isGuest: json['isGuest'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'picture': picture,
        'isGuest': isGuest,
      };
}

class AuthStatus {
  final bool googleOAuthConfigured;
  final String? callbackUrl;

  const AuthStatus({
    this.googleOAuthConfigured = false,
    this.callbackUrl,
  });

  factory AuthStatus.fromJson(Map<String, dynamic> json) {
    return AuthStatus(
      googleOAuthConfigured: json['googleOAuthConfigured'] == true,
      callbackUrl: json['callbackUrl']?.toString(),
    );
  }
}

class CloudLibrarySnapshot {
  final List<MusicItem> likedSongs;
  final List<UserPlaylist> playlists;
  final List<MusicItem> followedArtists;
  final List<MusicItem> savedAlbums;
  final List<MusicItem> savedPlaylists;
  final List<MusicItem> recentlyPlayed;
  final List<MusicItem> pinnedSpeedDial;
  final Map<String, dynamic>? streakData;
  final String? updatedAt;

  const CloudLibrarySnapshot({
    this.likedSongs = const [],
    this.playlists = const [],
    this.followedArtists = const [],
    this.savedAlbums = const [],
    this.savedPlaylists = const [],
    this.recentlyPlayed = const [],
    this.pinnedSpeedDial = const [],
    this.streakData,
    this.updatedAt,
  });

  factory CloudLibrarySnapshot.fromJson(Map<String, dynamic> json) {
    final rawPlaylists = json['playlists'];
    final playlists = <UserPlaylist>[];
    if (rawPlaylists is List) {
      for (final p in rawPlaylists) {
        if (p is Map) {
          playlists.add(UserPlaylist.fromJson(Map<String, dynamic>.from(p)));
        }
      }
    }
    final rawStreak = json['streakData'];
    return CloudLibrarySnapshot(
      likedSongs: _parseMusicItemList(json['likedSongs']),
      playlists: playlists,
      followedArtists: _parseMusicItemList(json['followedArtists']),
      savedAlbums: _parseMusicItemList(json['savedAlbums']),
      savedPlaylists: _parseMusicItemList(json['savedPlaylists']),
      recentlyPlayed: _parseMusicItemList(json['recentlyPlayed']),
      pinnedSpeedDial: _parseMusicItemList(json['pinnedSpeedDial']),
      streakData: rawStreak is Map ? Map<String, dynamic>.from(rawStreak) : null,
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class NodeProbeResult {
  final bool ok;
  final String service;
  final String version;
  final String region;
  final bool googleOAuthConfigured;
  final String message;

  const NodeProbeResult({
    required this.ok,
    this.service = 'Archys',
    this.version = '1.2.0',
    this.region = 'ID',
    this.googleOAuthConfigured = false,
    this.message = '',
  });
}

class RemoteNodeConfig {
  final bool configured;
  final String serverUrl;
  final String apiKey;
  final String defaultUrl;
  final String note;
  final String? updatedAt;

  const RemoteNodeConfig({
    this.configured = false,
    required this.serverUrl,
    this.apiKey = '',
    this.defaultUrl = '',
    this.note = '',
    this.updatedAt,
  });

  factory RemoteNodeConfig.fromJson(Map<String, dynamic> json) {
    return RemoteNodeConfig(
      configured: json['configured'] == true,
      serverUrl: (json['serverUrl'] ?? json['defaultUrl'] ?? '').toString().trim(),
      apiKey: (json['apiKey'] ?? '').toString().trim(),
      defaultUrl: (json['defaultUrl'] ?? '').toString().trim(),
      note: (json['note'] ?? '').toString().trim(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class ListenTogetherRoom {
  final String roomCode;
  final String hostToken;
  final String hostName;
  final List<String> members;
  final MusicItem? currentTrack;
  final bool isPlaying;
  final int positionMs;
  final int updatedAtMs;

  const ListenTogetherRoom({
    required this.roomCode,
    this.hostToken = '',
    this.hostName = 'Host',
    this.members = const [],
    this.currentTrack,
    this.isPlaying = false,
    this.positionMs = 0,
    this.updatedAtMs = 0,
  });

  factory ListenTogetherRoom.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final members = <String>[];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m != null && m.toString().trim().isNotEmpty) {
          members.add(m.toString().trim());
        }
      }
    }
    MusicItem? track;
    if (json['track'] is Map) {
      track = MusicItem.fromJson(Map<String, dynamic>.from(json['track'] as Map));
    }
    return ListenTogetherRoom(
      roomCode: (json['roomCode'] ?? json['code'] ?? '').toString(),
      hostToken: (json['hostToken'] ?? '').toString(),
      hostName: (json['hostName'] ?? 'Host').toString(),
      members: members,
      currentTrack: track,
      isPlaying: json['isPlaying'] == true,
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class MusicApiException implements Exception {
  final String message;
  final int? statusCode;

  const MusicApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
