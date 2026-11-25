import { httpJson, HttpError } from '../lib/http.js';
import { Ytdl } from '@distube/ytdl-core';

const ytdlClient = new Ytdl();

function ytdlGetInfo(videoId) {
  return ytdlClient.getInfo(`https://www.youtube.com/watch?v=${videoId}`);
}

function mapYtdlFormat(format) {
  return {
    itag: format.itag ?? null,
    mimeType: format.mimeType ?? null,
    codecs: format.mimeType?.match(/codecs="([^"]+)"/)?.[1] ?? null,
    bitrate: format.bitrate ?? null,
    averageBitrate: format.averageBitrate ?? null,
    quality: format.quality ?? null,
    audioQuality: format.audioQuality ?? null,
    audioSampleRate: format.audioSampleRate ? Number(format.audioSampleRate) : null,
    audioChannels: format.audioChannels ?? null,
    qualityLabel: format.qualityLabel ?? null,
    width: format.width ?? null,
    height: format.height ?? null,
    fps: format.fps ?? null,
    contentLength: format.contentLength ? Number(format.contentLength) : null,
    approxDurationMs: format.approxDurationMs ? Number(format.approxDurationMs) : null,
    url: format.url ?? null
  };
}

const MUSIC_API = 'https://music.youtube.com/youtubei/v1';
const YT_API = 'https://www.youtube.com/youtubei/v1';
const VERSION = '1.20261117.06.00';
const IOS_VERSION = '21.03.38';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
const IOS_UA = 'com.google.ios.youtube/21.03.38 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)';

const CONTEXT = {
  client: {
    clientName: 'WEB_REMIX',
    clientVersion: VERSION,
    hl: 'en',
    gl: 'ID',
    userAgent: UA,
    platform: 'DESKTOP',
    browserName: 'Chrome',
    browserVersion: '124.0.0.0',
    osName: 'Windows',
    osVersion: '10.0'
  },
  user: { lockedSafetyMode: false },
  request: { useSsl: true }
};

const IOS_CONTEXT = {
  client: {
    clientName: 'IOS',
    clientVersion: IOS_VERSION,
    deviceModel: 'iPhone16,2',
    hl: 'en',
    gl: 'ID',
    userAgent: IOS_UA,
    osName: 'iPhone',
    osVersion: '18.1.0.22B83'
  },
  user: { lockedSafetyMode: false },
  request: { useSsl: true }
};

const IOS_HEADERS = {
  'X-YouTube-Client-Name': '5',
  'X-YouTube-Client-Version': IOS_VERSION,
  'User-Agent': IOS_UA
};

const FILTERS = {
  all: '',
  songs: 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D',
  videos: 'EgWKAQIQAWoKEAkQChAFEAMQBA%3D%3D',
  albums: 'EgWKAQIYAWoKEAkQChAFEAMQBA%3D%3D',
  artists: 'EgWKAQIgAWoKEAkQChAFEAMQBA%3D%3D',
  playlists: 'EgWKAQIoAWoKEAkQChAFEAMQBA%3D%3D',
  community_playlists: 'EgeKAQQoAEABahIQBRADEAkQBBAKEBUQDhAQEBE%3D',
  featured_playlists: 'EgeKAQQoADgBahIQBRADEAkQBBAKEBUQDhAQEBE%3D',
  profiles: 'EgWKAQJYAWoSEAUQAxAJEAQQChAVEA4QEBAR',
  episodes: 'EgWKAQJIAWoSEAUQAxAJEAQQChAVEA4QEBAR',
  podcasts: 'EgWKAQJQAWoSEAUQAxAJEAQQChAVEA4QEBAR'
};

async function request(endpoint, body, options = {}) {
  const res = await httpJson(`${MUSIC_API}/${endpoint}?prettyPrint=false`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-YouTube-Client-Name': '67',
      'X-YouTube-Client-Version': VERSION,
      Origin: 'https://music.youtube.com',
      Referer: 'https://music.youtube.com/',
      'User-Agent': UA,
      ...options.headers
    },
    body: JSON.stringify({ context: options.context ?? CONTEXT, ...body }),
    retries: 1,
    tag: `music-${endpoint}`
  });
  return res;
}

function getPlayer(videoId) {
  return request('player', {
    videoId,
    contentCheckOk: true,
    racyCheckOk: true,
    playbackContext: { contentPlaybackContext: { html5Preference: 'HTML5_PREF_WANTS' } }
  }, { context: IOS_CONTEXT, headers: IOS_HEADERS });
}

function ensurePlayable(player) {
  const playability = player?.playabilityStatus ?? {};
  if (!playability.status || playability.status === 'OK') return;
  const error = new Error(playability.reason ?? `Playability status ${playability.status}`);
  const codes = { UNPLAYABLE: 403, LOGIN_REQUIRED: 403, ERROR: 404, LIVE_STREAM_OFFLINE: 404 };
  throw new HttpError(error.message, codes[playability.status] ?? 502);
}

const text = (value) => value?.runs?.map((run) => run.text ?? '').join('') ?? value?.simpleText ?? '';
const pageTypeOf = (browse) => browse?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig?.pageType ?? null;
const videoTypeOf = (watch) => watch?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType ?? null;
const thumbs = (renderer) => (
  renderer?.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails
  ?? renderer?.thumbnail?.croppedSquareThumbnailRenderer?.thumbnail?.thumbnails
  ?? renderer?.thumbnail?.thumbnails
  ?? renderer?.thumbnailRenderer?.musicThumbnailRenderer?.thumbnail?.thumbnails
  ?? []
).map(({ url, width, height }) => ({ url, width, height }));

function continuation(value) {
  const next = value?.continuations?.[0];
  const token = next?.nextContinuationData?.continuation ?? next?.nextRadioContinuationData?.continuation;
  if (token) return token;
  const items = value?.contents ?? value?.items ?? [];
  return items.at(-1)?.continuationItemRenderer?.continuationEndpoint?.continuationCommand?.token ?? null;
}

const yearOf = (value) => {
  const match = value?.match(/\b(19|20)\d{2}\b/);
  return match ? Number(match[0]) : null;
};

const statOf = (values) => values
  .map((value) => value?.match(/([\d.,]+[KMB]?)\s+(plays|views|monthly audience|subscribers)/i)?.[0])
  .find(Boolean) ?? null;

function artistsOf(runs = []) {
  const seen = new Set();
  return runs.flatMap((run) => {
    const browse = run.navigationEndpoint?.browseEndpoint;
    const name = run.text?.trim();
    if (pageTypeOf(browse) !== 'MUSIC_PAGE_TYPE_ARTIST' || !name || seen.has(browse.browseId)) return [];
    seen.add(browse.browseId);
    return [{ name, id: browse.browseId }];
  });
}

function albumOf(runs = []) {
  const run = runs.find((item) => pageTypeOf(item.navigationEndpoint?.browseEndpoint) === 'MUSIC_PAGE_TYPE_ALBUM');
  return run ? { name: run.text, id: run.navigationEndpoint.browseEndpoint.browseId } : null;
}

function durationOf(values) {
  const match = values.map((value) => value?.match(/\b(\d{1,2}):(\d{2})\b/)).find(Boolean);
  return match
    ? { text: match[0], seconds: Number(match[1]) * 60 + Number(match[2]) }
    : { text: null, seconds: null };
}

function formatDuration(seconds) {
  if (!seconds || Number.isNaN(Number(seconds))) return null;
  const total = Number(seconds);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const secs = total % 60;
  return hours
    ? `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
    : `${minutes}:${String(secs).padStart(2, '0')}`;
}

function parseStreamFormat(format) {
  return {
    itag: format.itag ?? null,
    mimeType: format.mimeType ?? null,
    codecs: format.mimeType?.match(/codecs="([^"]+)"/)?.[1] ?? null,
    bitrate: format.bitrate ?? null,
    averageBitrate: format.averageBitrate ?? null,
    quality: format.quality ?? null,
    audioQuality: format.audioQuality ?? null,
    audioSampleRate: format.audioSampleRate ? Number(format.audioSampleRate) : null,
    audioChannels: format.audioChannels ?? null,
    qualityLabel: format.qualityLabel ?? null,
    width: format.width ?? null,
    height: format.height ?? null,
    fps: format.fps ?? null,
    contentLength: format.contentLength ? Number(format.contentLength) : null,
    approxDurationMs: format.approxDurationMs ? Number(format.approxDurationMs) : null,
    url: format.url ?? null
  };
}

function parseStreamingData(streamingData) {
  const formats = [
    ...(streamingData?.formats ?? []),
    ...(streamingData?.adaptiveFormats ?? [])
  ];
  const expiresInSeconds = streamingData?.expiresInSeconds ? Number(streamingData.expiresInSeconds) : null;
  const audio = formats.filter((format) => format.mimeType?.startsWith('audio/')).map(parseStreamFormat);
  const video = formats.filter((format) => format.mimeType?.startsWith('video/')).map(parseStreamFormat);
  const best = (list) => list.reduce((top, format) => (!top || (format.bitrate ?? 0) > (top.bitrate ?? 0) ? format : top), null);
  return {
    expiresInSeconds,
    expiresAt: expiresInSeconds ? new Date(Date.now() + expiresInSeconds * 1000).toISOString() : null,
    bestAudio: best(audio),
    bestVideo: best(video),
    audio,
    video,
    serverAbrStreamingUrl: streamingData?.serverAbrStreamingUrl ?? null
  };
}

function detectType({ pageType, videoType, subtitle }) {
  if (videoType === 'MUSIC_VIDEO_TYPE_ATV') return 'song';
  if (videoType === 'MUSIC_VIDEO_TYPE_OMV' || videoType === 'MUSIC_VIDEO_TYPE_UGC') return 'video';
  const label = subtitle.split('•')[0].trim().toLowerCase();
  if (pageType === 'MUSIC_PAGE_TYPE_ALBUM') {
    return label === 'single' || label === 'ep' ? label : 'album';
  }
  const types = {
    MUSIC_PAGE_TYPE_ARTIST: 'artist',
    MUSIC_PAGE_TYPE_PLAYLIST: 'playlist',
    MUSIC_PAGE_TYPE_USER_CHANNEL: 'profile',
    MUSIC_PAGE_TYPE_PODCAST: 'podcast',
    MUSIC_PAGE_TYPE_NON_MUSIC_AUDIO_TRACK_PAGE: 'episode'
  };
  if (types[pageType]) return types[pageType];
  const known = ['song', 'video', 'album', 'single', 'ep', 'playlist', 'artist', 'profile', 'podcast', 'episode'];
  return known.includes(label) ? label : 'unknown';
}

function buildUrl({ videoId, browseId, playlistId } = {}) {
  if (videoId) return `https://music.youtube.com/watch?v=${videoId}`;
  if (playlistId) return `https://music.youtube.com/playlist?list=${playlistId}`;
  if (browseId?.startsWith('VL')) return `https://music.youtube.com/playlist?list=${browseId.slice(2)}`;
  if (browseId?.startsWith('UC')) return `https://music.youtube.com/channel/${browseId}`;
  return browseId ? `https://music.youtube.com/browse/${browseId}` : null;
}

function parseHeader(header) {
  if (!header) return null;
  const subtitle = text(header.subtitle);
  const secondSubtitle = text(header.secondSubtitle);
  const track = secondSubtitle.match(/([\d,]+)\s+(?:songs?|tracks?|episodes?|videos?)/i);
  const plays = secondSubtitle.match(/([\d.,]+[KMB]?)\s+(?:views?|plays?)/i);
  const duration = secondSubtitle.match(/((?:\d+\s+)?(?:hours?|minutes?|seconds?)(?:,\s*)?)+/i);
  return {
    title: text(header.title),
    subtitle,
    type: subtitle.split('•')[0].trim() || 'Artist',
    year: yearOf(subtitle),
    trackCount: track ? Number(track[1].replace(/,/g, '')) : null,
    plays: plays?.[0] ?? null,
    duration: duration?.[0].trim() ?? null,
    description: text(header.description) || text(header.description?.musicDescriptionShelfRenderer?.description),
    subscribers: text(header.subscriptionButton?.subscribeButtonRenderer?.subscriberCountText) || null,
    author: header.facepile?.avatarStackViewModel?.rendererContext?.accessibilityContext?.label ?? null,
    artists: artistsOf(header.straplineTextOne?.runs ?? []),
    thumbnails: thumbs(header)
  };
}

function parseResponsiveItem(item) {
  const columns = (item.flexColumns ?? []).map((column) => column.musicResponsiveListItemFlexColumnRenderer?.text);
  const flex = columns.map(text);
  const fixed = (item.fixedColumns ?? []).map((column) => text(column.musicResponsiveListItemFlexColumnRenderer?.text));
  const runs = columns.flatMap((column) => column?.runs ?? []);
  const play = item.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint;
  const watch = play?.watchEndpoint
    ?? item.navigationEndpoint?.watchEndpoint
    ?? runs.find((run) => run.navigationEndpoint?.watchEndpoint)?.navigationEndpoint?.watchEndpoint
    ?? null;
  const browse = item.navigationEndpoint?.browseEndpoint
    ?? runs.find((run) => run.navigationEndpoint?.browseEndpoint)?.navigationEndpoint?.browseEndpoint
    ?? null;
  const subtitle = flex[1] ?? '';
  const duration = durationOf([...flex, ...fixed]);
  const playlistId = play?.watchPlaylistEndpoint?.playlistId ?? watch?.playlistId ?? null;
  return {
    type: detectType({ pageType: pageTypeOf(browse), videoType: videoTypeOf(watch), subtitle }),
    id: watch?.videoId ?? browse?.browseId ?? playlistId,
    title: flex[0] ?? '',
    subtitle,
    artists: artistsOf(runs),
    album: albumOf(runs),
    duration: duration.text,
    durationSeconds: duration.seconds,
    plays: statOf([...flex, ...fixed]),
    year: yearOf(subtitle),
    index: watch?.index ?? null,
    thumbnails: thumbs(item),
    url: buildUrl({ videoId: watch?.videoId, browseId: browse?.browseId, playlistId }),
    explicit: (item.badges ?? []).some((badge) => badge.musicInlineBadgeRenderer?.icon?.iconType === 'MUSIC_EXPLICIT_BADGE')
  };
}

function parseTwoRowItem(item) {
  const navigation = item.navigationEndpoint
    ?? item.title?.runs?.find((run) => run.navigationEndpoint)?.navigationEndpoint
    ?? null;
  const browse = navigation?.browseEndpoint ?? null;
  const watch = navigation?.watchEndpoint ?? null;
  const subtitle = text(item.subtitle);
  const runs = item.subtitle?.runs ?? [];
  const duration = durationOf([subtitle]);
  return {
    type: detectType({ pageType: pageTypeOf(browse), videoType: videoTypeOf(watch), subtitle }),
    id: watch?.videoId ?? browse?.browseId ?? null,
    title: text(item.title),
    subtitle,
    artists: artistsOf(runs),
    album: albumOf(runs),
    duration: duration.text,
    durationSeconds: duration.seconds,
    plays: statOf([subtitle]),
    year: yearOf(subtitle),
    thumbnails: thumbs(item),
    url: buildUrl({ videoId: watch?.videoId, browseId: browse?.browseId }),
    explicit: (item.badges ?? []).some((badge) => badge.musicInlineBadgeRenderer?.icon?.iconType === 'MUSIC_EXPLICIT_BADGE')
  };
}

function parseCardShelf(item) {
  const navigation = item.title?.runs?.find((run) => run.navigationEndpoint)?.navigationEndpoint ?? null;
  const browse = navigation?.browseEndpoint ?? null;
  const watch = navigation?.watchEndpoint ?? null;
  const subtitle = text(item.subtitle);
  return {
    type: detectType({ pageType: pageTypeOf(browse), videoType: videoTypeOf(watch), subtitle }),
    id: watch?.videoId ?? browse?.browseId ?? null,
    title: text(item.title),
    subtitle,
    artists: artistsOf(item.subtitle?.runs ?? []),
    year: yearOf(subtitle),
    thumbnails: thumbs(item),
    url: buildUrl({ videoId: watch?.videoId, browseId: browse?.browseId }),
    items: (item.contents ?? []).map(parseItem).filter(Boolean)
  };
}

function parseNavigationButton(item) {
  const browse = item.clickCommand?.browseEndpoint ?? null;
  return {
    type: 'navigation',
    id: browse?.browseId ?? null,
    title: text(item.buttonText),
    params: browse?.params ?? null,
    url: buildUrl({ browseId: browse?.browseId })
  };
}

function parsePlaylistPanelItem(item) {
  const subtitle = text(item.longBylineText);
  const duration = durationOf([text(item.lengthText)]);
  const watch = item.navigationEndpoint?.watchEndpoint ?? null;
  return {
    type: detectType({ videoType: videoTypeOf(watch), subtitle }),
    id: item.videoId ?? null,
    title: text(item.title),
    subtitle,
    artists: artistsOf(item.longBylineText?.runs ?? []),
    album: albumOf(item.longBylineText?.runs ?? []),
    duration: duration.text,
    durationSeconds: duration.seconds,
    year: yearOf(subtitle),
    thumbnails: thumbs({ thumbnail: { thumbnails: item.thumbnail?.thumbnails } }),
    url: buildUrl({ videoId: item.videoId })
  };
}

function parseItem(renderer) {
  if (!renderer) return null;
  if (renderer.musicResponsiveListItemRenderer) return parseResponsiveItem(renderer.musicResponsiveListItemRenderer);
  if (renderer.musicTwoRowItemRenderer) return parseTwoRowItem(renderer.musicTwoRowItemRenderer);
  if (renderer.musicCardShelfRenderer) return parseCardShelf(renderer.musicCardShelfRenderer);
  if (renderer.musicNavigationButtonRenderer) return parseNavigationButton(renderer.musicNavigationButtonRenderer);
  if (renderer.playlistPanelVideoRenderer) return parsePlaylistPanelItem(renderer.playlistPanelVideoRenderer);
  return null;
}

function sectionLists(data) {
  const root = data?.contents ?? {};
  const tabs = root.singleColumnBrowseResultsRenderer?.tabs
    ?? root.twoColumnBrowseResultsRenderer?.tabs
    ?? root.tabbedSearchResultsRenderer?.tabs
    ?? [];
  const lists = [
    root.sectionListRenderer,
    ...tabs.map((tab) => tab.tabRenderer?.content?.sectionListRenderer),
    root.twoColumnBrowseResultsRenderer?.secondaryContents?.sectionListRenderer
  ];
  return [...new Set(lists.filter(Boolean))];
}

function findHeader(data) {
  const root = data?.contents ?? {};
  const tabs = root.singleColumnBrowseResultsRenderer?.tabs
    ?? root.twoColumnBrowseResultsRenderer?.tabs
    ?? [];
  for (const tab of tabs) {
    for (const section of tab.tabRenderer?.content?.sectionListRenderer?.contents ?? []) {
      const key = Object.keys(section)[0];
      if (key === 'musicResponsiveHeaderRenderer' || key === 'musicDetailHeaderRenderer') {
        return section[key];
      }
    }
  }
  return data.header?.musicImmersiveHeaderRenderer
    ?? data.header?.musicVisualHeaderRenderer
    ?? null;
}

function parseSections(data, fallbackTitle = '') {
  const sections = [];
  for (const list of sectionLists(data)) {
    for (const section of list.contents ?? []) {
      const key = Object.keys(section)[0];
      const value = section[key];
      if (key === 'musicCarouselShelfRenderer') {
        const items = (value.contents ?? []).map(parseItem).filter(Boolean);
        if (!items.length) continue;
        sections.push({
          title: text(value.header?.musicCarouselShelfBasicHeaderRenderer?.title),
          subtitle: text(value.header?.musicCarouselShelfBasicHeaderRenderer?.strapline),
          items
        });
      } else if (key === 'musicShelfRenderer' || key === 'musicPlaylistShelfRenderer') {
        const items = (value.contents ?? []).map(parseItem).filter(Boolean);
        if (!items.length) continue;
        sections.push({
          title: text(value.header?.musicShelfBasicHeaderRenderer?.title) || fallbackTitle,
          items,
          continuation: continuation(value)
        });
      } else if (key === 'gridRenderer' || key === 'itemSectionRenderer') {
        const items = (value.contents ?? value.items ?? []).map(parseItem).filter(Boolean);
        if (!items.length) continue;
        sections.push({ title: fallbackTitle, items });
      } else if (key === 'musicDescriptionShelfRenderer') {
        const description = text(value.description);
        if (!description) continue;
        sections.push({ title: 'About', description, footer: text(value.footer) || null });
      }
    }
  }
  return sections;
}

function parseSearchResults(data) {
  let topResult = null;
  let token = null;
  const results = [];
  for (const list of sectionLists(data)) {
    for (const section of list.contents ?? []) {
      const key = Object.keys(section)[0];
      const value = section[key];
      if (key === 'musicCardShelfRenderer') {
        topResult = parseCardShelf(value);
      } else if (key === 'musicShelfRenderer' || key === 'musicPlaylistShelfRenderer') {
        results.push(...(value.contents ?? []).map(parseItem).filter(Boolean));
        token ??= continuation(value);
      } else if (key === 'itemSectionRenderer') {
        results.push(...(value.contents ?? []).map(parseItem).filter(Boolean));
      }
    }
  }
  return { topResult, results, continuation: token };
}

function parseContinuation(data) {
  const shelf = data.continuationContents?.musicPlaylistShelfContinuation
    ?? data.continuationContents?.musicShelfContinuation;
  if (shelf) {
    return {
      items: (shelf.contents ?? []).map(parseItem).filter(Boolean),
      continuation: continuation(shelf)
    };
  }
  const items = data.onResponseReceivedActions?.find((action) => action.appendContinuationItemsAction)?.appendContinuationItemsAction?.continuationItems;
  return items
    ? { items: items.map(parseItem).filter(Boolean), continuation: continuation({ contents: items }) }
    : null;
}

const getTabPageType = (tab) => pageTypeOf(tab?.tabRenderer?.endpoint?.browseEndpoint);

async function getLyrics(browseId) {
  const data = await request('browse', { browseId });
  const shelf = (data.contents?.sectionListRenderer?.contents ?? [])
    .find((section) => section.musicDescriptionShelfRenderer)?.musicDescriptionShelfRenderer;
  return shelf ? { text: text(shelf.description), source: text(shelf.footer) || null } : null;
}

async function getRelated(browseId) {
  const data = await request('browse', { browseId });
  return parseSections(data, 'Related').flatMap((section) => section.items ?? []);
}

export async function musicHome() {
  const data = await request('browse', { browseId: 'FEmusic_home' });
  return { sections: parseSections(data, 'Home') };
}

export async function musicExplore() {
  const data = await request('browse', { browseId: 'FEmusic_explore' });
  return { sections: parseSections(data, 'Browse') };
}

export async function musicCharts() {
  const data = await request('browse', { browseId: 'FEmusic_charts' });
  return { sections: parseSections(data, 'Charts') };
}

export async function musicMoods() {
  const data = await request('browse', { browseId: 'FEmusic_moods_and_genres' });
  const moods = [];
  for (const list of sectionLists(data)) {
    for (const section of list.contents ?? []) {
      const grid = section.gridRenderer;
      if (!grid) continue;
      for (const item of grid.items ?? []) {
        const btn = item.musicNavigationButtonRenderer;
        if (!btn) continue;
        const browse = btn.clickCommand?.browseEndpoint ?? null;
        moods.push({
          name: text(btn.buttonText) || null,
          browseId: browse?.browseId ?? null,
          params: browse?.params ?? null
        });
      }
    }
  }
  return { total: moods.length, moods };
}

export async function musicMoodPlaylists(browseId, params) {
  const data = await request('browse', { browseId, params });
  return { sections: parseSections(data, 'Mood') };
}

export async function musicSearch(query, filter = 'all', page = 1, token = '') {
  if (!query && !token) throw new HttpError('query is required', 400);
  const params = FILTERS[filter];
  if (params === undefined) {
    throw new HttpError(`Unknown filter: ${filter}. available: ${Object.keys(FILTERS).filter((k) => k !== 'all').join(', ')}`, 400);
  }
  const data = await request('search', token ? { continuation: token } : { query, ...(params ? { params } : {}) });
  if (token) {
    const parsed = parseContinuation(data);
    return {
      query,
      filter,
      page,
      results: parsed?.items ?? [],
      continuation: parsed?.continuation ?? null
    };
  }
  const parsed = parseSearchResults(data);
  return {
    query,
    filter,
    page,
    topResult: parsed.topResult,
    results: parsed.results,
    continuation: parsed.continuation
  };
}

export async function musicSuggestions(query) {
  if (!query) throw new HttpError('query is required', 400);
  const data = await request('music/get_search_suggestions', { input: query });
  const items = (data.contents ?? []).flatMap((section) => (
    section.searchSuggestionsSectionRenderer?.contents ?? []
  ).map((item) => ({ query: text(item.searchSuggestionRenderer?.suggestion) }))).filter((item) => item.query);
  return { query, total: items.length, suggestions: items };
}

export async function musicArtist(browseId) {
  if (!browseId) throw new HttpError('browseId is required', 400);
  const data = await request('browse', { browseId });
  const header = parseHeader(findHeader(data));
  return {
    type: 'artist',
    id: browseId,
    name: header?.title ?? '',
    description: header?.description ?? '',
    subscribers: header?.subscribers ?? null,
    thumbnails: header?.thumbnails ?? [],
    url: buildUrl({ browseId }),
    sections: parseSections(data, 'Songs')
  };
}

export async function musicAlbum(browseId, page = 1, token = '') {
  if (!browseId && !token) throw new HttpError('browseId is required', 400);
  const data = await request('browse', token ? { continuation: token } : { browseId });
  if (token) {
    const parsed = parseContinuation(data);
    return { page, tracks: parsed?.items ?? [], continuation: parsed?.continuation ?? null };
  }
  const header = parseHeader(findHeader(data));
  const sections = parseSections(data, 'Tracks');
  const trackSection = sections.find((section) => section.title === 'Tracks' && section.items?.length)
    ?? sections.find((section) => section.items?.length);
  const tracks = (trackSection?.items ?? []).map((track) => ({
    ...track,
    album: track.album ?? (header ? { name: header.title, id: browseId } : null),
    artists: track.artists?.length ? track.artists : (header?.artists ?? []),
    thumbnails: track.thumbnails?.length ? track.thumbnails : (header?.thumbnails ?? [])
  }));
  const label = header?.type?.toLowerCase();
  const type = label === 'single' ? 'single' : label === 'ep' ? 'ep' : 'album';
  const next = trackSection?.continuation ?? null;
  return {
    type,
    id: browseId,
    title: header?.title ?? '',
    year: header?.year ?? null,
    trackCount: header?.trackCount ?? tracks.length,
    duration: header?.duration ?? null,
    description: header?.description ?? '',
    artists: header?.artists ?? [],
    thumbnails: header?.thumbnails ?? [],
    url: buildUrl({ browseId }),
    tracks,
    sections: sections.filter((section) => section !== trackSection && section.items?.length),
    continuation: next,
    page
  };
}

export async function musicPlaylist(browseId, page = 1, token = '') {
  if (!browseId && !token) throw new HttpError('browseId is required', 400);
  const id = token ? null : (browseId.startsWith('VL') ? browseId : `VL${browseId}`);
  const data = await request('browse', token ? { continuation: token } : { browseId: id });
  if (token) {
    const parsed = parseContinuation(data);
    return { page, tracks: parsed?.items ?? [], continuation: parsed?.continuation ?? null };
  }
  const header = parseHeader(findHeader(data));
  const sections = parseSections(data, 'Tracks');
  const trackSection = sections.find((section) => section.title === 'Tracks' && section.items?.length)
    ?? sections.find((section) => section.items?.length);
  const tracks = trackSection?.items ?? [];
  const next = trackSection?.continuation ?? null;
  return {
    type: 'playlist',
    id: id.slice(2),
    browseId: id,
    title: header?.title ?? '',
    author: header?.author ?? null,
    year: header?.year ?? null,
    plays: header?.plays ?? null,
    trackCount: header?.trackCount ?? tracks.length,
    duration: header?.duration ?? null,
    description: header?.description ?? '',
    thumbnails: header?.thumbnails ?? [],
    url: buildUrl({ browseId: id }),
    tracks,
    sections: sections.filter((section) => section !== trackSection && section.items?.length),
    continuation: next,
    page
  };
}

export async function musicSong(videoId, withLyrics = true) {
  if (!videoId) throw new HttpError('videoId is required', 400);
  let player = null;
  let stream = null;
  try {
    player = await getPlayer(videoId);
    ensurePlayable(player);
  } catch {
    player = null;
  }
  const next = await request('next', { videoId });
  const tabs = next.contents?.singleColumnMusicWatchNextResultsRenderer?.tabbedRenderer?.watchNextTabbedResultsRenderer?.tabs ?? [];
  const queue = (tabs.find((tab) => tab.tabRenderer?.content?.musicQueueRenderer)
    ?.tabRenderer?.content?.musicQueueRenderer?.content?.playlistPanelRenderer?.contents ?? [])
    .map(parseItem)
    .filter(Boolean);
  const current = queue.find((item) => item.id === videoId) ?? queue[0] ?? null;
  const lyricsTab = tabs.find((tab) => getTabPageType(tab) === 'MUSIC_PAGE_TYPE_TRACK_LYRICS');
  const relatedTab = tabs.find((tab) => getTabPageType(tab) === 'MUSIC_PAGE_TYPE_TRACK_RELATED');
  const [lyrics, related] = await Promise.all([
    withLyrics && lyricsTab ? getLyrics(lyricsTab.tabRenderer.endpoint.browseEndpoint.browseId).catch(() => null) : Promise.resolve(null),
    relatedTab ? getRelated(relatedTab.tabRenderer.endpoint.browseEndpoint.browseId).catch(() => []) : Promise.resolve([])
  ]);
  const details = player?.videoDetails ?? {};
  const durationSeconds = details.lengthSeconds ? Number(details.lengthSeconds) : current?.durationSeconds ?? null;
  if (player?.streamingData) {
    stream = parseStreamingData(player.streamingData);
  } else {
    try {
      const fallback = await musicStream(videoId);
      stream = {
        expiresInSeconds: fallback.expiresInSeconds,
        expiresAt: fallback.expiresAt,
        bestAudio: fallback.bestAudio,
        bestVideo: fallback.bestVideo,
        audio: fallback.audio,
        video: fallback.video,
        serverAbrStreamingUrl: fallback.serverAbrStreamingUrl
      };
    } catch {
      stream = { expiresInSeconds: null, expiresAt: null, bestAudio: null, bestVideo: null, audio: [], video: [], serverAbrStreamingUrl: null };
    }
  }
  return {
    type: current?.type ?? 'song',
    id: videoId,
    title: details.title ?? current?.title ?? '',
    artists: current?.artists?.length
      ? current.artists
      : details.author
        ? [{ name: details.author, id: details.channelId ?? null }]
        : [],
    album: current?.album ?? null,
    duration: formatDuration(durationSeconds),
    durationSeconds,
    views: details.viewCount ? Number(details.viewCount) : null,
    thumbnails: details.thumbnail?.thumbnails ?? current?.thumbnails ?? [],
    description: details.shortDescription ?? '',
    tags: details.keywords ?? [],
    isLive: details.isLiveContent ?? false,
    url: buildUrl({ videoId }),
    lyrics,
    related,
    upNext: queue.filter((item) => item.id !== videoId),
    stream
  };
}

export async function musicStream(videoId) {
  if (!videoId) throw new HttpError('videoId is required', 400);
  let player = null;
  try {
    player = await getPlayer(videoId);
    ensurePlayable(player);
  } catch {
    player = null;
  }
  if (!player || !player.videoDetails) {
    try {
      return await ytdlStreamFallback(videoId);
    } catch {
      return await snapytStreamFallback(videoId);
    }
  }
  const details = player.videoDetails ?? {};
  const durationSeconds = details.lengthSeconds ? Number(details.lengthSeconds) : null;
  const streams = parseStreamingData(player.streamingData);
  return {
    id: videoId,
    title: details.title ?? '',
    author: details.author ?? null,
    channelId: details.channelId ?? null,
    duration: formatDuration(durationSeconds),
    durationSeconds,
    views: details.viewCount ? Number(details.viewCount) : null,
    thumbnails: details.thumbnail?.thumbnails ?? [],
    description: details.shortDescription ?? '',
    tags: details.keywords ?? [],
    isLive: details.isLiveContent ?? false,
    isPrivate: details.isPrivate ?? false,
    url: buildUrl({ videoId }),
    ...streams
  };
}

async function ytdlStreamFallback(videoId) {
  const info = await ytdlGetInfo(videoId);
  const details = info.videoDetails ?? {};
  const formats = (info.formats ?? []).filter((f) => f.url);
  const durationSeconds = details.lengthSeconds ? Number(details.lengthSeconds) : null;
  const audio = formats.filter((f) => f.mimeType?.startsWith('audio/')).map(mapYtdlFormat);
  const video = formats.filter((f) => f.mimeType?.startsWith('video/')).map(mapYtdlFormat);
  const best = (list) => list.reduce((top, format) => (!top || (format.bitrate ?? 0) > (top.bitrate ?? 0) ? format : top), null);
  const expiresInSeconds = info.playerResponse?.streamingData?.expiresInSeconds
    ? Number(info.playerResponse.streamingData.expiresInSeconds)
    : 21540;
  return {
    id: videoId,
    title: details.title ?? '',
    author: details.author?.name ?? null,
    channelId: details.channelId ?? null,
    duration: formatDuration(durationSeconds),
    durationSeconds,
    views: details.viewCount ? Number(details.viewCount) : null,
    thumbnails: details.thumbnails ?? [],
    description: details.shortDescription ?? '',
    tags: details.keywords ?? [],
    isLive: details.isLiveContent ?? false,
    isPrivate: details.isPrivate ?? false,
    url: buildUrl({ videoId }),
    expiresInSeconds,
    expiresAt: new Date(Date.now() + expiresInSeconds * 1000).toISOString(),
    bestAudio: best(audio),
    bestVideo: best(video),
    audio,
    video,
    serverAbrStreamingUrl: null
  };
}

async function snapytStreamFallback(videoId) {
  const { downloadV3 } = await import('./downloader-v3.js');
  const result = await downloadV3(videoId, { type: 'audio', quality: null });
  const url = result.download?.url ?? null;
  if (!url) throw new HttpError('no audio stream available', 502);
  const formats = [result.download].filter(Boolean).map((item) => ({
    itag: null,
    mimeType: item.contentType ?? `audio/${result.resolved?.extension ?? 'mp3'}`,
    codecs: null,
    bitrate: result.resolved?.bitrateKbps ? result.resolved.bitrateKbps * 1000 : null,
    averageBitrate: null,
    quality: null,
    audioQuality: result.resolved?.bitrateKbps ? `AUDIO_QUALITY_${result.resolved.bitrateKbps >= 256 ? 'HIGH' : 'LOW'}` : null,
    audioSampleRate: null,
    audioChannels: null,
    qualityLabel: result.resolved?.label ?? null,
    width: null,
    height: null,
    fps: null,
    contentLength: item.sizeBytes ?? null,
    approxDurationMs: result.durationSeconds ? result.durationSeconds * 1000 : null,
    url: item.url
  }));
  const best = formats.reduce((top, format) => (!top || (format.bitrate ?? 0) > (top.bitrate ?? 0) ? format : top), null);
  return {
    id: videoId,
    title: result.title ?? '',
    author: result.channel?.name ?? null,
    channelId: null,
    duration: result.duration ?? null,
    durationSeconds: result.durationSeconds ?? null,
    views: null,
    thumbnails: result.thumbnail ? [{ url: result.thumbnail, width: null, height: null }] : [],
    description: '',
    tags: [],
    isLive: false,
    isPrivate: false,
    url: buildUrl({ videoId }),
    expiresInSeconds: 3600,
    expiresAt: new Date(Date.now() + 3600 * 1000).toISOString(),
    bestAudio: best,
    bestVideo: null,
    audio: formats,
    video: [],
    serverAbrStreamingUrl: null
  };
}

export async function musicAudio(videoId) {
  const result = await musicStream(videoId);
  return {
    id: result.id,
    title: result.title,
    author: result.author,
    duration: result.duration,
    durationSeconds: result.durationSeconds,
    expiresInSeconds: result.expiresInSeconds,
    expiresAt: result.expiresAt,
    best: result.bestAudio,
    audio: result.audio,
    serverAbrStreamingUrl: result.serverAbrStreamingUrl
  };
}
