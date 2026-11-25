import { extractVideoId, httpText, httpJson, httpFetch, UpstreamError } from '../lib/http.js';

const BASE = 'https://www.snapyt.app';
const AJAX = `${BASE}/wp-admin/admin-ajax.php`;
const HOME_ID = `${BASE}/id/`;

const UA = 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

const HEADERS = {
  'User-Agent': UA,
  Accept: 'text/html,application/json,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'id-ID,id;q=0.9,en;q=0.8'
};

async function httpPostForm(fields, tag) {
  const body = new URLSearchParams(fields).toString();
  const res = await httpFetch(AJAX, {
    method: 'POST',
    headers: {
      ...HEADERS,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      Referer: HOME_ID,
      Origin: BASE,
      'X-Requested-With': 'XMLHttpRequest'
    },
    body,
    timeout: 30000,
    retries: 1,
    tag
  });
  return res;
}

async function getFreshNonce() {
  const res = await httpPostForm({ action: 'vd_fresh_nonce' }, 'snapyt-nonce');
  if (res.ok) {
    const json = await res.json().catch(() => null);
    if (json && json.success && json.data && json.data.nonce) return json.data.nonce;
  }
  const html = await httpText(HOME_ID, { headers: HEADERS, timeout: 20000, tag: 'snapyt-home' });
  const match = html.match(/"nonce"\s*:\s*"([a-f0-9]+)"/);
  if (match) return match[1];
  throw new UpstreamError('snapyt: nonce tidak ditemukan');
}

async function requestPreviewUrl(ytUrl, nonce) {
  const res = await httpPostForm({
    action: 'process_video_url',
    video_url: ytUrl,
    security: nonce || ''
  }, 'snapyt-process');
  const json = await res.json().catch(() => null);

  if (res.status === 403 || json === -1 || json === '-1') {
    const err = new UpstreamError('snapyt: nonce rejected');
    err.nonceRejected = true;
    throw err;
  }
  if (json && json.success && json.data && json.data.redirect) {
    return { redirect: json.data.redirect };
  }
  const msg = json && typeof json.data === 'string'
    ? json.data
    : json && json.data && json.data.message
      ? json.data.message
      : `Respons tidak valid (HTTP ${res.status}).`;
  throw new UpstreamError(`snapyt: ${msg}`);
}

function parseDuration(text) {
  const match = String(text || '').match(/(\d{1,2}:)?(\d{1,2}):(\d{2})/);
  if (!match) return { text: null, seconds: null };
  const parts = match[0].split(':').map((n) => parseInt(n, 10));
  let sec = 0;
  for (const p of parts) sec = sec * 60 + p;
  return { text: match[0], seconds: sec };
}

function parseResolution(label) {
  const match = String(label || '').match(/(\d{3,4})p/);
  return match ? `${match[1]}p` : null;
}

function parseBitrateKbps(label) {
  const match = String(label || '').match(/(\d{2,3})\s*kbps/i);
  return match ? parseInt(match[1], 10) : null;
}

function parseSizeToBytes(size) {
  if (!size) return null;
  const match = String(size).match(/([\d.]+)\s*(KB|MB|GB)/i);
  if (!match) return null;
  const n = parseFloat(match[1]);
  const unit = match[2].toUpperCase();
  const mult = unit === 'GB' ? 1024 ** 3 : unit === 'MB' ? 1024 ** 2 : 1024;
  return Math.round(n * mult);
}

function decodeEntities(text) {
  return String(text || '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)));
}

function attr(html, tag, attribute) {
  const re = new RegExp(`<${tag}[^>]*\\b${attribute}="([^"]*)"`, 'i');
  const match = html.match(re);
  return match ? decodeEntities(match[1]) : null;
}

function parsePreviewHtml(html, inputUrl) {
  const title = attr(html, 'h1', 'class') ? (html.match(/<h1 class="title"[^>]*>([^<]+)<\/h1>/i)?.[1] || null) : null;
  const chipMatch = html.match(/class="chip"[^>]*>([^<]+)</i);
  const thumbnail = attr(html, 'img', 'src')
    || (html.match(/id="vd-thumb-dl"[^>]*data-srcs="([^"]*)"/i)?.[1] || '').split('|')[0] || null;

  let durationText = null;
  let durationSeconds = null;
  for (const metaMatch of html.matchAll(/class="meta"[^>]*>([^<]+)</gi)) {
    const text = decodeEntities(metaMatch[1]).replace(/\s+/g, ' ').trim();
    const m = text.match(/Duration:\s*([0-9:]+)/i);
    if (m && !durationText) {
      durationText = m[1];
      durationSeconds = parseDuration(m[1]).seconds;
    }
  }

  const formats = [];
  const optgroupRe = /<optgroup([^>]*)>([\s\S]*?)<\/optgroup>/gi;
  for (const ogMatch of html.matchAll(optgroupRe)) {
    const ogAttrs = ogMatch[1];
    const groupLabel = decodeEntities((ogAttrs.match(/label="([^"]*)"/i)?.[1] || '')).replace(/^[^\w]*\s*/, '').trim();
    for (const optMatch of ogMatch[2].matchAll(/<option([^>]*)>([^<]*)<\/option>/gi)) {
      const optAttrs = optMatch[1];
      const optText = decodeEntities(optMatch[2]).replace(/\s+/g, ' ').trim();
      const get = (name) => {
        const m = optAttrs.match(new RegExp(`\\b${name}="([^"]*)"`, 'i'));
        return m ? decodeEntities(m[1]) : null;
      };
      const label = (get('data-label') || optText || '').replace(/\s+/g, ' ').trim();
      const kind = get('data-kind');
      const ext = get('data-ext');
      const size = get('data-size');
      const bytes = get('data-bytes');
      const mp3 = get('data-mp3');
      const force = get('data-force');
      const stream = get('data-url');
      let itag = null;
      if (stream) {
        try { itag = new URL(stream).searchParams.get('itag'); } catch { itag = null; }
      }
      formats.push({
        group: groupLabel || null,
        value: get('value'),
        label: label || optText || null,
        kind,
        extension: ext,
        resolution: parseResolution(label || optText),
        bitrateKbps: mp3 ? parseInt(mp3, 10) : parseBitrateKbps(label || optText),
        isMp3: Boolean(mp3) || /mp3/i.test(label || optText),
        sizeDisplay: size,
        sizeBytes: bytes ? parseInt(bytes, 10) : parseSizeToBytes(size),
        recommended: get('data-recommended') === '1',
        itag,
        downloadUrl: force,
        streamUrl: stream
      });
    }
  }

  const videoId = extractVideoId(inputUrl)
    || ((thumbnail || '').match(/\/vi\/([^/]+)\//)?.[1] || null);

  const errorBox = html.match(/id="error-message"[^>]*>([\s\S]*?)<\/div>/i)?.[1];
  const pageError = errorBox ? decodeEntities(errorBox.replace(/<[^>]+>/g, '')).replace(/\s+/g, ' ').trim() : null;

  return {
    videoId,
    title: title ? decodeEntities(title) : null,
    statusChip: chipMatch ? decodeEntities(chipMatch[1]).trim() : null,
    pageError: pageError || null,
    thumbnailUrl: thumbnail,
    durationText,
    durationSeconds,
    formats
  };
}

async function fetchOEmbed(ytUrl) {
  try {
    const normalized = `https://www.youtube.com/watch?v=${extractVideoId(ytUrl)}`;
    const data = await httpJson(`https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(normalized)}`, {
      headers: { Accept: 'application/json', Referer: 'https://www.youtube.com/', 'User-Agent': UA },
      timeout: 12000,
      tag: 'oembed'
    });
    const username = data.author_url ? `@${data.author_url.match(/@([^/?#]+)/)?.[1] || ''}` : null;
    return {
      channelName: data.author_name || null,
      channelUsername: username && username !== '@' ? username : null,
      channelUrl: data.author_url || null,
      oembedTitle: data.title || null
    };
  } catch {
    return { channelName: null, channelUsername: null, channelUrl: null, oembedTitle: null };
  }
}

let nonceCache = { nonce: null, expires: 0 };

async function getNonce() {
  if (nonceCache.nonce && nonceCache.expires > Date.now()) return nonceCache.nonce;
  const nonce = await getFreshNonce();
  nonceCache = { nonce, expires: Date.now() + 8 * 60 * 1000 };
  return nonce;
}

export async function downloadV3(urlOrId, options = {}) {
  const { type = 'video', quality = null } = options;
  const videoId = extractVideoId(urlOrId);
  if (!videoId) throw new UpstreamError('invalid youtube url or video id');
  const ytUrl = `https://www.youtube.com/watch?v=${videoId}`;
  const isVideo = type !== 'audio';

  let nonce = await getNonce();
  let redirect;
  try {
    ({ redirect } = await requestPreviewUrl(ytUrl, nonce));
  } catch (err) {
    if (err.nonceRejected) {
      nonceCache = { nonce: null, expires: 0 };
      nonce = await getNonce();
      ({ redirect } = await requestPreviewUrl(ytUrl, nonce));
    } else {
      throw err;
    }
  }

  const previewHtml = await httpText(redirect, { headers: HEADERS, timeout: 30000, retries: 1, tag: 'snapyt-preview' });
  const parsed = parsePreviewHtml(previewHtml, ytUrl);

  if (!parsed.formats.length && !parsed.title) {
    throw new UpstreamError('snapyt: halaman preview kosong (video mungkin dihapus, privat, atau diblokir regional)');
  }

  const formats = parsed.formats;
  const wanted = quality != null ? String(quality) : null;

  let chosen = null;
  if (wanted) {
    chosen = formats.find((f) => f.resolution === (wanted.endsWith('p') ? wanted : `${wanted}p`))
      || formats.find((f) => f.bitrateKbps === parseInt(wanted, 10))
      || formats.find((f) => f.label && f.label.toLowerCase().includes(String(wanted).toLowerCase()));
  }
  if (!chosen) {
    const pool = isVideo
      ? formats.filter((f) => f.kind === 'video+audio' || (f.kind === 'video-only' && f.downloadUrl))
      : formats.filter((f) => f.kind === 'audio-only' || f.isMp3);
    const fallbackPool = pool.length ? pool : formats;
    chosen = (isVideo
      ? fallbackPool.sort((a, b) => (parseInt(b.resolution, 10) || 0) - (parseInt(a.resolution, 10) || 0))[0]
      : fallbackPool.sort((a, b) => (b.bitrateKbps || 0) - (a.bitrateKbps || 0))[0]) || formats[0];
  }

  const oembed = await fetchOEmbed(ytUrl);

  const downloadUrl = chosen.downloadUrl || chosen.streamUrl || null;
  if (!downloadUrl) {
    throw new UpstreamError('snapyt: format terpilih tidak memiliki download url');
  }

  return {
    engine: 'v3',
    engineName: 'SnapYT',
    videoId,
    title: parsed.title || oembed.oembedTitle || null,
    channel: {
      name: oembed.channelName,
      username: oembed.channelUsername,
      url: oembed.channelUrl
    },
    thumbnail: parsed.thumbnailUrl,
    duration: parsed.durationText,
    durationSeconds: parsed.durationSeconds,
    requested: { type: isVideo ? 'video' : 'audio', quality: wanted },
    resolved: {
      group: chosen.group,
      label: chosen.label,
      kind: chosen.kind,
      extension: chosen.extension,
      resolution: chosen.resolution,
      bitrateKbps: chosen.bitrateKbps,
      sizeBytes: chosen.sizeBytes,
      sizeDisplay: chosen.sizeDisplay,
      recommended: chosen.recommended
    },
    download: {
      url: downloadUrl,
      tunnel: chosen.streamUrl && chosen.streamUrl !== downloadUrl ? chosen.streamUrl : null,
      filename: chosen.label ? `${chosen.label.replace(/[^\w\s.-]/g, '').trim()}.${chosen.extension || (isVideo ? 'mp4' : 'mp3')}` : null,
      contentType: null,
      sizeBytes: chosen.sizeBytes,
      sizeMb: chosen.sizeBytes ? Number((chosen.sizeBytes / 1048576).toFixed(2)) : null
    },
    previewUrl: redirect,
    availableFormats: {
      total: formats.length,
      items: formats.map((f) => ({
        group: f.group,
        label: f.label,
        kind: f.kind,
        extension: f.extension,
        resolution: f.resolution,
        bitrateKbps: f.bitrateKbps,
        sizeDisplay: f.sizeDisplay,
        recommended: f.recommended
      }))
    }
  };
}
