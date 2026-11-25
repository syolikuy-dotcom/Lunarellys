import { httpText, httpJson, extractYtInitialData, deepFind, textOf, bestThumb, extractVideoId, UpstreamError, HttpError } from '../lib/http.js';

const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Accept-Language': 'en-US,en;q=0.9'
};

const INNERTUBE = 'https://www.youtube.com/youtubei/v1';
const WEB_CONTEXT = {
  context: {
    client: {
      clientName: 'WEB',
      clientVersion: '2.20241126.01.00',
      hl: 'en',
      gl: 'US'
    }
  }
};

async function innertube(endpoint, body, extraHeaders = {}) {
  return httpJson(`${INNERTUBE}/${endpoint}?prettyPrint=false`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': HEADERS['User-Agent'],
      Origin: 'https://www.youtube.com',
      Referer: 'https://www.youtube.com/',
      ...extraHeaders
    },
    body: JSON.stringify({ ...WEB_CONTEXT, ...body }),
    retries: 1,
    tag: `innertube-${endpoint}`
  });
}

function parseViews(text) {
  if (!text) return null;
  const match = String(text).match(/([\d.,]+)\s*(K|M|B|rb|jt|ribu|juta|billion|million|thousand)?/i);
  if (!match) return null;
  let value = parseFloat(match[1].replace(/,/g, ''));
  if (!Number.isFinite(value)) return null;
  const suffix = (match[2] || '').toLowerCase();
  if (['k', 'rb', 'ribu', 'thousand'].includes(suffix)) value *= 1e3;
  else if (['m', 'jt', 'juta', 'million'].includes(suffix)) value *= 1e6;
  else if (suffix === 'b' || suffix === 'billion') value *= 1e9;
  return Math.round(value);
}

function parseDate(text) {
  if (!text) return null;
  const match = String(text).match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
  return match ? match[0] : null;
}

function lockupDuration(lockup) {
  const overlays = lockup?.contentImage?.thumbnailViewModel?.overlays || [];
  for (const overlay of overlays) {
    for (const badge of overlay.thumbnailBottomOverlayViewModel?.badges || []) {
      const text = badge.thumbnailBadgeViewModel?.text;
      if (text && /^\d{1,2}:\d{2}(:\d{2})?$/.test(text)) return text;
    }
  }
  return null;
}

function lockupMetaRows(lockup) {
  const rows = lockup?.metadata?.lockupMetadataViewModel?.metadata?.contentMetadataViewModel?.metadataRows || [];
  return rows.map((row) => (row.metadataParts || []).map((part) => part.text?.content || '').filter(Boolean));
}

function lockupChannel(lockup) {
  const image = lockup?.metadata?.lockupMetadataViewModel?.image?.decoratedAvatarViewModel;
  const onTap = image?.avatar?.avatarViewModel?.rendererContext?.commandContext?.onTap?.innertubeCommand;
  const browse = onTap?.browseEndpoint;
  const rows = lockupMetaRows(lockup);
  if (browse && /^UC/.test(browse.browseId || '')) {
    return {
      id: browse.browseId,
      name: null,
      handle: browse.canonicalBaseUrl ? browse.canonicalBaseUrl.replace('/', '@') : null,
      url: browse.canonicalBaseUrl ? `https://www.youtube.com${browse.canonicalBaseUrl}` : null
    };
  }
  const rowText = rows.length >= 2 ? rows[0]?.[0] || null : null;
  return { id: null, name: rowText, handle: null, url: null };
}

function mapLockupVideo(lockup) {
  if (!lockup || lockup.contentType !== 'LOCKUP_CONTENT_TYPE_VIDEO') return null;
  const videoId = lockup.contentId;
  if (!videoId) return null;
  const meta = lockup.metadata?.lockupMetadataViewModel || {};
  const rows = lockupMetaRows(lockup);
  const statRow = rows.length >= 2 ? rows[1] : (rows[0] || []);
  return {
    type: 'video',
    videoId,
    title: meta.title?.content || null,
    url: `https://www.youtube.com/watch?v=${videoId}`,
    author: lockupChannel(lockup),
    views: statRow[0] || null,
    viewCount: parseViews(statRow[0]),
    published: statRow[1] || null,
    duration: lockupDuration(lockup),
    thumbnail: bestThumb(lockup.contentImage) || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`
  };
}

function mapLockupShort(lockup) {
  const onTap = lockup?.onTap?.innertubeCommand;
  const videoId = onTap?.reelWatchEndpoint?.videoId || lockup?.contentId;
  if (!videoId) return null;
  const title = lockup?.overlayMetadata?.primaryText?.content
    || lockup?.metadata?.lockupMetadataViewModel?.title?.content
    || null;
  const views = lockup?.overlayMetadata?.secondaryText?.content
    || lockup?.metadata?.lockupMetadataViewModel?.metadata?.contentMetadataViewModel?.metadataRows?.[0]?.metadataParts?.[0]?.text?.content
    || null;
  const thumb = onTap?.reelWatchEndpoint?.thumbnail?.thumbnails?.[0]?.url
    || bestThumb(lockup?.thumbnailViewModel)
    || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
  return {
    type: 'short',
    videoId,
    title,
    url: `https://www.youtube.com/shorts/${videoId}`,
    views,
    thumbnail: thumb
  };
}

export async function getVideoMeta(videoId) {
  let html = await httpText(`https://www.youtube.com/watch?v=${videoId}&hl=en`, { headers: HEADERS, retries: 1, tag: 'watch' });
  let data = extractYtInitialData(html);
  if (!data) {
    await new Promise((resolve) => setTimeout(resolve, 1200));
    html = await httpText(`https://www.youtube.com/watch?v=${videoId}&hl=en`, { headers: HEADERS, retries: 1, tag: 'watch-retry' });
    data = extractYtInitialData(html);
  }
  if (!data) throw new UpstreamError('video: ytInitialData tidak ditemukan');

  const currentVideoEndpoint = deepFind(data, 'currentVideoEndpoint', [], 2)[0];
  const effectiveId = currentVideoEndpoint?.watchEndpoint?.videoId || videoId;

  const header = deepFind(data, 'videoDescriptionHeaderRenderer', [], 2)[0];
  const primary = deepFind(data, 'videoPrimaryInfoRenderer', [], 2)[0];
  const secondary = deepFind(data, 'videoSecondaryInfoRenderer', [], 2)[0];

  const title = textOf(header?.title) || textOf(primary?.title) || null;
  const channelName = textOf(header?.owner?.runs?.[0]) || textOf(secondary?.owner?.videoOwnerRenderer?.title) || null;
  const channelUrl = header?.owner?.runs?.[0]?.navigationEndpoint?.browseEndpoint?.canonicalBaseUrl
    || secondary?.owner?.videoOwnerRenderer?.navigationEndpoint?.browseEndpoint?.canonicalBaseUrl
    || null;
  const channelId = header?.owner?.runs?.[0]?.navigationEndpoint?.browseEndpoint?.browseId
    || secondary?.owner?.videoOwnerRenderer?.navigationEndpoint?.browseEndpoint?.browseId
    || null;
  const viewsText = textOf(primary?.viewCount?.videoViewCountRenderer?.viewCount) || textOf(header?.views) || null;
  const dateText = textOf(primary?.dateText?.simpleText) || textOf(header?.publishDate) || null;

  const factoids = header?.factoids || [];
  let likes = null;
  for (const factoid of factoids) {
    const value = textOf(factoid?.factoidRenderer?.value);
    const label = textOf(factoid?.factoidRenderer?.label) || '';
    if (/like/i.test(label)) {
      likes = parseViews(value);
      break;
    }
  }
  if (likes === null) {
    for (const item of deepFind(data, 'segmentedLikeDislikeButtonViewModel', [], 2)) {
      const btnTitle = item?.likeButtonViewModel?.likeButtonViewModel?.toggleButtonViewModel?.toggleButtonViewModel
        ?.defaultButtonViewModel?.buttonViewModel?.title;
      if (btnTitle) {
        likes = parseViews(btnTitle);
        break;
      }
    }
  }

  let description = null;
  let descriptionLinks = [];
  const descPanel = deepFind(data, 'expandableVideoDescriptionBodyRenderer', [], 2)[0]
    || deepFind(data, 'structuredDescriptionVideoRenderer', [], 2)[0]?.description?.expandableVideoDescriptionBodyRenderer;
  const attributed = descPanel?.descriptionBodyText || descPanel?.attributedDescriptionBodyText;
  if (attributed) {
    description = textOf(attributed);
    if (Array.isArray(attributed.commandRuns)) {
      for (const run of attributed.commandRuns) {
        const url = run.onTap?.innertubeCommand?.urlEndpoint?.url
          || run.onTap?.innertubeCommand?.watchEndpoint?.videoId
          || run.onTap?.innertubeCommand?.browseEndpoint?.canonicalBaseUrl;
        if (url) descriptionLinks.push(url);
      }
    }
  } else if (attributed === undefined) {
    const attr = deepFind(data, 'attributedDescription', [], 2)[0];
    if (attr) {
      description = textOf(attr);
      if (Array.isArray(attr.commandRuns)) {
        for (const run of attr.commandRuns) {
          const url = run.onTap?.innertubeCommand?.urlEndpoint?.url
            || run.onTap?.innertubeCommand?.browseEndpoint?.canonicalBaseUrl;
          if (url) descriptionLinks.push(url);
        }
      }
    }
  }

  const keywords = deepFind(data, 'superTitleLink', [], 1)[0]
    ? deepFind(data, 'superTitleLink', [], 1)[0].runs?.map((r) => r.text).join(' ').match(/#\w+/g) || []
    : [];

  const related = [];
  const secondaryResults = deepFind(data, 'secondaryResults', [], 1)[0];
  const relatedLockups = secondaryResults ? deepFind(secondaryResults, 'lockupViewModel', [], 30) : [];
  for (const lockup of relatedLockups) {
    const item = mapLockupVideo(lockup);
    if (!item) continue;
    related.push({ videoId: item.videoId, title: item.title, url: item.url, duration: item.duration, thumbnail: item.thumbnail });
    if (related.length >= 20) break;
  }

  const chapters = [];
  for (const panel of deepFind(data, 'macroMarkersListItemRenderer', [], 30)) {
    chapters.push({
      title: textOf(panel.title) || null,
      time: textOf(panel.timeDescription) || null,
      timeSeconds: panel.timeDescriptionA11yLabel ? parseViews(panel.timeDescriptionA11yLabel) : null
    });
  }

  const commentsContinuation = deepFind(data, 'continuationItemRenderer', [], 3)[0]
    ?.continuationItemRenderer?.continuationEndpoint?.continuationCommand?.token || null;

  const playability = deepFind(data, 'playabilityStatus', [], 1)[0];
  const isPlayable = !playability || playability.status === 'OK';

  return {
    videoId: effectiveId,
    title,
    url: `https://www.youtube.com/watch?v=${effectiveId}`,
    description,
    descriptionLinks: descriptionLinks.slice(0, 20),
    views: viewsText || null,
    viewCount: parseViews(viewsText),
    likes,
    published: dateText,
    publishedAt: parseDate(dateText),
    channel: {
      id: channelId,
      name: channelName,
      url: channelUrl ? `https://www.youtube.com${channelUrl}` : null,
      thumbnail: channelId ? `https://yt3.googleusercontent.com/ytc/${channelId}=s176-c-k-c0x00ffffff-no-rj` : null
    },
    keywords,
    chapters,
    related,
    commentsContinuation,
    playable: isPlayable,
    playabilityStatus: playability?.status || null,
    thumbnails: {
      maxres: `https://i.ytimg.com/vi/${effectiveId}/maxresdefault.jpg`,
      hq: `https://i.ytimg.com/vi/${effectiveId}/hqdefault.jpg`,
      mq: `https://i.ytimg.com/vi/${effectiveId}/mqdefault.jpg`
    }
  };
}

export async function getComments(videoId, continuation = null) {
  if (!continuation) {
    const bootstrap = await innertube('next', { videoId });
    const token = deepFind(bootstrap, 'continuationItemRenderer', [], 3)
      .map((item) => item.continuationEndpoint?.continuationCommand?.token || item.continuationCommand?.token)
      .find(Boolean) || null;
    if (!token) return { videoId, total: 0, comments: [], continuation: null };
    continuation = token;
  }

  const data = await innertube('next', { continuation });
  const payloads = new Map();
  for (const mutation of data.frameworkUpdates?.entityBatchUpdate?.mutations || []) {
    const payload = mutation.payload?.commentEntityPayload;
    if (payload && payload.properties?.commentId) {
      payloads.set(payload.key, payload);
    }
  }

  const comments = [];
  const threads = deepFind(data, 'commentThreadRenderer', [], 40);
  for (const thread of threads) {
    const commentKey = thread.commentViewModel?.commentViewModel?.commentKey;
    const payload = commentKey ? payloads.get(commentKey) : null;
    if (!payload) continue;
    const props = payload.properties || {};
    const toolbar = payload.toolbar || {};
    comments.push({
      id: props.commentId || null,
      author: payload.author?.displayName || null,
      text: props.content?.content || null,
      published: props.publishedTime || null,
      likes: parseViews(toolbar.likeCountNotliked) || 0,
      replyCount: parseViews(toolbar.replyCount) || 0
    });
  }

  let nextToken = null;
  for (const item of deepFind(data, 'continuationItemRenderer', [], 4)) {
    const token = item.continuationEndpoint?.continuationCommand?.token;
    if (token) {
      nextToken = token;
      break;
    }
  }

  return {
    videoId,
    total: comments.length,
    comments,
    continuation: nextToken
  };
}

export async function getChannelMeta(channelInput) {
  let channelId = channelInput;
  let handle = null;
  if (/^UC[\w-]{22}$/.test(channelInput)) {
    channelId = channelInput;
  } else if (channelInput.startsWith('@')) {
    handle = channelInput;
    channelId = null;
  } else if (channelInput.includes('youtube.com') || channelInput.includes('youtu.be')) {
    const urlMatch = channelInput.match(/(UC[\w-]{22})|(@[\w.-]+)/);
    if (urlMatch) {
      if (urlMatch[1]) channelId = urlMatch[1];
      else handle = urlMatch[2];
    }
  } else {
    handle = `@${channelInput}`;
  }

  const target = channelId
    ? `https://www.youtube.com/channel/${channelId}/about?hl=en`
    : `https://www.youtube.com/${handle}/about?hl=en`;
  const html = await httpText(target, { headers: HEADERS, retries: 1, tag: 'channel' });
  const data = extractYtInitialData(html);
  if (!data) throw new UpstreamError('channel: ytInitialData tidak ditemukan');

  const headerViewModel = deepFind(data, 'pageHeaderViewModel', [], 2)[0];
  const micro = deepFind(data, 'microformatDataRenderer', [], 2)[0];
  const meta = deepFind(data, 'aboutChannelViewModel', [], 2)[0];

  const name = headerViewModel?.title?.dynamicTextViewModel?.text?.content
    || micro?.title
    || null;

  const avatarSources = headerViewModel?.image?.decoratedAvatarViewModel?.avatar?.avatarViewModel?.image?.sources || [];
  const avatar = avatarSources.length
    ? avatarSources[avatarSources.length - 1].url
    : (micro ? bestThumb(micro.thumbnail) : null);

  const links = [];
  if (meta?.links) {
    for (const link of meta.links) {
      const val = link.channelExternalLinkViewModel?.title?.content || null;
      const url = link.channelExternalLinkViewModel?.link?.content || null;
      if (url) links.push({ title: val, url });
    }
  }

  const resolvedId = meta?.channelId
    || deepFind(data, 'browseId', [], 3).find((id) => /^UC[\w-]{22}$/.test(id))
    || channelId
    || null;
  const canonical = meta?.canonicalChannelUrl || meta?.displayCanonicalChannelUrl || null;
  const resolvedHandle = canonical
    ? (canonical.startsWith('@') ? canonical : `@${canonical.split('/').pop()}`)
    : handle;

  const subscriberText = meta?.subscriberCountText || null;

  return {
    channelId: resolvedId,
    handle: resolvedHandle,
    name,
    description: meta?.description || null,
    subscribers: subscriberText,
    subscriberCount: parseViews(subscriberText),
    videoCount: meta?.videoCountText || null,
    totalViews: meta?.viewCountText || null,
    joined: meta?.joinedDateText?.content ? parseDate(meta.joinedDateText.content) : null,
    country: meta?.country || null,
    links,
    url: resolvedId ? `https://www.youtube.com/channel/${resolvedId}` : `https://www.youtube.com/${resolvedHandle}`,
    thumbnail: avatar || (resolvedId ? `https://yt3.googleusercontent.com/ytc/${resolvedId}=s176-c-k-c0x00ffffff-no-rj` : null)
  };
}

export async function getChannelVideos(channelId, type = 'videos') {
  const target = channelId.startsWith('@')
    ? `https://www.youtube.com/${channelId}/${type}?hl=en`
    : `https://www.youtube.com/channel/${channelId}/${type}?hl=en`;
  const html = await httpText(target, { headers: HEADERS, retries: 1, tag: 'channel-videos' });
  const data = extractYtInitialData(html);
  if (!data) throw new UpstreamError('channel videos: ytInitialData tidak ditemukan');

  const videos = [];
  for (const rich of deepFind(data, 'richItemRenderer', [], 40)) {
    const content = rich.content || {};
    if (content.shortsLockupViewModel) {
      const mapped = mapLockupShort(content.shortsLockupViewModel);
      if (mapped) videos.push(mapped);
    } else if (content.lockupViewModel) {
      const mapped = mapLockupVideo(content.lockupViewModel);
      if (mapped) videos.push(mapped);
    } else if (content.videoRenderer?.videoId) {
      const renderer = content.videoRenderer;
      videos.push({
        type: 'video',
        videoId: renderer.videoId,
        title: textOf(renderer.title) || null,
        url: `https://www.youtube.com/watch?v=${renderer.videoId}`,
        author: { id: null, name: null, handle: null, url: null },
        views: textOf(renderer.viewCountText) || null,
        published: textOf(renderer.publishedTimeText) || null,
        duration: textOf(renderer.lengthText) || null,
        thumbnail: bestThumb(renderer.thumbnail)
      });
    }
    if (videos.length >= 30) break;
  }

  for (const vid of deepFind(data, 'gridVideoRenderer', [], 30)) {
    if (videos.length >= 30) break;
    if (!vid.videoId) continue;
    videos.push({
      type: 'video',
      videoId: vid.videoId,
      title: textOf(vid.title) || null,
      url: `https://www.youtube.com/watch?v=${vid.videoId}`,
      author: { id: null, name: null, handle: null, url: null },
      views: textOf(vid.viewCountText) || null,
      published: textOf(vid.publishedTimeText) || null,
      duration: textOf(vid.lengthText) || null,
      thumbnail: bestThumb(vid.thumbnail)
    });
  }

  const seen = new Set();
  const unique = videos.filter((v) => {
    if (seen.has(v.videoId)) return false;
    seen.add(v.videoId);
    return true;
  });

  let continuation = null;
  for (const item of deepFind(data, 'continuationItemRenderer', [], 3)) {
    const token = item.continuationEndpoint?.continuationCommand?.token;
    if (token) {
      continuation = token;
      break;
    }
  }

  const pageHeader = deepFind(data, 'pageHeaderViewModel', [], 2)[0];
  const ownerName = pageHeader?.title?.dynamicTextViewModel?.text?.content || null;
  if (ownerName) {
    for (const v of unique) {
      if (v.author && v.author.name && !v.author.id && !v.author.handle && v.author.name === v.views) {
        v.author = { id: null, name: null, handle: null, url: null };
      }
    }
  }

  return {
    channelId,
    channelName: ownerName,
    tab: type,
    total: unique.length,
    videos: unique,
    continuation
  };
}

export async function getTrending(region = 'ID') {
  const data = await innertube('browse', {
    browseId: 'UC4R8DWoMoI7CAwX8_LjQHig',
    params: 'EgdsaXZldGFikgEDCKEK'
  }, {
    'X-YouTube-Client-Name': '1',
    'X-YouTube-Client-Version': '2.20241126.01.00'
  }).catch(() => null);

  if (!data) throw new UpstreamError('trending: upstream tidak merespons');

  const videos = [];
  for (const rich of deepFind(data, 'richItemRenderer', [], 40)) {
    const content = rich.content || {};
    const lockup = content.lockupViewModel;
    if (lockup) {
      const mapped = mapLockupVideo(lockup);
      if (mapped) videos.push(mapped);
      continue;
    }
    const renderer = content.videoRenderer;
    if (renderer?.videoId) {
      videos.push({
        type: 'video',
        videoId: renderer.videoId,
        title: textOf(renderer.title) || null,
        url: `https://www.youtube.com/watch?v=${renderer.videoId}`,
        author: { id: null, name: textOf(renderer.ownerText) || null, handle: null, url: null },
        views: textOf(renderer.shortViewCountText) || null,
        published: textOf(renderer.publishedTimeText) || null,
        duration: textOf(renderer.lengthText) || null,
        thumbnail: bestThumb(renderer.thumbnail)
      });
    }
    if (videos.length >= 30) break;
  }

  const seen = new Set();
  const unique = videos.filter((v) => {
    if (seen.has(v.videoId)) return false;
    seen.add(v.videoId);
    return true;
  });

  return {
    region,
    source: 'youtube-live-channel',
    note: 'YouTube removed the aggregated trending feed in July 2025, this returns the live-now feed that replaced it',
    total: unique.length,
    videos: unique
  };
}

export async function getPlaylistMeta(playlistId) {
  const cleanId = playlistId.startsWith('VL') ? playlistId.slice(2) : playlistId;
  const html = await httpText(`https://www.youtube.com/playlist?list=${cleanId}&hl=en`, {
    headers: HEADERS,
    retries: 1,
    tag: 'playlist'
  });
  const data = extractYtInitialData(html);
  if (!data) throw new UpstreamError('playlist: ytInitialData tidak ditemukan');

  const headerViewModel = deepFind(data, 'pageHeaderViewModel', [], 2)[0];
  const micro = deepFind(data, 'microformatDataRenderer', [], 2)[0];
  const title = headerViewModel?.title?.dynamicTextViewModel?.text?.content || micro?.title || null;

  let videoCountText = null;
  let viewsText = null;
  const headerRows = headerViewModel?.metadata?.contentMetadataViewModel?.metadataRows || [];
  for (const row of headerRows) {
    for (const part of row.metadataParts || []) {
      const content = part.text?.content || '';
      if (/videos?/i.test(content)) videoCountText = content;
      else if (/views?/i.test(content)) viewsText = content;
    }
  }

  const videos = [];
  for (const lockup of deepFind(data, 'lockupViewModel', [], 100)) {
    if (lockup.contentType !== 'LOCKUP_CONTENT_TYPE_VIDEO') continue;
    const videoId = lockup.contentId;
    if (!videoId) continue;
    const meta = lockup.metadata?.lockupMetadataViewModel || {};
    const rows = lockupMetaRows(lockup);
    const statRow = rows[1] || [];
    const channel = lockupChannel(lockup);
    videos.push({
      videoId,
      title: meta.title?.content || null,
      url: `https://www.youtube.com/watch?v=${videoId}`,
      author: channel.name || channel.handle,
      channelHandle: channel.handle,
      views: statRow[0] || null,
      published: statRow[1] || null,
      duration: lockupDuration(lockup),
      thumbnail: bestThumb(lockup.contentImage) || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`
    });
    if (videos.length >= 100) break;
  }

  let continuation = null;
  for (const item of deepFind(data, 'continuationItemRenderer', [], 3)) {
    const token = item.continuationEndpoint?.continuationCommand?.token;
    if (token) {
      continuation = token;
      break;
    }
  }

  return {
    playlistId: cleanId,
    title,
    url: `https://www.youtube.com/playlist?list=${cleanId}`,
    videoCount: videoCountText,
    videoCountNumber: parseViews(videoCountText),
    views: viewsText,
    viewCount: parseViews(viewsText),
    thumbnail: videos[0]?.thumbnail || (micro ? bestThumb(micro) : null),
    total: videos.length,
    videos,
    continuation
  };
}

export { extractVideoId };
