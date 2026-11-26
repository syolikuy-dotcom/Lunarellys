export const routes = [];

const API_PREFIX = '/api';

export function route(method, path, description, params, example) {
  routes.push({ method, path: API_PREFIX + path, description, params, example });
  return path;
}

route('GET', '/', 'API information and developer metadata', [], {
  request: 'GET /api/',
  response: '{ success, name, service, version, developer, auth, region }'
});

route('GET', '/health', 'Health check with cache stats and node capabilities', [], {
  request: 'GET /api/health',
  response: '{ success, status, service, version, developer, uptime, authRequired, cache }'
});

route('GET', '/node/info', 'Public Pterodactyl / self-hosted node discovery & capability probe', [], {
  request: 'GET /api/node/info',
  response: '{ success, status, service, version, developer, region, baseUrl, authRequired, googleOAuthConfigured, callbackUrl }'
});

route('GET', '/search', 'YouTube search (all types combined)', [
  { name: 'q', required: true, type: 'string', description: 'Search query' },
  { name: 'gl', required: false, type: 'string', description: 'Geo region code, default ID' },
  { name: 'hl', required: false, type: 'string', description: 'Language code, default en' }
], {
  request: 'GET /api/search?q=lofi hip hop',
  response: '{ success, query, type: "all", total, results: [ { type: video|playlist|channel|short, ... } ] }'
});

route('GET', '/search/video', 'YouTube search videos only', [
  { name: 'q', required: true, type: 'string', description: 'Search query' },
  { name: 'gl', required: false, type: 'string', description: 'Geo region code' },
  { name: 'hl', required: false, type: 'string', description: 'Language code' }
], {
  request: 'GET /api/search/video?q=lofi hip hop',
  response: '{ success, query, type: "video", total, results: [ { videoId, title, author, views, duration, thumbnail, ... } ] }'
});

route('GET', '/search/channel', 'YouTube search channels only', [
  { name: 'q', required: true, type: 'string', description: 'Search query' }
], {
  request: 'GET /api/search/channel?q=lofi girl',
  response: '{ success, query, type: "channel", total, results: [ { channelId, name, handle, subscribers, thumbnail, ... } ] }'
});

route('GET', '/search/playlist', 'YouTube search playlists only', [
  { name: 'q', required: true, type: 'string', description: 'Search query' }
], {
  request: 'GET /api/search/playlist?q=lofi 2024',
  response: '{ success, query, type: "playlist", total, results: [ { playlistId, title, videoCount, thumbnail, ... } ] }'
});

route('GET', '/search/shorts', 'YouTube search shorts only', [
  { name: 'q', required: true, type: 'string', description: 'Search query' }
], {
  request: 'GET /api/search/shorts?q=funny cats',
  response: '{ success, query, type: "shorts", total, results: [ { videoId, title, views, thumbnail } ] }'
});

route('GET', '/video', 'Video details (title, description, likes, channel, related, chapters)', [
  { name: 'id', required: true, type: 'string', description: 'Video ID or URL' }
], {
  request: 'GET /api/video?id=dQw4w9WgXcQ',
  response: '{ success, video: { videoId, title, description, views, likes, channel, related, chapters, ... } }'
});

route('GET', '/video/comments', 'Video comments (paginated)', [
  { name: 'id', required: true, type: 'string', description: 'Video ID or URL' },
  { name: 'continuation', required: false, type: 'string', description: 'Continuation token from previous response' }
], {
  request: 'GET /api/video/comments?id=dQw4w9WgXcQ',
  response: '{ success, videoId, total, comments: [ { author, text, likes, replies } ], continuation }'
});

route('GET', '/channel', 'Channel details (about, links, subscribers)', [
  { name: 'id', required: true, type: 'string', description: 'Channel ID, @handle, or URL' }
], {
  request: 'GET /api/channel?id=@MrBeast',
  response: '{ success, channel: { channelId, name, description, subscribers, links, ... } }'
});

route('GET', '/channel/videos', 'Channel videos tab', [
  { name: 'id', required: true, type: 'string', description: 'Channel ID, @handle, or URL' },
  { name: 'tab', required: false, type: 'string', description: 'videos | shorts | streams, default videos' }
], {
  request: 'GET /api/channel/videos?id=@MrBeast',
  response: '{ success, channelId, tab, total, videos: [ { videoId, title, views, duration, ... } ], continuation }'
});

route('GET', '/playlist', 'Playlist details with videos', [
  { name: 'id', required: true, type: 'string', description: 'Playlist ID or URL' }
], {
  request: 'GET /api/playlist?id=PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
  response: '{ success, playlist: { playlistId, title, owner, videoCount, videos: [...], continuation } }'
});

route('GET', '/trending', 'YouTube trending feed', [
  { name: 'region', required: false, type: 'string', description: 'Region code (ID, US, GB, JP), default ID' }
], {
  request: 'GET /api/trending?region=ID',
  response: '{ success, region, total, videos: [ { videoId, title, author, views, ... } ] }'
});

route('GET', '/music/search', 'YouTube Music search with filters', [
  { name: 'q', required: true, type: 'string', description: 'Search query' },
  { name: 'filter', required: false, type: 'string', description: 'all | songs | videos | albums | artists | playlists | community_playlists | featured_playlists | podcasts | episodes | profiles' },
  { name: 'continuation', required: false, type: 'string', description: 'Continuation token for next page' }
], {
  request: 'GET /api/music/search?q=coldplay&filter=songs',
  response: '{ success, query, filter, topResult, results: [ { type: song|video|album|artist|playlist, id, title, artists, ... } ], continuation }'
});

route('GET', '/music/suggestions', 'YouTube Music search suggestions', [
  { name: 'q', required: true, type: 'string', description: 'Partial query' }
], {
  request: 'GET /api/music/suggestions?q=cold',
  response: '{ success, query, total, suggestions: [ { query } ] }'
});

route('GET', '/music/song', 'Song detail with lyrics, related, queue and stream data', [
  { name: 'id', required: true, type: 'string', description: 'Video ID' },
  { name: 'lyrics', required: false, type: 'string', description: 'false to skip lyrics fetch' }
], {
  request: 'GET /api/music/song?id=9qnqYL0eNNI',
  response: '{ success, song: { id, title, artists, album, lyrics, related, upNext, stream } }'
});

route('GET', '/music/artist', 'Artist page (songs, albums, singles, related)', [
  { name: 'id', required: true, type: 'string', description: 'Artist browse ID (UC...)' }
], {
  request: 'GET /api/music/artist?id=UCIaFw5VBEK8qaW6nRpx_qnw',
  response: '{ success, artist: { id, name, description, subscribers, sections } }'
});

route('GET', '/music/album', 'Album detail with tracks', [
  { name: 'id', required: true, type: 'string', description: 'Album browse ID (MPREb...)' },
  { name: 'continuation', required: false, type: 'string', description: 'Continuation token' }
], {
  request: 'GET /api/music/album?id=MPREb_oBucXyijinj',
  response: '{ success, album: { type, id, title, year, trackCount, tracks, ... } }'
});

route('GET', '/music/playlist', 'Music playlist detail with tracks', [
  { name: 'id', required: true, type: 'string', description: 'Playlist ID (PL...)' },
  { name: 'continuation', required: false, type: 'string', description: 'Continuation token' }
], {
  request: 'GET /api/music/playlist?id=PLfOOT_t91UDhq6JJO_U4PqqcBISJvJP1W',
  response: '{ success, playlist: { id, title, trackCount, tracks, ... } }'
});

route('GET', '/music/home', 'YouTube Music home feed', [], {
  request: 'GET /api/music/home',
  response: '{ success, sections: [ { title, items } ] }'
});

route('GET', '/music/explore', 'YouTube Music explore feed', [], {
  request: 'GET /api/music/explore',
  response: '{ success, sections: [ { title, items } ] }'
});

route('GET', '/music/charts', 'YouTube Music charts', [], {
  request: 'GET /api/music/charts',
  response: '{ success, sections: [ { title, items } ] }'
});

route('GET', '/music/moods', 'Moods and genres with browse params', [], {
  request: 'GET /api/music/moods',
  response: '{ success, total, moods: [ { name, browseId, params } ] }'
});

route('GET', '/music/mood', 'Playlists for a mood or genre', [
  { name: 'browseId', required: true, type: 'string', description: 'Mood browse ID from /music/moods' },
  { name: 'params', required: true, type: 'string', description: 'Mood params from /music/moods' }
], {
  request: 'GET /api/music/mood?browseId=FEmusic_moods_and_genres_category&params=...',
  response: '{ success, sections: [ { title, items } ] }'
});

route('GET', '/music/stream', 'Direct audio and video stream URLs for a track (IOS player)', [
  { name: 'id', required: true, type: 'string', description: 'Video ID' }
], {
  request: 'GET /api/music/stream?id=9qnqYL0eNNI',
  response: '{ success, track: { id, title, bestAudio, audio: [...], video: [...], expiresAt } }'
});

route('GET', '/music/audio', 'Best audio stream only', [
  { name: 'id', required: true, type: 'string', description: 'Video ID' }
], {
  request: 'GET /api/music/audio?id=9qnqYL0eNNI',
  response: '{ success, track: { id, title, best, audio: [...] } }'
});

route('GET', '/music/lyrics', 'Time-synced LRC and plain lyrics for a track', [
  { name: 'id', required: true, type: 'string', description: 'Video ID' },
  { name: 'title', required: false, type: 'string', description: 'Optional track title for LRCLIB match' },
  { name: 'artist', required: false, type: 'string', description: 'Optional artist name for LRCLIB match' },
  { name: 'duration', required: false, type: 'number', description: 'Optional duration in seconds' }
], {
  request: 'GET /api/music/lyrics?id=9qnqYL0eNNI',
  response: '{ success, id, synced, lines: [{ timeMs, text }], plain, source }'
});

route('GET', '/music/radio', 'Up-next radio queue and related tracks', [
  { name: 'id', required: true, type: 'string', description: 'Seed Video ID' }
], {
  request: 'GET /api/music/radio?id=9qnqYL0eNNI',
  response: '{ success, id, total, tracks: [...] }'
});

route('GET', '/music/proxy-stream', 'HTTP Range-aware audio stream proxy for Web & Flutter playback', [
  { name: 'id', required: true, type: 'string', description: 'Video ID' },
  { name: 'quality', required: false, type: 'string', description: 'high | medium | low, default high' },
  { name: 'format', required: false, type: 'string', description: 'mp4 | auto, default auto' }
], {
  request: 'GET /api/music/proxy-stream?id=9qnqYL0eNNI&quality=high',
  response: 'Binary audio stream (200 OK / 206 Partial Content)'
});

route('GET', '/download/v1', 'Downloader V1 via @distube/ytdl-core', [
  { name: 'url', required: true, type: 'string', description: 'YouTube video URL or ID' },
  { name: 'type', required: false, type: 'string', description: 'video | audio, default video' },
  { name: 'quality', required: false, type: 'string', description: 'e.g. 720 for video, 128 for audio bitrate' }
], {
  request: 'GET /api/download/v1?url=https://youtu.be/dQw4w9WgXcQ&type=video&quality=720',
  response: '{ success, engine: "v1", videoId, title, format: {...}, download: { url, sizeMb, expiresInSeconds } }'
});

route('GET', '/download/v2', 'Downloader V2 via SSYouTube (challenge + tunnel)', [
  { name: 'url', required: true, type: 'string', description: 'YouTube video URL or ID' },
  { name: 'type', required: false, type: 'string', description: 'video | audio, default video' },
  { name: 'quality', required: false, type: 'string', description: '720 default video, 320 default audio' }
], {
  request: 'GET /api/download/v2?url=https://youtu.be/dQw4w9WgXcQ&type=audio&quality=320',
  response: '{ success, engine: "v2", videoId, resolved: { quality }, download: { url, tunnel, sizeMb } }'
});

route('GET', '/download/v3', 'Downloader V3 via SnapYT (formats listing)', [
  { name: 'url', required: true, type: 'string', description: 'YouTube video URL or ID' },
  { name: 'type', required: false, type: 'string', description: 'video | audio, default video' },
  { name: 'quality', required: false, type: 'string', description: 'e.g. 720p or 320 (kbps)' }
], {
  request: 'GET /api/download/v3?url=https://youtu.be/dQw4w9WgXcQ&type=video',
  response: '{ success, engine: "v3", videoId, title, resolved, download: { url }, availableFormats }'
});

route('GET', '/download/all', 'Try all three downloaders, first success wins', [
  { name: 'url', required: true, type: 'string', description: 'YouTube video URL or ID' },
  { name: 'type', required: false, type: 'string', description: 'video | audio, default video' }
], {
  request: 'GET /api/download/all?url=https://youtu.be/dQw4w9WgXcQ&type=audio',
  response: '{ success, winner: "v1", result: {...}, failures: [...] }'
});

route('GET', '/auth/status', 'Check Google OAuth configuration and callback URI', [], {
  request: 'GET /api/auth/status',
  response: '{ success, googleOAuthConfigured, callbackUrl, deepLinkScheme }'
});

route('GET', '/auth/google/start', 'Start Google OAuth 2.0 flow for Flutter or Web', [
  { name: 'platform', required: false, type: 'string', description: 'flutter | web, default flutter' }
], {
  request: 'GET /api/auth/google/start?platform=flutter',
  response: '302 Redirect to Google OAuth consent screen'
});

route('GET', '/auth/me', 'Get authenticated Google user profile', [], {
  request: 'GET /api/auth/me (Header: X-User-Token)',
  response: '{ success, user: { id, name, email, picture, lastLoginAt } }'
});

route('GET', '/user/sync', 'Fetch or update synced cloud library snapshot', [], {
  request: 'GET/PUT /api/user/sync (Header: X-User-Token)',
  response: '{ success, library: { likedSongs, playlists, followedArtists, savedAlbums, savedPlaylists, recentlyPlayed, updatedAt } }'
});

