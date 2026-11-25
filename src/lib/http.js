import { setTimeout as sleep } from 'node:timers/promises';

const UA_DESKTOP = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
const UA_IOS = 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
const UA_VR = 'com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

export const BROWSERS = { UA_DESKTOP, UA_IOS, UA_VR };

export class HttpError extends Error {
  constructor(message, status = 502, details = null) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.details = details;
  }
}

export class UpstreamError extends Error {
  constructor(message, details = null) {
    super(message);
    this.name = 'UpstreamError';
    this.status = 502;
    this.details = details;
  }
}

const DEFAULT_TIMEOUT = 20000;
const REDIRECT_STATUS = new Set([301, 302, 303, 307, 308]);

export async function httpFetch(url, options = {}) {
  const {
    method = 'GET',
    headers = {},
    body = null,
    timeout = DEFAULT_TIMEOUT,
    retries = 0,
    retryDelay = 800,
    retryOn = (status) => status >= 500 || status === 429 || status === 403,
    redirect = 'follow',
    tag = 'fetch'
  } = options;

  let lastError = null;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
      const res = await fetch(url, {
        method,
        headers,
        body,
        redirect,
        signal: controller.signal,
        dispatcher: undefined
      });
      clearTimeout(timer);
      const ok = res.status >= 200 && res.status < 300;
      if (!ok && attempt < retries && retryOn(res.status)) {
        lastError = new HttpError(`${tag}: HTTP ${res.status}`, res.status >= 400 && res.status < 500 && res.status !== 429 ? 502 : 502);
        await sleep(retryDelay * (attempt + 1));
        continue;
      }
      return res;
    } catch (err) {
      clearTimeout(timer);
      lastError = err;
      const aborted = err.name === 'AbortError';
      if (attempt < retries) {
        await sleep(retryDelay * (attempt + 1));
        continue;
      }
      if (aborted) throw new UpstreamError(`${tag}: timeout setelah ${timeout}ms`);
      throw new UpstreamError(`${tag}: ${err.message}`);
    }
  }
  throw lastError || new UpstreamError(`${tag}: gagal`);
}

export async function httpJson(url, options = {}) {
  const res = await httpFetch(url, options);
  const contentType = res.headers.get('content-type') || '';
  if (!res.ok) {
    let snippet = '';
    try { snippet = (await res.text()).slice(0, 300); } catch { snippet = ''; }
    throw new HttpError(`${options.tag || 'request'}: HTTP ${res.status}`, 502, snippet);
  }
  if (!contentType.includes('json')) {
    const text = await res.text();
    try {
      return JSON.parse(text);
    } catch {
      throw new UpstreamError(`${options.tag || 'request'}: respons bukan JSON (${contentType.slice(0, 60)})`);
    }
  }
  return res.json();
}

export async function httpText(url, options = {}) {
  const res = await httpFetch(url, options);
  if (!res.ok) throw new HttpError(`${options.tag || 'request'}: HTTP ${res.status}`, 502);
  return res.text();
}

export async function resolveRedirect(url, options = {}) {
  const { headers = {}, timeout = 15000, method = 'GET' } = options;
  const res = await httpFetch(url, { method, headers, timeout, redirect: 'manual', tag: 'resolve' });
  if (REDIRECT_STATUS.has(res.status)) {
    const loc = res.headers.get('location');
    if (!loc) throw new UpstreamError(`redirect ${res.status} tanpa location`);
    return loc.startsWith('http') ? loc : new URL(loc, url).toString();
  }
  if (!res.ok) throw new UpstreamError(`probe: HTTP ${res.status}`);
  return res.url || url;
}

export async function headProbe(url, options = {}) {
  const { headers = {}, timeout = 15000 } = options;
  let res = await httpFetch(url, { method: 'HEAD', headers, timeout, redirect: 'follow', tag: 'probe' });
  if (!res.ok || !res.headers.get('content-type')) {
    res = await httpFetch(url, { method: 'GET', headers, timeout, redirect: 'follow', tag: 'probe' });
    try { res.body?.destroy(); } catch { /* ignore */ }
  }
  if (!res.ok) throw new UpstreamError(`probe: HTTP ${res.status}`);
  const contentType = res.headers.get('content-type') || 'application/octet-stream';
  if (/^text\/|^application\/(json|xhtml)/i.test(contentType)) {
    throw new UpstreamError(`bukan media: ${contentType}`);
  }
  const length = res.headers.get('content-length');
  const disposition = res.headers.get('content-disposition') || '';
  const nameMatch = disposition.match(/filename\*?=(?:UTF-8''|")?([^";]+)"?/i);
  return {
    url: res.url || url,
    contentType,
    length: length ? Number(length) : null,
    sizeMb: length ? Number((Number(length) / 1048576).toFixed(2)) : null,
    filename: nameMatch ? decodeURIComponent(nameMatch[1]) : null
  };
}

export function parseCount(raw) {
  if (raw == null) return null;
  const text = String(raw).replace(/,(?=\d{3}\b)/g, '').trim();
  const match = text.match(/^([\d.]+)\s*(K|M|B|JT|RB|T)?/i);
  if (!match) return null;
  let value = parseFloat(match[1].replace(/,(?=\d)/, '.'));
  if (!Number.isFinite(value)) return null;
  const suffix = (match[2] || '').toLowerCase();
  if (suffix === 'k' || suffix === 'rb') value *= 1e3;
  else if (suffix === 'm' || suffix === 'jt') value *= 1e6;
  else if (suffix === 'b') value *= 1e9;
  else if (suffix === 't') value *= 1e12;
  return Math.round(value);
}

export function parseHMS(text) {
  if (!text || typeof text !== 'string') return null;
  const match = text.trim().match(/^(?:(\d+):)?(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const h = match[1] ? parseInt(match[1], 10) : 0;
  return h * 3600 + parseInt(match[2], 10) * 60 + parseInt(match[3], 10);
}

export function formatDuration(seconds) {
  const total = Number(seconds);
  if (!total || Number.isNaN(total)) return null;
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const secs = Math.floor(total % 60);
  return hours
    ? `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
    : `${minutes}:${String(secs).padStart(2, '0')}`;
}

export function extractVideoId(input) {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  if (/^[A-Za-z0-9_-]{11}$/.test(raw)) return raw;
  const patterns = [
    /[?&]v=([A-Za-z0-9_-]{11})/,
    /youtu\.be\/([A-Za-z0-9_-]{11})/,
    /youtube\.com\/embed\/([A-Za-z0-9_-]{11})/,
    /youtube\.com\/shorts\/([A-Za-z0-9_-]{11})/,
    /youtube\.com\/live\/([A-Za-z0-9_-]{11})/,
    /youtube\.com\/v\/([A-Za-z0-9_-]{11})/,
    /youtube-nocookie\.com\/embed\/([A-Za-z0-9_-]{11})/,
    /\/([A-Za-z0-9_-]{11})(?:[?/#]|$)/
  ];
  for (const pattern of patterns) {
    const match = raw.match(pattern);
    if (match) return match[1];
  }
  return null;
}

export function isYouTubeUrl(raw) {
  const text = String(raw ?? '').trim();
  if (!text) return false;
  const candidate = /^https?:\/\//i.test(text) ? text : `https://${text}`;
  try {
    const url = new URL(candidate);
    const host = (url.hostname || '').toLowerCase();
    if (host === 'youtu.be' && url.pathname.length > 1) return true;
    if (/(^|\.)youtube\.com$/.test(host) || /(^|\.)youtube-nocookie\.com$/.test(host)) {
      const path = url.pathname || '';
      if (path === '/watch' && url.searchParams.get('v')) return true;
      if (/^\/(shorts|embed|live|v)\/[^/]+/.test(path)) return true;
    }
    return false;
  } catch {
    return false;
  }
}

const BALANCED_RE = /ytInitialData\s*=\s*/;

export function extractJsonAfter(html, marker, startIndex = 0) {
  const pos = html.indexOf(marker, startIndex);
  if (pos === -1) return null;
  let i = html.indexOf('{', pos + marker.length);
  if (i === -1) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (; i < html.length; i++) {
    const ch = html[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === '{') depth++;
    else if (ch === '}') {
      depth--;
      if (depth === 0) {
        try {
          return JSON.parse(html.slice(html.indexOf('{', pos + marker.length), i + 1));
        } catch {
          return null;
        }
      }
    }
  }
  return null;
}

export function extractYtInitialData(html) {
  return extractJsonAfter(html, 'var ytInitialData = ')
    ?? extractJsonAfter(html, 'ytInitialData" ] = ')
    ?? extractJsonAfter(html, 'ytInitialData = ');
}

export function deepFind(node, key, results = [], limit = Infinity) {
  if (results.length >= limit) return results;
  if (!node || typeof node !== 'object') return results;
  if (Array.isArray(node)) {
    for (const item of node) {
      deepFind(item, key, results, limit);
      if (results.length >= limit) return results;
    }
    return results;
  }
  if (node[key] !== undefined) results.push(node[key]);
  for (const value of Object.values(node)) {
    deepFind(value, key, results, limit);
    if (results.length >= limit) return results;
  }
  return results;
}

export function textOf(value) {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (value.simpleText) return value.simpleText;
  if (Array.isArray(value.runs)) return value.runs.map((run) => run.text || '').join('');
  return value.content || value.text || '';
}

export function bestThumb(node) {
  const found = [];
  const walk = (obj) => {
    if (!obj || typeof obj !== 'object' || found.length > 40) return;
    if (Array.isArray(obj)) {
      for (const item of obj) walk(item);
      return;
    }
    if (Array.isArray(obj.thumbnails)) {
      for (const t of obj.thumbnails) {
        if (t && typeof t.url === 'string') found.push({ url: t.url, width: t.width || 0 });
      }
    }
    if (typeof obj.url === 'string' && (obj.url.includes('ytimg') || obj.url.includes('ggpht'))) {
      found.push({ url: obj.url, width: obj.width || 0 });
    }
    for (const value of Object.values(obj)) {
      if (value && typeof value === 'object') walk(value);
    }
  };
  walk(node);
  if (!found.length) return null;
  found.sort((a, b) => b.width - a.width);
  let url = found[0].url;
  if (url.startsWith('//')) url = `https:${url}`;
  return url.split('?')[0];
}
