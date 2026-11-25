import { createHash } from 'node:crypto';
import { inflateRawSync } from 'node:zlib';
import vm from 'node:vm';
import { Worker } from 'node:worker_threads';
import { extractVideoId, httpFetch, httpText, headProbe, resolveRedirect, UpstreamError } from '../lib/http.js';

const base = 'https://embed.dlsrv.online';
const check = 'https://check.dlsrv.online';
const ua = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Mobile Safari/537.36';

const QUALITY_ORDER = {
  mp4: [720, 1080, 480, 360, 240, 144],
  mp3: [320, 256, 192, 128]
};

const REDIRECT_STATUS = new Set([301, 302, 303, 307, 308]);
const RETRYABLE = /HTTP (401|403|429|5\d\d)/;

const hdr = {
  'User-Agent': ua,
  'sec-ch-ua': '"Google Chrome";v="155", "Chromium";v="155", "Not(A:Brand";v="24"',
  'sec-ch-ua-mobile': '?1',
  'sec-ch-ua-platform': '"Android"',
  'accept-language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7'
};

const navHdr = {
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'upgrade-insecure-requests': '1',
  'sec-fetch-site': 'cross-site',
  'sec-fetch-mode': 'navigate',
  'sec-fetch-dest': 'iframe',
  referer: 'https://ssyoutube.me/'
};

const apiHdr = {
  origin: base,
  'sec-fetch-site': 'same-origin',
  'sec-fetch-mode': 'cors',
  'sec-fetch-dest': 'empty'
};

const dlHdr = {
  ...hdr,
  Accept: 'text/html,application/xhtml+xml,*/*;q=0.8',
  'sec-fetch-site': 'same-site',
  'sec-fetch-mode': 'navigate',
  'sec-fetch-dest': 'document'
};

const POW_SOURCE = `
const { createHash } = require('node:crypto');
const { parentPort } = require('node:worker_threads');

parentPort.on('message', (job) => {
  const { salt, target, max } = job;
  const bits = 4 * target.length;
  const full = Math.floor(bits / 8);
  const rest = bits % 8;
  const pad = target.length % 2 === 0 ? target : target + '0';
  const want = new Uint8Array(pad.length / 2);
  for (let i = 0; i < want.length; i++) want[i] = parseInt(pad.substring(2 * i, 2 * i + 2), 16);
  const mask = rest > 0 ? (255 << (8 - rest)) & 255 : 0;
  let found = null;
  for (let n = 0; n < max; n++) {
    const d = new Uint8Array(createHash('sha256').update(salt + n).digest());
    let ok = true;
    for (let i = 0; i < full; i++) {
      if (d[i] !== want[i]) { ok = false; break; }
    }
    if (ok && rest > 0 && (d[full] & mask) !== (want[full] & mask)) ok = false;
    if (ok) { found = n; break; }
  }
  parentPort.postMessage(found);
});
`;

let worker = null;
function getWorker() {
  if (!worker) {
    worker = new Worker(POW_SOURCE, { eval: true });
    worker.unref();
  }
  return worker;
}

function powAsync(salt, target, max = 20000000) {
  return new Promise((resolve, reject) => {
    const w = getWorker();
    const onMessage = (result) => {
      w.removeListener('message', onMessage);
      w.removeListener('error', onError);
      resolve(result);
    };
    const onError = (err) => {
      w.removeListener('message', onMessage);
      w.removeListener('error', onError);
      reject(err);
    };
    w.on('message', onMessage);
    w.on('error', onError);
    w.postMessage({ salt, target, max });
  });
}

function rnd(seed, len) {
  let st = 0x811c9dc5;
  for (let i = 0; i < seed.length; i++) {
    st ^= seed.charCodeAt(i);
    st += (st << 1) + (st << 4) + (st << 7) + (st << 8) + (st << 24);
  }
  let v = st >>> 0;
  let out = '';
  while (out.length < len) {
    v ^= v << 13;
    v ^= v >>> 17;
    v ^= v << 5;
    out += (v >>> 0).toString(16).padStart(8, '0');
  }
  return out.substring(0, len);
}

function addCookie(jar, res) {
  const set = res.headers.getSetCookie ? res.headers.getSetCookie() : [];
  if (!set.length) return jar;
  const map = new Map((jar ? jar.split('; ') : []).map((p) => p.split('=')));
  for (const cookie of set) {
    const pair = cookie.split(';')[0].trim();
    const idx = pair.indexOf('=');
    if (idx > 0) map.set(pair.slice(0, idx), pair.slice(idx + 1));
  }
  return [...map].map(([k, v]) => `${k}=${v}`).join('; ');
}

const stackBad = ['node:internal', 'moduleEvaluation', 'loadAndEvaluateModule', 'file:///', '[eval]', '(native:'];

function FakeErr(msg) {
  const e = new Error(msg);
  const lines = String(e.stack ?? '').split('\n').filter((l) => !stackBad.some((b) => l.includes(b)));
  const clean = lines.length ? lines.join('\n') : String(e.stack).split('\n')[0];
  delete e.stack;
  Object.defineProperty(e, 'stack', { value: clean, configurable: true, writable: true });
  Object.setPrototypeOf(e, FakeErr.prototype);
  return e;
}
FakeErr.prototype = Object.create(Error.prototype);
FakeErr.prototype.name = 'Error';

function Node3(data) {
  this.nodeType = 3;
  this.data = data;
}

function EvTarget() {}
function El() {}
function Win() {}
function Doc() {}
function Nav() {}
function Nod() {}
function Mime() {}
function MimeArr() {}

function Ev(type, opt) {
  this.type = type;
  this.detail = opt && opt.detail;
}

El.prototype = Object.create(EvTarget.prototype);
Win.prototype = Object.create(EvTarget.prototype);
Doc.prototype = Object.create(EvTarget.prototype);
Nav.prototype = Object.create(EvTarget.prototype);
El.prototype[Symbol.toStringTag] = 'HTMLDivElement';
Win.prototype[Symbol.toStringTag] = 'Window';
Doc.prototype[Symbol.toStringTag] = 'HTMLDocument';
Nav.prototype[Symbol.toStringTag] = 'Navigator';
Nod.prototype[Symbol.toStringTag] = 'Node';

Object.defineProperties(El.prototype, {
  children: { get() { return this.childNodes.filter((n) => n.nodeType === 1); } },
  lastElementChild: { get() { const c = this.children; return c.length ? c[c.length - 1] : null; } },
  textContent: {
    get() { return this.childNodes.map((n) => (n.nodeType === 3 ? n.data : n.textContent)).join(''); },
    set(v) { this.childNodes = String(v) === '' ? [] : [new Node3(v)]; }
  },
  innerText: {
    get() { return this.textContent; },
    set(v) { this.childNodes = [new Node3(String(v))]; }
  }
});

Object.assign(El.prototype, {
  appendChild(n) {
    n.parentNode = this;
    this.childNodes.push(n);
    return n;
  },
  removeChild(n) {
    const i = this.childNodes.indexOf(n);
    if (i >= 0) this.childNodes.splice(i, 1);
    n.parentNode = null;
    return n;
  },
  addEventListener(t, cb) {
    if (!this._ev) this._ev = new Map();
    if (!this._ev.has(t)) this._ev.set(t, []);
    this._ev.get(t).push(cb);
  },
  removeEventListener(t, cb) {
    const l = (this._ev && this._ev.get(t)) || [];
    const i = l.indexOf(cb);
    if (i >= 0) l.splice(i, 1);
  },
  dispatchEvent(e) {
    e.target = this;
    e.currentTarget = this;
    for (const cb of [...((this._ev && this._ev.get(e.type)) || [])]) cb(e);
    return true;
  },
  getAttributeNames() { return []; }
});

function el(tag) {
  const e = Object.create(El.prototype);
  e.tagName = String(tag).toUpperCase();
  e.nodeType = 1;
  e.childNodes = [];
  e.parentNode = null;
  e.style = {};
  return e;
}

function fakeBrowser() {
  const inbox = [];
  const doc = Object.create(Doc.prototype);
  const html = el('html');
  const body = el('body');
  html.appendChild(body);
  Object.defineProperties(doc, {
    body: { value: body, enumerable: true },
    documentElement: { value: html, enumerable: true }
  });
  doc.createElement = el;
  doc.createTextNode = (t) => new Node3(t);

  const nav = Object.create(Nav.prototype);
  const mimes = new MimeArr();
  const plugs = new MimeArr();
  Object.defineProperties(Nav.prototype, {
    userAgent: { get: () => ua, configurable: true },
    productSub: { get: () => '20030107', configurable: true },
    mimeTypes: { get: () => mimes, configurable: true },
    plugins: { get: () => plugs, configurable: true },
    language: { get: () => 'id-ID', configurable: true },
    languages: { get: () => ['id-ID', 'en-US'], configurable: true },
    hardwareConcurrency: { get: () => 8, configurable: true }
  });

  const parent = { postMessage: (m) => inbox.push(m) };

  const box = {
    document: doc,
    navigator: nav,
    parent,
    Error: FakeErr,
    HTMLElement: El,
    Window: Win,
    Document: Doc,
    Navigator: Nav,
    EventTarget: EvTarget,
    CustomEvent: Ev,
    Node: Nod,
    MimeType: Mime,
    MimeTypeArray: MimeArr,
    location: { href: `${base}/v1/full`, origin: base },
    setTimeout,
    clearTimeout,
    setInterval,
    clearInterval,
    console: { log() {}, warn() {}, error() {}, debug() {} },
    postMessage: (m) => inbox.push(m)
  };

  const ctx = vm.createContext(box);
  const g = vm.runInContext('globalThis', ctx);
  Object.setPrototypeOf(g, Win.prototype);
  for (const k of ['window', 'self', 'top']) {
    Object.defineProperty(g, k, { value: g, configurable: true, enumerable: true, writable: true });
  }
  Object.defineProperty(g, Symbol.toStringTag, { value: 'Window', configurable: true });
  doc.defaultView = g;
  g.parent = parent;
  return { ctx, inbox, win: g };
}

async function runInstr(b64) {
  const src = inflateRawSync(Buffer.from(b64, 'base64')).toString('utf8');
  const { ctx, inbox, win } = fakeBrowser();
  await new Promise((ok, fail) => {
    try {
      new vm.Script(src, { filename: 'instr.js' }).runInContext(ctx);
      if (typeof win.onload === 'function') Promise.resolve(win.onload()).then(ok, fail);
      else setTimeout(ok, 2000);
    } catch (e) {
      fail(e);
    }
  });
  const msg = inbox.find((m) => m && m.type === 'cap:instr');
  if (!msg) throw new UpstreamError('instrumentation: lingkungan kedetect bot');
  if (msg.blocked) throw new UpstreamError(`instrumentation: blocked (${msg.blockReason || 'bot'})`);
  return msg.result;
}

async function findSk() {
  const page = await httpFetch(`${base}/v1/full?videoId=x`, {
    headers: { ...hdr, ...navHdr },
    redirect: 'follow',
    timeout: 20000,
    tag: 'ssyoutube-page'
  });
  if (!page.ok) throw new UpstreamError(`halaman embed: HTTP ${page.status}`);
  const html = await page.text();
  const jar = addCookie('', page);

  const queue = [...new Set([...html.matchAll(/\/_next\/static\/chunks\/[A-Za-z0-9_.-]+\.js/g)].map((m) => m[0]))];
  const done = new Set();

  for (let depth = 0; depth < 3 && queue.length; depth++) {
    const next = [];
    for (const chunk of queue) {
      if (done.has(chunk)) continue;
      done.add(chunk);
      const res = await httpFetch(`${base}${chunk}`, {
        headers: { ...hdr, referer: `${base}/`, 'sec-fetch-site': 'same-origin', 'sec-fetch-mode': 'no-cors', 'sec-fetch-dest': 'script' },
        timeout: 15000,
        tag: 'ssyoutube-chunk'
      });
      if (!res.ok) continue;
      const js = await res.text();
      const match = js.match(/check\.dlsrv\.online\/([0-9a-f]{10})\//);
      if (match) return { sk: match[1], jar };
      for (const n of js.matchAll(/static\/chunks\/([A-Za-z0-9_.-]+\.js)/g)) next.push(`/_next/static/chunks/${n[1]}`);
    }
    queue.length = 0;
    queue.push(...next.filter((c) => !done.has(c)));
  }
  throw new UpstreamError('ssyoutube: sitekey tidak ditemukan');
}

async function newSession(videoId) {
  const { sk, jar } = await findSk();

  const chalRes = await httpFetch(`${check}/${sk}/challenge`, {
    method: 'POST',
    headers: { ...hdr, ...apiHdr, 'sec-fetch-site': 'same-site', Cookie: jar },
    body: '',
    timeout: 20000,
    tag: 'ssyoutube-challenge'
  });
  if (!chalRes.ok) throw new UpstreamError(`challenge: HTTP ${chalRes.status}`);
  const chal = await chalRes.json();

  const instr = chal.instrumentation ? await runInstr(chal.instrumentation) : null;

  const { c, s, d } = chal.challenge;
  const solutions = [];
  for (let i = 1; i <= c; i++) {
    const n = await powAsync(rnd(`${chal.token}${i}`, s), rnd(`${chal.token}${i}d`, d));
    if (n === null) throw new UpstreamError(`pow nomor ${i} gagal`);
    solutions.push(n);
  }

  const redRes = await httpFetch(`${check}/${sk}/redeem`, {
    method: 'POST',
    headers: { ...hdr, ...apiHdr, 'sec-fetch-site': 'same-site', 'Content-Type': 'application/json', Cookie: jar },
    body: JSON.stringify({ token: chal.token, solutions, instr }),
    timeout: 20000,
    tag: 'ssyoutube-redeem'
  });
  const red = await redRes.json().catch(() => ({}));
  if (!redRes.ok || !red.success) throw new UpstreamError(`redeem: HTTP ${redRes.status}`);

  const verRes = await httpFetch(`${base}/api/verify`, {
    method: 'POST',
    headers: { ...hdr, ...apiHdr, 'Content-Type': 'application/json', referer: `${base}/v1/full?videoId=${videoId}`, Cookie: jar },
    body: JSON.stringify({ capToken: red.token }),
    timeout: 20000,
    tag: 'ssyoutube-verify'
  });
  if (!verRes.ok) throw new UpstreamError(`verify: HTTP ${verRes.status}`);
  const ver = await verRes.json();
  if (!ver.token) throw new UpstreamError('verify: token tidak ada');

  const tok = ver.token;
  let ck = addCookie(jar, verRes);

  const touchRes = await httpFetch(`${base}/api/session/touch`, {
    method: 'POST',
    headers: { ...hdr, ...apiHdr, 'Content-Type': 'application/json', authorization: `Bearer ${tok}`, referer: `${base}/v1/full?videoId=${videoId}`, Cookie: ck },
    body: JSON.stringify({ videoId }),
    timeout: 20000,
    tag: 'ssyoutube-touch'
  });
  const touch = await touchRes.json().catch(() => ({}));
  if (!touchRes.ok || !touch.ok) throw new UpstreamError(`touch: HTTP ${touchRes.status}`);

  return { sk, tok, jar: addCookie(ck, touchRes) };
}

async function getStream(session, videoId, format, quality) {
  const res = await httpFetch(`${base}/api/download/${format === 'mp4' ? 'mp4' : 'mp3'}`, {
    method: 'POST',
    headers: { ...hdr, ...apiHdr, 'Content-Type': 'application/json', authorization: `Bearer ${session.tok}`, referer: `${base}/v1/full?videoId=${videoId}`, Cookie: session.jar },
    body: JSON.stringify({ videoId, format, quality }),
    timeout: 25000,
    tag: `ssyoutube-download-${format}`
  });
  if (!res.ok) throw new UpstreamError(`api/download/${format}: HTTP ${res.status}`);
  const payload = await res.json();
  if (!payload.url) throw new UpstreamError(`api/download/${format}: provider tidak memberi URL`);
  return payload;
}

async function resolveMedia(url) {
  const hop = await httpFetch(url, { redirect: 'manual', headers: dlHdr, timeout: 15000, tag: 'ssyoutube-hop' });
  let target = url;
  if (REDIRECT_STATUS.has(hop.status)) {
    const loc = hop.headers.get('location');
    if (!loc) throw new UpstreamError(`tunnel: redirect ${hop.status} tanpa location`);
    target = loc;
  } else if (!hop.ok) {
    throw new UpstreamError(`tunnel: HTTP ${hop.status}`);
  }
  return headProbe(target, { headers: dlHdr, timeout: 15000 });
}

const sessionCache = new Map();
const SESSION_TTL = 9 * 60 * 1000;

async function getSession(videoId) {
  const key = 'global';
  const entry = sessionCache.get(key);
  if (entry && entry.expires > Date.now()) return entry.session;
  const session = await newSession(videoId);
  sessionCache.set(key, { session, expires: Date.now() + SESSION_TTL });
  return session;
}

export async function downloadV2(urlOrId, options = {}) {
  const { type = 'video', quality = null } = options;
  const videoId = extractVideoId(urlOrId);
  if (!videoId) throw new UpstreamError('invalid youtube url or video id');
  const isVideo = type !== 'audio';
  const format = isVideo ? 'mp4' : 'mp3';
  const preferred = Number(quality) || (isVideo ? 720 : 320);

  const order = [...new Set([preferred, ...QUALITY_ORDER[format]])].filter((q) => q > 0 && Number.isFinite(q));
  order.sort((a, b) => Math.abs(a - preferred) - Math.abs(b - preferred) || b - a);

  const attempts = [];
  let session = null;
  for (const q of order) {
    try {
      session = await getSession(videoId);
      const stream = await getStream(session, videoId, format, q);
      const media = await resolveMedia(stream.url);
      return {
        engine: 'v2',
        engineName: 'SSYouTube',
        videoId,
        title: media.filename ? media.filename.replace(/\.[a-z0-9]+$/i, '') : null,
        requested: { type: isVideo ? 'video' : 'audio', quality: preferred },
        resolved: { quality: q, fallback: q !== preferred },
        download: {
          url: media.url,
          tunnel: stream.url,
          filename: media.filename || stream.filename || null,
          contentType: media.contentType,
          sizeBytes: media.length,
          sizeMb: media.sizeMb
        }
      };
    } catch (err) {
      attempts.push({ quality: q, ok: false, error: err.message });
      if (!RETRYABLE.test(err.message)) break;
      sessionCache.delete('global');
      session = null;
      await new Promise((resolve) => setTimeout(resolve, 800));
    }
  }

  throw new UpstreamError(
    `ssyoutube: ${format} gagal untuk semua quality [${order.join(', ')}]`,
    attempts.length ? { attempts } : null
  );
}

export { extractVideoId };
