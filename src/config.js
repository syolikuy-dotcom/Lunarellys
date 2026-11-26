import 'dotenv/config';
import crypto from 'node:crypto';

function readInt(names, fallback, min, max) {
  for (const name of names) {
    const raw = process.env[name];
    const value = parseInt(raw, 10);
    if (Number.isFinite(value)) return Math.min(max, Math.max(min, value));
  }
  return fallback;
}

function readKeys() {
  const raw = process.env.API_KEYS || '';
  return raw.split(',').map((k) => k.trim()).filter(Boolean);
}

export const config = {
  serviceName: 'Lunarellys',
  appVersion: '1.2.0',
  developer: 'Ikhwan Romadon',
  port: readInt(['PORT', 'SERVER_PORT'], 3000, 1, 65535),
  apiKeys: readKeys(),
  rateLimitWindowMs: readInt(['RATE_LIMIT_WINDOW_MS'], 60000, 1000, 3600000),
  rateLimitMax: readInt(['RATE_LIMIT_MAX'], 300, 1, 10000),
  cacheTtlMs: readInt(['CACHE_TTL_MS'], 300000, 1000, 3600000),
  cacheMaxEntries: readInt(['CACHE_MAX_ENTRIES'], 500, 10, 100000),
  defaultRegion: (process.env.DEFAULT_REGION || 'ID').slice(0, 2).toUpperCase(),
  corsOrigin: process.env.CORS_ORIGIN || '*',
  logLevel: (process.env.LOG_LEVEL || 'info').toLowerCase(),
  nodeEnv: process.env.NODE_ENV || 'production',
  webTokenSecret: crypto.randomBytes(32),
  sessionSecret: process.env.SESSION_SECRET
    ? crypto.createHash('sha256').update(process.env.SESSION_SECRET).digest()
    : crypto.randomBytes(32),
  googleClientId: (process.env.GOOGLE_CLIENT_ID || '').trim(),
  googleClientSecret: (process.env.GOOGLE_CLIENT_SECRET || '').trim(),
  publicBaseUrl: (process.env.PUBLIC_BASE_URL || process.env.APP_URL || '').trim().replace(/\/+$/, ''),
  adminPasscode: (process.env.ADMIN_PASSCODE || '').trim(),
  publicDocs: process.env.PUBLIC_DOCS === 'true'
};

export function authEnabled() {
  return config.apiKeys.length > 0;
}

export function googleOAuthEnabled() {
  return Boolean(config.googleClientId && config.googleClientSecret);
}

export function adminConfigured() {
  return config.adminPasscode.length > 0;
}

export function verifyAdminPasscode(candidate) {
  if (!adminConfigured() || !candidate || typeof candidate !== 'string') return false;
  const hashA = crypto.createHash('sha256').update(candidate.trim()).digest();
  const hashB = crypto.createHash('sha256').update(config.adminPasscode).digest();
  return crypto.timingSafeEqual(hashA, hashB);
}

function signPayload(dataObj, secret) {
  const payload = Buffer.from(JSON.stringify(dataObj), 'utf8').toString('base64url');
  const sig = crypto.createHmac('sha256', secret).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

function verifyPayload(token, secret) {
  if (!token || typeof token !== 'string') return null;
  const dot = token.indexOf('.');
  if (dot <= 0) return null;
  const payload = token.slice(0, dot);
  const sig = token.slice(dot + 1);
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('base64url');
  const bufA = Buffer.from(sig);
  const bufB = Buffer.from(expected);
  if (bufA.length !== bufB.length || !crypto.timingSafeEqual(bufA, bufB)) return null;
  try {
    const parsed = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    if (parsed.exp && Date.now() > parsed.exp) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function createUserToken(user) {
  return signPayload(
    {
      sub: user.id,
      email: user.email || '',
      name: user.name || '',
      exp: Date.now() + 30 * 24 * 60 * 60 * 1000
    },
    config.sessionSecret
  );
}

export function verifyUserToken(token) {
  return verifyPayload(token, config.sessionSecret);
}

export function createOAuthState(extra = {}) {
  return signPayload(
    {
      nonce: crypto.randomBytes(12).toString('hex'),
      ...extra,
      exp: Date.now() + 10 * 60 * 1000
    },
    config.sessionSecret
  );
}

export function verifyOAuthState(state) {
  return verifyPayload(state, config.sessionSecret);
}

export function createWebToken() {
  const exp = Date.now() + 24 * 60 * 60 * 1000;
  const sig = crypto.createHmac('sha256', config.webTokenSecret).update(String(exp)).digest('hex');
  return `${exp}.${sig}`;
}

export function verifyWebToken(token) {
  if (!token || typeof token !== 'string') return false;
  const dot = token.indexOf('.');
  if (dot <= 0) return false;
  const expStr = token.slice(0, dot);
  const sig = token.slice(dot + 1);
  const exp = Number(expStr);
  if (!Number.isFinite(exp) || exp < Date.now()) return false;
  const expected = crypto.createHmac('sha256', config.webTokenSecret).update(expStr).digest('hex');
  const bufA = Buffer.from(sig);
  const bufB = Buffer.from(expected);
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

