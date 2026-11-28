import { Router } from 'express';
import { Readable } from 'node:stream';
import { randomBytes } from 'node:crypto';
import { config, authEnabled, googleOAuthEnabled } from './config.js';
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
import { getRemoteNodeConfig, setRemoteNodeConfig, resetRemoteNodeConfig } from './lib/node-config-store.js';
import authRouter, { resolveBaseUrl } from './auth-routes.js';

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
    name: `${config.serviceName} REST API`,
    service: 'archys-api',
    version: config.appVersion,
    developer: config.developer,
    auth: authEnabled() ? 'API key required' : 'open',
    region: config.defaultRegion
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
    status: 'ok',
    service: config.serviceName,
    version: config.appVersion,
    developer: config.developer,
    uptime: Math.floor(process.uptime()),
    region: config.defaultRegion,
    authRequired: authEnabled(),
    googleOAuthConfigured: googleOAuthEnabled(),
    cache: cache.stats()
  });
});

router.get(['/node/info', '/node/info/'], (req, res) => {
  const baseUrl = resolveBaseUrl(req);
  res.json({
    success: true,
    status: 'online',
    service: config.serviceName,
    version: config.appVersion,
    developer: config.developer,
    region: config.defaultRegion,
    baseUrl,
    authRequired: authEnabled(),
    googleOAuthConfigured: googleOAuthEnabled(),
    callbackUrl: `${baseUrl}/api/auth/google/callback`,
    publicDocs: config.publicDocs,
    uptime: Math.floor(process.uptime())
  });
});

router.get(['/node/config', '/node/config/'], (req, res) => {
  const baseUrl = resolveBaseUrl(req);
  const remote = getRemoteNodeConfig();
  res.json({
    success: true,
    configured: Boolean(remote.serverUrl),
    serverUrl: remote.serverUrl || baseUrl,
    apiKey: remote.apiKey || '',
    defaultUrl: baseUrl,
    note: remote.note || '',
    updatedAt: remote.updatedAt || null
  });
});

function handleSaveNodeConfig(req, res) {
  const baseUrl = resolveBaseUrl(req);
  if (req.body?.reset === true) {
    const cleared = resetRemoteNodeConfig();
    return res.json({
      success: true,
      configured: false,
      serverUrl: baseUrl,
      apiKey: '',
      defaultUrl: baseUrl,
      note: '',
      updatedAt: cleared.updatedAt
    });
  }

  let saved;
  try {
    saved = setRemoteNodeConfig({
      serverUrl: req.body?.serverUrl,
      apiKey: req.body?.apiKey || '',
      note: req.body?.note || ''
    });
  } catch (err) {
    throw new HttpError(err.message || 'invalid node configuration', 400);
  }

  res.json({
    success: true,
    configured: true,
    serverUrl: saved.serverUrl,
    apiKey: saved.apiKey,
    defaultUrl: baseUrl,
    note: saved.note,
    updatedAt: saved.updatedAt
  });
}

// PUT is the canonical method, but many reverse proxies / panels (Pterodactyl port
// forwards, nginx, Cloudflare rules) reject PUT with HTTP 405. POST, PATCH, and
// POST /admin/node-config/publish are accepted so the APK can always publish.
router.all(['/admin/node-config', '/admin/node-config/'], (req, res, next) => {
  if (!['PUT', 'POST', 'PATCH'].includes(req.method)) {
    res.setHeader('Allow', 'PUT, POST, PATCH');
    return res.status(405).json({ success: false, error: 'method not allowed, use PUT or POST' });
  }
  next();
}, adminRateLimit, requireAdminAuth, handleSaveNodeConfig);

router.post(['/admin/node-config/publish', '/admin/node-config/publish/'], adminRateLimit, requireAdminAuth, handleSaveNodeConfig);

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

const HANGUL_INITIALS = [
  'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss',
  '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h'
];
const HANGUL_MEDIALS = [
  'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae',
  'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i'
];
const HANGUL_FINALS = [
  '', 'k', 'k', 'ks', 'n', 'nj', 'nh', 't', 'l', 'lk', 'lm', 'lb',
  'ls', 'lt', 'lp', 'lh', 'm', 'p', 'ps', 't', 't', 'ng', 't', 't',
  'k', 't', 'p', 't'
];

const KANA_MAP = {
  // Hiragana basic & voiced
  'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
  'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
  'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
  'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
  'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
  'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
  'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
  'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
  'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
  'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
  'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
  'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
  'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
  'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
  'わ': 'wa', 'を': 'o', 'ん': 'n',
  'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o',
  'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'ゔ': 'vu',
  // Katakana basic & voiced
  'ア': 'a', 'イ': 'i', 'ウ': 'u', 'エ': 'e', 'オ': 'o',
  'カ': 'ka', 'キ': 'ki', 'ク': 'ku', 'ケ': 'ke', 'コ': 'ko',
  'ガ': 'ga', 'ギ': 'gi', 'グ': 'gu', 'ゲ': 'ge', 'ゴ': 'go',
  'サ': 'sa', 'シ': 'shi', 'ス': 'su', 'セ': 'se', 'ソ': 'so',
  'ザ': 'za', 'ジ': 'ji', 'ズ': 'zu', 'ゼ': 'ze', 'ゾ': 'zo',
  'タ': 'ta', 'チ': 'chi', 'ツ': 'tsu', 'テ': 'te', 'ト': 'to',
  'ダ': 'da', 'ヂ': 'ji', 'ヅ': 'zu', 'デ': 'de', 'ド': 'do',
  'ナ': 'na', 'ニ': 'ni', 'ヌ': 'nu', 'ネ': 'ne', 'ノ': 'no',
  'ハ': 'ha', 'ヒ': 'hi', 'フ': 'fu', 'ヘ': 'he', 'ホ': 'ho',
  'バ': 'ba', 'ビ': 'bi', 'ブ': 'bu', 'ベ': 'be', 'ボ': 'bo',
  'パ': 'pa', 'ピ': 'pi', 'プ': 'pu', 'ペ': 'pe', 'ポ': 'po',
  'マ': 'ma', 'ミ': 'mi', 'ム': 'mu', 'メ': 'me', 'モ': 'mo',
  'ヤ': 'ya', 'ユ': 'yu', 'ヨ': 'yo',
  'ラ': 'ra', 'リ': 'ri', 'ル': 'ru', 'レ': 're', 'ロ': 'ro',
  'ワ': 'wa', 'ヲ': 'o', 'ン': 'n',
  'ァ': 'a', 'ィ': 'i', 'ゥ': 'u', 'ェ': 'e', 'ォ': 'o',
  'ャ': 'ya', 'ュ': 'yu', 'ョ': 'yo', 'ヴ': 'vu'
};

const CYRILLIC_MAP = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
  'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
  'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
  'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya'
};

function romanizeLyricText(input) {
  const text = String(input || '').trim();
  if (!text) return null;
  const hasNonLatin = /[\u3040-\u30FF\uAC00-\uD7A3\u0400-\u04FF\u4E00-\u9FFF]/.test(text);
  if (!hasNonLatin) return null;

  let out = '';
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    const code = ch.charCodeAt(0);

    // Hangul syllable decomposition
    if (code >= 0xac00 && code <= 0xd7a3) {
      const syl = code - 0xac00;
      const ini = Math.floor(syl / 588);
      const med = Math.floor((syl % 588) / 28);
      const fin = syl % 28;
      out += HANGUL_INITIALS[ini] + HANGUL_MEDIALS[med] + HANGUL_FINALS[fin];
      continue;
    }

    // Small tsu (geminate consonant)
    if (ch === 'っ' || ch === 'ッ') {
      const next = KANA_MAP[text[i + 1]] || '';
      if (next && /^[a-z]/.test(next)) out += next[0];
      continue;
    }

    // Prolonged sound mark in Katakana
    if (ch === 'ー') {
      const lastVowel = out.match(/[aeiou]$/i);
      if (lastVowel) out += lastVowel[0];
      continue;
    }

    // Yoon combinations (e.g. きゃ -> kya)
    if (i + 1 < text.length && 'ゃゅょャュョ'.includes(text[i + 1])) {
      const base = KANA_MAP[ch];
      const small = KANA_MAP[text[i + 1]];
      if (base && small) {
        out += base.slice(0, -1) + small;
        i += 1;
        continue;
      }
    }

    if (KANA_MAP[ch]) {
      out += KANA_MAP[ch];
      continue;
    }

    const lower = ch.toLowerCase();
    if (Object.prototype.hasOwnProperty.call(CYRILLIC_MAP, lower)) {
      const mapped = CYRILLIC_MAP[lower];
      out += ch !== lower && mapped ? mapped[0].toUpperCase() + mapped.slice(1) : mapped;
      continue;
    }

    out += ch;
  }

  const normalized = out.replace(/\s+/g, ' ').trim();
  if (!normalized || normalized === text) return null;
  return normalized;
}

async function translateLinesBatch(lines, targetLang) {
  const joined = lines.join('\n');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 4500);
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${encodeURIComponent(targetLang)}&dt=t&q=${encodeURIComponent(joined)}`;
    const upstream = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0' },
      signal: controller.signal
    });
    if (!upstream.ok) return lines.map(() => null);
    const json = await upstream.json();
    const translatedJoined = Array.isArray(json?.[0])
      ? json[0].map((seg) => (Array.isArray(seg) ? seg[0] || '' : '')).join('')
      : '';
    if (!translatedJoined) return lines.map(() => null);
    const split = translatedJoined.split('\n');
    if (split.length === lines.length) {
      return split.map((s) => s.trim() || null);
    }
    return lines.map((_, idx) => (split[idx] ? split[idx].trim() : null));
  } catch {
    return lines.map(() => null);
  } finally {
    clearTimeout(timer);
  }
}

router.post('/music/lyrics-assist', asyncHandler(async (req, res) => {
  const rawLines = Array.isArray(req.body?.lines) ? req.body.lines : null;
  if (!rawLines || rawLines.length === 0) {
    throw new HttpError('lines array is required', 400);
  }
  if (rawLines.length > 120) {
    throw new HttpError('maximum 120 lines allowed per request', 400);
  }

  const cleanLines = rawLines.map((item) => String(item || '').trim().slice(0, 300));
  const targetLang = ['id', 'en'].includes(req.body?.targetLang) ? req.body.targetLang : 'id';
  const wantRomanize = req.body?.romanize !== false;
  const wantTranslate = req.body?.translate === true;

  const cacheKey = `lyrics-assist|${targetLang}|${wantRomanize ? 1 : 0}|${wantTranslate ? 1 : 0}|${cleanLines.join('\u0001')}`;
  const hit = cache.get(cacheKey);
  if (hit) {
    return res.json({ success: true, ...hit });
  }

  let translated = cleanLines.map(() => null);
  if (wantTranslate) {
    const chunkSize = 15;
    const chunks = [];
    for (let i = 0; i < cleanLines.length; i += chunkSize) {
      chunks.push(cleanLines.slice(i, i + chunkSize));
    }
    const results = await Promise.all(
      chunks.map((chunk) => translateLinesBatch(chunk, targetLang))
    );
    translated = results.flat();
  }

  const lines = cleanLines.map((text, idx) => {
    const tr = wantTranslate ? translated[idx] : null;
    const cleanedTr = tr && tr.toLowerCase() !== text.toLowerCase() ? tr : null;
    return {
      text,
      romanized: wantRomanize ? romanizeLyricText(text) : null,
      translated: cleanedTr
    };
  });

  const payload = { targetLang, lines };
  cache.set(cacheKey, payload, 60 * 60 * 1000);
  res.json({ success: true, ...payload });
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
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
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

const listenRooms = new Map();
const LISTEN_ROOM_TTL_MS = 3 * 60 * 60 * 1000;

function cleanupListenRooms() {
  const now = Date.now();
  for (const [code, room] of listenRooms.entries()) {
    if (now - room.updatedAt > LISTEN_ROOM_TTL_MS) {
      listenRooms.delete(code);
    }
  }
}

function generateRoomCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(6);
  let out = '';
  for (let i = 0; i < 6; i += 1) {
    out += alphabet[bytes[i] % alphabet.length];
  }
  return out;
}

router.post('/listen-together/host', (req, res) => {
  cleanupListenRooms();
  let roomCode = generateRoomCode();
  while (listenRooms.has(roomCode)) roomCode = generateRoomCode();
  const hostName = String(req.body?.hostName || 'Host').trim().slice(0, 40) || 'Host';
  const hostToken = randomBytes(16).toString('hex');
  const room = {
    roomCode,
    hostToken,
    hostName,
    members: [hostName],
    track: req.body?.track && typeof req.body.track === 'object' ? req.body.track : null,
    isPlaying: Boolean(req.body?.isPlaying),
    positionMs: Number(req.body?.positionMs) || 0,
    updatedAt: Date.now()
  };
  listenRooms.set(roomCode, room);
  res.json({
    success: true,
    roomCode: room.roomCode,
    hostToken: room.hostToken,
    hostName: room.hostName,
    members: room.members,
    track: room.track,
    isPlaying: room.isPlaying,
    positionMs: room.positionMs,
    updatedAt: room.updatedAt
  });
});

router.post('/listen-together/join', (req, res) => {
  cleanupListenRooms();
  const code = String(req.body?.roomCode || '').trim().toUpperCase();
  if (!code || !listenRooms.has(code)) {
    throw new HttpError('Listen Together room not found or expired', 404);
  }
  const room = listenRooms.get(code);
  const memberName = String(req.body?.memberName || 'Guest').trim().slice(0, 40) || 'Guest';
  if (!room.members.includes(memberName)) {
    room.members = [...room.members.slice(0, 24), memberName];
  }
  room.updatedAt = Date.now();
  res.json({
    success: true,
    roomCode: room.roomCode,
    hostName: room.hostName,
    members: room.members,
    track: room.track,
    isPlaying: room.isPlaying,
    positionMs: room.positionMs,
    updatedAt: room.updatedAt
  });
});

router.get('/listen-together/state', (req, res) => {
  cleanupListenRooms();
  const code = requireQuery(req.query.code || req.query.roomCode, 'code').toUpperCase();
  const room = listenRooms.get(code);
  if (!room) {
    throw new HttpError('Listen Together room not found or expired', 404);
  }
  res.json({
    success: true,
    roomCode: room.roomCode,
    hostName: room.hostName,
    members: room.members,
    track: room.track,
    isPlaying: room.isPlaying,
    positionMs: room.positionMs,
    updatedAt: room.updatedAt
  });
});

router.post('/listen-together/sync', (req, res) => {
  cleanupListenRooms();
  const code = String(req.body?.roomCode || '').trim().toUpperCase();
  const hostToken = String(req.body?.hostToken || '').trim();
  const room = listenRooms.get(code);
  if (!room) {
    throw new HttpError('Listen Together room not found or expired', 404);
  }
  if (!hostToken || room.hostToken !== hostToken) {
    throw new HttpError('Only the host can sync room playback', 403);
  }
  if (req.body?.track !== undefined) {
    room.track = req.body.track && typeof req.body.track === 'object' ? req.body.track : null;
  }
  if (req.body?.isPlaying !== undefined) {
    room.isPlaying = Boolean(req.body.isPlaying);
  }
  if (req.body?.positionMs !== undefined) {
    room.positionMs = Math.max(0, Number(req.body.positionMs) || 0);
  }
  room.updatedAt = Date.now();
  res.json({
    success: true,
    roomCode: room.roomCode,
    updatedAt: room.updatedAt
  });
});

function decodeHtmlEntities(str) {
  return String(str || '')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim();
}

async function resolveExternalPlaylistMetadata(rawUrl) {
  let parsed;
  try {
    parsed = new URL(String(rawUrl || '').trim());
  } catch {
    throw new HttpError('Tautan playlist tidak valid', 400);
  }
  const host = parsed.hostname.toLowerCase();
  const isSpotify = host.includes('spotify.com');
  const isApple = host.includes('music.apple.com');
  if (!isSpotify && !isApple) {
    throw new HttpError('Gunakan tautan playlist/album Spotify atau Apple Music yang valid', 400);
  }

  const resp = await fetch(parsed.toString(), {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
      'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7'
    },
    redirect: 'follow',
    signal: AbortSignal.timeout(12000)
  });

  if (!resp.ok) {
    throw new HttpError(`Gagal membuka tautan (${resp.status})`, 400);
  }
  const html = await resp.text();

  const ogTitleMatch = html.match(/<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i)
    || html.match(/<title>([^<]+)<\/title>/i);
  const title = decodeHtmlEntities(ogTitleMatch ? ogTitleMatch[1] : '')
    .replace(/\s*\|\s*Spotify.*$/i, '')
    .replace(/\s*on Apple Music.*$/i, '')
    || (isSpotify ? 'Playlist Spotify' : 'Playlist Apple Music');

  const tracks = [];
  const seen = new Set();
  const pushTrack = (songTitle, artistName) => {
    const cleanTitle = decodeHtmlEntities(songTitle).slice(0, 140);
    const cleanArtist = decodeHtmlEntities(artistName).slice(0, 120);
    if (!cleanTitle) return;
    const key = `${cleanTitle.toLowerCase()}||${cleanArtist.toLowerCase()}`;
    if (!seen.has(key)) {
      seen.add(key);
      tracks.push({ title: cleanTitle, artist: cleanArtist });
    }
  };

  if (isSpotify) {
    // Spotify embed page exposes clean track list JSON reliably without auth
    try {
      const m = parsed.pathname.match(/\/(playlist|album|track)\/([A-Za-z0-9]+)/);
      if (m) {
        const embedUrl = `https://open.spotify.com/embed/${m[1]}/${m[2]}`;
        const eresp = await fetch(embedUrl, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
          },
          signal: AbortSignal.timeout(12000)
        });
        if (eresp.ok) {
          const ehtml = await eresp.text();
          const nextDataMatch = ehtml.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/i);
          if (nextDataMatch) {
            const data = JSON.parse(nextDataMatch[1]);
            const entity = data?.props?.pageProps?.state?.data?.entity;
            const list = entity?.trackList || entity?.tracks?.items || [];
            for (const row of list) {
              const tTitle = row?.title || row?.track?.name || row?.name;
              const tSub = row?.subtitle
                || (Array.isArray(row?.artists) ? row.artists.map((a) => a.name).join(', ') : '')
                || (Array.isArray(row?.track?.artists) ? row.track.artists.map((a) => a.name).join(', ') : '');
              pushTrack(tTitle, tSub);
            }
          }
        }
      }
    } catch (_) {}
  }

  // Fallback JSON-LD MusicRecording / meta music:song tags (Spotify & Apple Music)
  if (tracks.length === 0) {
    const ldMatches = html.matchAll(/<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi);
    for (const lm of ldMatches) {
      try {
        const parsedJson = JSON.parse(lm[1]);
        const list = Array.isArray(parsedJson?.track)
          ? parsedJson.track
          : (Array.isArray(parsedJson?.tracks) ? parsedJson.tracks : []);
        for (const item of list) {
          const artistObj = item?.byArtist;
          const artistStr = Array.isArray(artistObj)
            ? artistObj.map((a) => a?.name || '').filter(Boolean).join(', ')
            : (artistObj?.name || item?.artist || '');
          pushTrack(item?.name, artistStr);
        }
      } catch (_) {}
    }
  }

  // Apple Music serialized-server-data fallback
  if (isApple && tracks.length === 0) {
    const songMatches = html.matchAll(/"songName":"([^"]{2,120})","artistName":"([^"]{1,100})"/g);
    for (const sm of songMatches) {
      pushTrack(sm[1], sm[2]);
    }
    if (tracks.length === 0) {
      const altMatches = html.matchAll(/"name":"([^"]{2,120})","artistName":"([^"]{1,100})"/g);
      for (const am of altMatches) {
        pushTrack(am[1], am[2]);
      }
    }
  }

  return {
    success: true,
    platform: isSpotify ? 'spotify' : 'apple_music',
    title,
    url: parsed.toString(),
    total: tracks.length,
    tracks: tracks.slice(0, 60)
  };
}

router.get('/music/import-link', asyncHandler(async (req, res) => {
  const url = requireQuery(req.query.url, 'url');
  const data = await resolveExternalPlaylistMetadata(url);
  res.json(data);
}));

router.post('/music/import-link', asyncHandler(async (req, res) => {
  const url = requireQuery(req.body?.url || req.query.url, 'url');
  const data = await resolveExternalPlaylistMetadata(url);
  res.json(data);
}));

export default router;
