import { Router } from 'express';
import { Readable } from 'node:stream';
import { config } from './config.js';
import { TtlCache } from './lib/cache.js';
import { asyncHandler, downloadRateLimit, requireAdminAuth, adminRateLimit } from './middleware.js';
import { routes } from './routes-registry.js';
import * as searchScraper from './scrapers/search.js';
import * as ytScraper from './scrapers/youtube.js';
import * as musicScraper from './scrapers/music.js';
import { downloadV1 } from './scrapers/downloader-v1.js';
import { downloadV2 } from './scrapers/downloader-v2.js';
import { downloadV3 } from './scrapers/downloader-v3.js';
import { HttpError, UpstreamError, extractVideoId } from './lib/http.js';
import authRouter from './auth-routes.js';

const cache = new TtlCache(config.cacheMaxEntries);
const TTL = config.cacheTtlMs;

const inFlight = new Map();

function cachedFn(keyFn, resolver, ttl = TTL) {
  return async (...args) => {
    const key = keyFn(...args);
    const hit = cache.get(key);
    if (hit !== undefined) return hit;
    if (inFlight.has(key)) return inFlight.get(key);
    const promise = Promise.resolve()
      .then(() => resolver(...args))
      .then((value) => {
        cache.set(key, value, ttl);
        return value;
      })
      .finally(() => {
        inFlight.delete(key);
      });
    inFlight.set(key, promise);
    return promise;
  };
}

const cachedSearch = cachedFn((q, gl, hl) => `search|all|${q}|${gl}|${hl}`, (q, gl, hl) => searchScraper.searchAll(q, { gl, hl }));
const cachedSearchType = cachedFn((t, q, gl, hl) => `search|${t}|${q}|${gl}|${hl}`, (t, q, gl, hl) => searchScraper.searchAll(q, { type: t, gl, hl }));
const cachedShorts = cachedFn((q, gl, hl) => `search|shorts|${q}|${gl}|${hl}`, (q, gl, hl) => searchScraper.searchShorts(q, { gl, hl }));
const cachedVideo = cachedFn((id) => `video|${id}`, (id) => ytScraper.getVideoMeta(id));
const cachedComments = cachedFn((id, cont) => `comments|${id}|${cont || ''}`, (id, cont) => ytScraper.getComments(id, cont), 120000);
const cachedChannel = cachedFn((id) => `channel|${id}`, (id) => ytScraper.getChannelMeta(id));
const cachedChannelVideos = cachedFn((id, tab) => `channelvideos|${id}|${tab}`, (id, tab) => ytScraper.getChannelVideos(id, tab));
const cachedTrending = cachedFn((region) => `trending|${region}`, (region) => ytScraper.getTrending(region));
const cachedPlaylist = cachedFn((id) => `playlist|${id}`, (id) => ytScraper.getPlaylistMeta(id));

const cachedMusicSearch = cachedFn((q, f, token) => `msearch|${q}|${f}|${token || ''}`, (q, f, token) => musicScraper.musicSearch(q, f, 1, token), 180000);
const cachedMusicSuggestions = cachedFn((q) => `msugg|${q}`, (q) => musicScraper.musicSuggestions(q), 300000);
const cachedMusicArtist = cachedFn((id) => `martist|${id}`, (id) => musicScraper.musicArtist(id));
const cachedMusicAlbum = cachedFn((id, token) => `malbum|${id}|${token || ''}`, (id, token) => musicScraper.musicAlbum(id, 1, token));
const cachedMusicPlaylist = cachedFn((id, token) => `mplaylist|${id}|${token || ''}`, (id, token) => musicScraper.musicPlaylist(id, 1, token));
const cachedMusicHome = cachedFn(() => 'mhome', () => musicScraper.musicHome());
const cachedMusicExplore = cachedFn(() => 'mexplore', () => musicScraper.musicExplore());
const cachedMusicCharts = cachedFn(() => 'mcharts', () => musicScraper.musicCharts());
const cachedMusicMoods = cachedFn(() => 'mmoods', () => musicScraper.musicMoods());
const cachedMusicMood = cachedFn((b, p) => `mmood|${b}|${p}`, (b, p) => musicScraper.musicMoodPlaylists(b, p));
const cachedMusicSong = cachedFn((id, ly) => `msong|${id}|${ly}`, (id, ly) => musicScraper.musicSong(id, ly));
const cachedMusicStream = cachedFn((id) => `mstream|${id}`, (id) => musicScraper.musicStream(id), 60 * 60 * 1000);
const cachedMusicLyrics = cachedFn((id, t, a, d) => `mlyrics|${id}|${t}|${a}|${d}`, (id, t, a, d) => musicScraper.getSyncedLyrics(id, { title: t, artist: a, durationSeconds: d }), 30 * 60 * 1000);
const cachedMusicRadio = cachedFn((id) => `mradio|${id}`, (id) => musicScraper.getRadioQueue(id), 10 * 60 * 1000);

function requireQuery(value, name) {
  if (!value || !String(value).trim()) {
    throw new HttpError(`missing required query parameter '${name}'`, 400);
  }
  return String(value).trim();
}

function parseBool(value, fallback = true) {
  if (value === undefined || value === null) return fallback;
  return !['false', '0', 'no'].includes(String(value).toLowerCase());
}

const router = Router();
router.use(authRouter);

router.get('/', (req, res) => {
  res.json({
    success: true,
    service: 'lunarellys-api'
  });
});

router.get('/admin/routes', adminRateLimit, requireAdminAuth, (req, res) => {
  res.json({
    success: true,
    cache: cache.stats(),
    endpoints: routes.map((r) => ({ method: r.method, path: r.path, description: r.description }))
  });
});

router.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'ok'
  });
});

router.get('/search', asyncHandler(async (req, res) => {
  const q = requireQuery(req.query.q || req.query.query, 'q');
  const gl = req.query.gl ? String(req.query.gl).slice(0, 2) : config.defaultRegion;
  const hl = req.query.hl ? String(req.query.hl).slice(0, 5) : 'en';
  const data = await cachedSearch(q, gl, hl);
  res.json({ success: true, ...data });
}));

for (const type of ['video', 'channel', 'playlist']) {
  router.get(`/search/${type}`, asyncHandler(async (req, res) => {
    const q = requireQuery(req.query.q || req.query.query, 'q');
    const gl = req.query.gl ? String(req.query.gl).slice(0, 2) : config.defaultRegion;
    const hl = req.query.hl ? String(req.query.hl).slice(0, 5) : 'en';
    const data = await cachedSearchType(type, q, gl, hl);
    res.json({ success: true, ...data });
  }));
}

router.get('/search/shorts', asyncHandler(async (req, res) => {
  const q = requireQuery(req.query.q || req.query.query, 'q');
  const gl = req.query.gl ? String(req.query.gl).slice(0, 2) : config.defaultRegion;
  const hl = req.query.hl ? String(req.query.hl).slice(0, 5) : 'en';
  const data = await cachedShorts(q, gl, hl);
  res.json({ success: true, ...data });
}));

router.get('/video', asyncHandler(async (req, res) => {
  const id = extractVideoId(requireQuery(req.query.id || req.query.v, 'id'));
  if (!id) throw new HttpError('invalid video id or url', 400);
  const video = await cachedVideo(id);
  res.json({ success: true, video });
}));

router.get('/video/comments', asyncHandler(async (req, res) => {
  const id = extractVideoId(requireQuery(req.query.id || req.query.v, 'id'));
  if (!id) throw new HttpError('invalid video id or url', 400);
  const continuation = req.query.continuation ? String(req.query.continuation) : null;
  const data = await cachedComments(id, continuation);
  res.json({ success: true, ...data });
}));

router.get('/channel', asyncHandler(async (req, res) => {
  const id = requireQuery(req.query.id, 'id');
  const channel = await cachedChannel(id);
  res.json({ success: true, channel });
}));

router.get('/channel/videos', asyncHandler(async (req, res) => {
  const id = requireQuery(req.query.id, 'id');
  const tab = ['videos', 'shorts', 'streams'].includes(req.query.tab) ? req.query.tab : 'videos';
  const data = await cachedChannelVideos(id, tab);
  res.json({ success: true, ...data });
}));

router.get('/trending', asyncHandler(async (req, res) => {
  const region = req.query.region ? String(req.query.region).slice(0, 2).toUpperCase() : config.defaultRegion;
  const data = await cachedTrending(region);
  res.json({ success: true, ...data });
}));

router.get('/playlist', asyncHandler(async (req, res) => {
  const raw = requireQuery(req.query.id || req.query.list, 'id');
  const id = raw.match(/(PL|OL|UU|FL|LL|RD)[\w-]{10,}/)?.[0] || raw;
  const playlist = await cachedPlaylist(id);
  res.json({ success: true, playlist });
}));

const MUSIC_FILTERS = ['all', 'songs', 'videos', 'albums', 'artists', 'playlists', 'community_playlists', 'featured_playlists', 'podcasts', 'episodes', 'profiles'];

router.get('/music/search', asyncHandler(async (req, res) => {
  const q = requireQuery(req.query.q || req.query.query, 'q');
  const filter = MUSIC_FILTERS.includes(req.query.filter) ? req.query.filter : 'all';
  const token = req.query.continuation ? String(req.query.continuation) : '';
  const data = token
    ? await musicScraper.musicSearch(q, filter, 1, token)
    : await cachedMusicSearch(q, filter, token);
  res.json({ success: true, ...data });
}));

router.get('/music/suggestions', asyncHandler(async (req, res) => {
  const q = requireQuery(req.query.q || req.query.query, 'q');
  const data = await cachedMusicSuggestions(q);
  res.json({ success: true, ...data });
}));

router.get('/music/song', asyncHandler(async (req, res) => {
  const id = extractVideoId(requireQuery(req.query.id || req.query.v, 'id'));
  if (!id) throw new HttpError('invalid video id or url', 400);
  const withLyrics = parseBool(req.query.lyrics, true);
  const song = await cachedMusicSong(id, withLyrics);
  res.json({ success: true, song });
}));

router.get('/music/artist', asyncHandler(async (req, res) => {
  const id = requireQuery(req.query.id, 'id');
  const artist = await cachedMusicArtist(id);
  res.json({ success: true, artist });
}));

router.get('/music/album', asyncHandler(async (req, res) => {
  const id = requireQuery(req.query.id, 'id');
  const token = req.query.continuation ? String(req.query.continuation) : '';
  const album = token
    ? await musicScraper.musicAlbum(id, 1, token)
    : await cachedMusicAlbum(id, token);
  res.json({ success: true, album });
}));

router.get('/music/playlist', asyncHandler(async (req, res) => {
  const id = requireQuery(req.query.id, 'id');
  const token = req.query.continuation ? String(req.query.continuation) : '';
  const playlist = token
    ? await musicScraper.musicPlaylist(id, 1, token)
    : await cachedMusicPlaylist(id, token);
  res.json({ success: true, playlist });
}));

router.get('/music/home', asyncHandler(async (req, res) => {
  const data = await cachedMusicHome();
  res.json({ success: true, ...data });
}));

router.get('/music/explore', asyncHandler(async (req, res) => {
  const data = await cachedMusicExplore();
  res.json({ success: true, ...data });
}));

router.get('/music/charts', asyncHandler(async (req, res) => {
  const data = await cachedMusicCharts();
  res.json({ success: true, ...data });
}));

router.get('/music/moods', asyncHandler(async (req, res) => {
  const data = await cachedMusicMoods();
  res.json({ success: true, ...data });
}));

router.get('/music/mood', asyncHandler(async (req, res) => {
  const browseId = requireQuery(req.query.browseId, 'browseId');
  const params = requireQuery(req.query.params, 'params');
  const data = await cachedMusicMood(browseId, params);
  res.json({ success: true, ...data });
}));

router.get('/music/stream', asyncHandler(async (req, res) => {
  const id = extractVideoId(requireQuery(req.query.id || req.query.v, 'id'));
  if (!id) throw new HttpError('invalid video id or url', 400);
  const track = await cachedMusicStream(id);
  res.json({ success: true, track });
}));

router.get('/music/audio', asyncHandler(async (req, res) => {
  const id = extractVideoId(requireQuery(req.query.id || req.query.v, 'id'));
  if (!id) throw new HttpError('invalid video id or url', 400);
  const track = await cachedMusicStream(id);
  res.json({
    success: true,
    track: {
      id: track.id,
      title: track.title,
      author: track.author,
      duration: track.duration,
      durationSeconds: track.durationSeconds,
      expiresInSeconds: track.expiresInSeconds,
      expiresAt: track.expiresAt,
      best: track.bestAudio,
      audio: track.audio,
      serverAbrStreamingUrl: track.serverAbrStreamingUrl
    }
  });
}));

router.get('/music/lyrics', asyncHandler(async (req, res) => {
  const id = extractVideoId(requireQuery(req.query.id || req.query.v, 'id'));
  if (!id) throw new HttpError('invalid video id or url', 400);
  const title = req.query.title ? String(req.query.title).slice(0, 150) : '';
  const artist = req.query.artist ? String(req.query.artist).slice(0, 150) : '';
  const duration = req.query.duration ? Number(req.query.duration) : null;
  const data = await cachedMusicLyrics(id, title, artist, duration);
  res.json({ success: true, ...data });
}));

router.get('/music/radio', asyncHandler(async (req, res) => {
  const id = extractVideoId(requireQuery(req.query.id || req.query.v, 'id'));
  if (!id) throw new HttpError('invalid video id or url', 400);
  const data = await cachedMusicRadio(id);
  res.json({ success: true, ...data });
}));

function pickFormatFromStream(stream, quality = 'high', preferMp4 = false) {
  const audioList = (stream.audio ?? []).filter((f) => f.url);
  if (!audioList.length) throw new HttpError('no playable audio stream found', 404);
  const pool = preferMp4
    ? (audioList.filter((f) => f.mimeType?.includes('audio/mp4')).length
      ? audioList.filter((f) => f.mimeType?.includes('audio/mp4'))
      : audioList)
    : audioList;
  const sorted = [...pool].sort((a, b) => (a.bitrate ?? 0) - (b.bitrate ?? 0));
  if (quality === 'low') return sorted[0];
  if (quality === 'medium' && sorted.length > 1) return sorted[Math.floor((sorted.length - 1) / 2)];
  return sorted[sorted.length - 1];
}

router.get('/music/proxy-stream', asyncHandler(async (req, res) => {
  const id = extractVideoId(requireQuery(req.query.id || req.query.v, 'id'));
  if (!id) throw new HttpError('invalid video id or url', 400);
  const quality = ['high', 'medium', 'low'].includes(req.query.quality) ? req.query.quality : 'high';
  const preferMp4 = req.query.format === 'mp4';

  let streamData = await cachedMusicStream(id);
  let format = pickFormatFromStream(streamData, quality, preferMp4);

  const rangeHeader = req.headers.range;
  const buildUpstreamHeaders = () => {
    const h = {
      'User-Agent': 'com.google.ios.youtube/21.03.38 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
      Accept: '*/*'
    };
    if (rangeHeader) h.Range = rangeHeader;
    return h;
  };

  let upstream = await fetch(format.url, { headers: buildUpstreamHeaders() });
  if (upstream.status === 403 || upstream.status === 410) {
    streamData = await musicScraper.musicStream(id);
    cache.set(`mstream|${id}`, streamData, 60 * 60 * 1000);
    format = pickFormatFromStream(streamData, quality, preferMp4);
    upstream = await fetch(format.url, { headers: buildUpstreamHeaders() });
  }

  if (!upstream.ok && upstream.status !== 206) {
    throw new UpstreamError(`upstream audio stream returned HTTP ${upstream.status}`);
  }

  const contentType = upstream.headers.get('content-type') || (format.mimeType ? format.mimeType.split(';')[0] : 'audio/mp4');
  const contentLength = upstream.headers.get('content-length');
  const contentRange = upstream.headers.get('content-range');

  res.status(upstream.status === 206 ? 206 : 200);
  res.setHeader('Content-Type', contentType);
  res.setHeader('Accept-Ranges', 'bytes');
  res.setHeader('Cache-Control', 'public, max-age=1800');
  if (contentLength) res.setHeader('Content-Length', contentLength);
  if (contentRange) res.setHeader('Content-Range', contentRange);

  if (req.method === 'HEAD') {
    res.end();
    return;
  }

  if (!upstream.body) {
    res.end();
    return;
  }

  const nodeStream = Readable.fromWeb(upstream.body);
  req.on('close', () => {
    if (!nodeStream.destroyed) nodeStream.destroy();
  });
  nodeStream.on('error', () => {
    if (!res.headersSent) res.status(502).end();
    else res.end();
  });
  nodeStream.pipe(res);
}));

const ALLOWED_ARTWORK_HOSTS = new Set([
  'i.ytimg.com',
  'lh3.googleusercontent.com',
  'yt3.ggpht.com',
  'yt3.googleusercontent.com',
  'music.youtube.com'
]);

router.get('/music/artwork', asyncHandler(async (req, res) => {
  const rawUrl = requireQuery(req.query.url, 'url');
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    throw new HttpError('invalid artwork url', 400);
  }
  if (!['https:', 'http:'].includes(parsed.protocol) || !ALLOWED_ARTWORK_HOSTS.has(parsed.hostname.toLowerCase())) {
    throw new HttpError('artwork host not allowed', 403);
  }
  const upstream = await fetch(parsed.toString(), {
    headers: { 'User-Agent': 'Mozilla/5.0' }
  });
  if (!upstream.ok || !upstream.body) {
    throw new UpstreamError(`artwork fetch failed (${upstream.status})`);
  }
  res.setHeader('Content-Type', upstream.headers.get('content-type') || 'image/jpeg');
  res.setHeader('Cache-Control', 'public, max-age=86400');
  const nodeStream = Readable.fromWeb(upstream.body);
  nodeStream.pipe(res);
}));

const DOWNLOAD_TYPES = ['video', 'audio'];

async function runDownloader(fn, req, res) {
  const url = requireQuery(req.query.url || req.query.id || req.query.v, 'url');
  const videoId = extractVideoId(url);
  if (!videoId) throw new HttpError('invalid youtube url or video id', 400);
  const type = DOWNLOAD_TYPES.includes(req.query.type) ? req.query.type : 'video';
  const quality = req.query.quality ? String(req.query.quality) : null;
  const result = await fn(url, { type, quality });
  res.json({ success: true, ...result });
}

router.get('/download/v1', downloadRateLimit, asyncHandler(async (req, res) => {
  await runDownloader(downloadV1, req, res);
}));

router.get('/download/v2', downloadRateLimit, asyncHandler(async (req, res) => {
  await runDownloader(downloadV2, req, res);
}));

router.get('/download/v3', downloadRateLimit, asyncHandler(async (req, res) => {
  await runDownloader(downloadV3, req, res);
}));

router.get('/download/all', downloadRateLimit, asyncHandler(async (req, res) => {
  const url = requireQuery(req.query.url || req.query.id || req.query.v, 'url');
  const videoId = extractVideoId(url);
  if (!videoId) throw new HttpError('invalid youtube url or video id', 400);
  const type = DOWNLOAD_TYPES.includes(req.query.type) ? req.query.type : 'video';

  const failures = [];
  for (const [engine, fn] of [['v1', downloadV1], ['v2', downloadV2], ['v3', downloadV3]]) {
    try {
      const result = await fn(url, { type, quality: null });
      return res.json({ success: true, winner: engine, result, failures });
    } catch (err) {
      failures.push({ engine, error: err.message });
    }
  }
  throw new UpstreamError('all download engines failed', failures);
}));

export default router;
