import { httpText, extractYtInitialData, deepFind, textOf, bestThumb, UpstreamError } from '../lib/http.js';

const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Accept-Language': 'en-US,en;q=0.9,id;q=0.8'
};

const SEARCH_FILTERS = {
  video: 'EgIQAQ==',
  channel: 'EgIQAg==',
  playlist: 'EgIQAw==',
  movie: 'EgIQBA=='
};

function parseNumber(text) {
  if (!text) return null;
  const match = String(text).match(/([\d.,]+)\s*(K|M|B|rb|jt|ribu|juta)?/i);
  if (!match) return null;
  let value = parseFloat(match[1].replace(/,/g, ''));
  if (!Number.isFinite(value)) return null;
  const suffix = (match[2] || '').toLowerCase();
  if (suffix === 'k' || suffix === 'rb' || suffix === 'ribu') value *= 1e3;
  else if (suffix === 'm' || suffix === 'jt' || suffix === 'juta') value *= 1e6;
  else if (suffix === 'b') value *= 1e9;
  return Math.round(value);
}

function parseDurationSeconds(lengthText) {
  if (!lengthText) return null;
  const match = String(lengthText).match(/^(?:(\d+):)?(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const h = match[1] ? parseInt(match[1], 10) : 0;
  return h * 3600 + parseInt(match[2], 10) * 60 + parseInt(match[3], 10);
}

async function getSearchPage(query, filter, gl, hl) {
  const params = new URLSearchParams({ search_query: query, hl: hl || 'en' });
  if (gl) params.set('gl', gl);
  const sp = SEARCH_FILTERS[filter];
  if (sp) params.set('sp', sp);
  const url = `https://www.youtube.com/results?${params.toString()}`;
  let data = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    const html = await httpText(url, { headers: HEADERS, retries: 1, tag: 'search' });
    data = extractYtInitialData(html);
    const hasResults = data && /videoRenderer|lockupViewModel|channelRenderer|playlistRenderer|shortsLockupViewModel/.test(JSON.stringify(data));
    if (data && hasResults) return data;
    data = null;
    await new Promise((resolve) => setTimeout(resolve, 1200));
  }
  if (!data) throw new UpstreamError('search: ytInitialData tidak ditemukan');
  return data;
}

function mapVideo(vid) {
  if (!vid?.videoId) return null;
  const handleUrl = vid.ownerText?.runs?.[0]?.navigationEndpoint?.browseEndpoint?.canonicalBaseUrl
    || vid.shortBylineText?.runs?.[0]?.navigationEndpoint?.browseEndpoint?.canonicalBaseUrl
    || '';
  const lengthText = textOf(vid.lengthText);
  const views = textOf(vid.shortViewCountText) || textOf(vid.viewCountText);
  return {
    type: 'video',
    videoId: vid.videoId,
    title: textOf(vid.title) || 'Untitled',
    url: `https://www.youtube.com/watch?v=${vid.videoId}`,
    author: {
      name: textOf(vid.ownerText) || textOf(vid.shortBylineText) || '',
      handle: handleUrl ? handleUrl.replace('/', '@') : null,
      url: handleUrl ? `https://www.youtube.com${handleUrl}` : null,
      verified: !!(vid.ownerBadges && vid.ownerBadges.some((b) => JSON.stringify(b).includes('VERIFIED')))
    },
    views: views || null,
    viewCount: parseNumber(views),
    duration: lengthText || null,
    durationSeconds: parseDurationSeconds(lengthText),
    published: textOf(vid.publishedTimeText) || null,
    description: textOf(vid.detailedMetadataSnippets?.[0]?.snippetText) || null,
    thumbnail: bestThumb(vid.thumbnail) || `https://i.ytimg.com/vi/${vid.videoId}/hqdefault.jpg`,
    live: /LIVE|live/i.test(textOf(vid.badges)) || vid.badges?.some((b) => b.metadataBadgeRenderer?.style === 'BADGE_STYLE_TYPE_LIVE_NOW') || false
  };
}

function mapChannel(ch) {
  if (!ch?.channelId) return null;
  const rawSub = textOf(ch.subscriberCountText);
  const isHandle = rawSub.startsWith('@');
  return {
    type: 'channel',
    channelId: ch.channelId,
    name: textOf(ch.title),
    handle: isHandle ? rawSub : null,
    subscribers: isHandle ? null : (rawSub || null),
    videoCount: isHandle ? textOf(ch.videoCountText) : (textOf(ch.videoCountText) || null),
    url: `https://www.youtube.com/channel/${ch.channelId}`,
    description: textOf(ch.descriptionSnippet) || null,
    verified: !!ch.ownerBadges,
    thumbnail: bestThumb(ch.thumbnail)
  };
}

function mapPlaylist(p) {
  const id = p.playlistId || p.contentId;
  if (!id) return null;
  if (p.contentType && p.contentType !== 'LOCKUP_CONTENT_TYPE_PLAYLIST') return null;
  const title = textOf(p.title) || textOf(p.metadata?.lockupMetadataViewModel?.title) || 'Untitled';
  const thumb = bestThumb(p);
  const countText = textOf(p.videoCountText) || textOf(p.stats) || textOf(p.metadata?.lockupMetadataViewModel?.metadata?.contentMetadataViewModel?.metadataRows?.[0]?.metadataParts?.[0]?.text);
  return {
    type: 'playlist',
    playlistId: id,
    title,
    url: `https://www.youtube.com/playlist?list=${id}`,
    videoCount: countText || null,
    videoCountNumber: parseNumber(countText),
    thumbnail: thumb
  };
}

function mapShort(item) {
  const reel = item.reelItemRenderer;
  const lockup = item.shortsLockupViewModel;
  if (reel?.videoId) {
    const raw = textOf(reel.headline) || reel.accessibility?.accessibilityData?.label || 'Untitled';
    return {
      type: 'short',
      videoId: reel.videoId,
      title: raw.split(',').slice(0, -1).join(',').trim() || raw,
      url: `https://www.youtube.com/shorts/${reel.videoId}`,
      views: textOf(reel.viewCountText) || null,
      thumbnail: bestThumb(reel)
    };
  }
  if (lockup) {
    const videoId = lockup.onTap?.innertubeCommand?.reelWatchEndpoint?.videoId;
    if (!videoId) return null;
    const raw = textOf(lockup.overlayMetadata?.primaryText) || lockup.accessibilityText || 'Untitled';
    return {
      type: 'short',
      videoId,
      title: raw,
      url: `https://www.youtube.com/shorts/${videoId}`,
      views: textOf(lockup.overlayMetadata?.secondaryText) || null,
      thumbnail: bestThumb(lockup)
    };
  }
  return null;
}

function extractResults(data, filter) {
  const items = [];
  if (filter === 'video') {
    for (const vid of deepFind(data, 'videoRenderer', [], 60)) items.push(mapVideo(vid));
  } else if (filter === 'channel') {
    for (const ch of deepFind(data, 'channelRenderer', [], 40)) items.push(mapChannel(ch));
  } else if (filter === 'playlist') {
    const nodes = [...deepFind(data, 'playlistRenderer', [], 40), ...deepFind(data, 'lockupViewModel', [], 40)];
    for (const p of nodes) items.push(mapPlaylist(p));
  } else {
    for (const node of deepFind(data, 'videoRenderer', [], 40)) items.push(mapVideo(node));
    for (const node of deepFind(data, 'lockupViewModel', [], 20)) items.push(mapPlaylist(node));
    for (const node of deepFind(data, 'channelRenderer', [], 10)) items.push(mapChannel(node));
    for (const node of deepFind(data, 'reelItemRenderer', [], 10)) items.push(mapShort({ reelItemRenderer: node }));
    for (const node of deepFind(data, 'shortsLockupViewModel', [], 10)) items.push(mapShort({ shortsLockupViewModel: node }));
  }
  const seen = new Set();
  return items.filter((item) => {
    if (!item) return false;
    const key = `${item.type}:${item.videoId || item.playlistId || item.channelId}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export async function searchAll(query, options = {}) {
  const { type = 'all', gl = null, hl = 'en' } = options;
  const filter = SEARCH_FILTERS[type] || null;
  const data = await getSearchPage(query, filter ? type : 'all', gl, hl);
  const results = extractResults(data, filter ? type : 'all');
  return {
    query,
    type: filter ? type : 'all',
    total: results.length,
    results
  };
}

export async function searchShorts(query, options = {}) {
  const { gl = null, hl = 'en' } = options;
  const params = new URLSearchParams({ search_query: `${query}`, hl: hl || 'en' });
  if (gl) params.set('gl', gl);
  const data = await getSearchPage(query, null, gl, hl);
  const shorts = [];
  for (const node of deepFind(data, 'reelItemRenderer', [], 30)) shorts.push(mapShort({ reelItemRenderer: node }));
  for (const node of deepFind(data, 'shortsLockupViewModel', [], 30)) shorts.push(mapShort({ shortsLockupViewModel: node }));
  const seen = new Set();
  return {
    query,
    type: 'shorts',
    total: shorts.filter(Boolean).length,
    results: shorts.filter((s) => {
      if (!s || seen.has(s.videoId)) return false;
      seen.add(s.videoId);
      return true;
    })
  };
}
