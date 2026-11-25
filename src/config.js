import 'dotenv/config';

function readInt(name, fallback, min, max) {
  const raw = process.env[name];
  const value = parseInt(raw, 10);
  if (!Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, value));
}

function readKeys() {
  const raw = process.env.API_KEYS || process.env.API_KEY || '';
  return raw.split(',').map((k) => k.trim()).filter(Boolean);
}

export const config = {
  port: readInt('PORT', 3000, 1, 65535),
  apiKeys: readKeys(),
  rateLimitWindowMs: readInt('RATE_LIMIT_WINDOW_MS', 60000, 1000, 3600000),
  rateLimitMax: readInt('RATE_LIMIT_MAX', 60, 1, 10000),
  cacheTtlMs: readInt('CACHE_TTL_MS', 300000, 1000, 3600000),
  cacheMaxEntries: readInt('CACHE_MAX_ENTRIES', 500, 10, 100000),
  defaultRegion: (process.env.DEFAULT_REGION || 'ID').slice(0, 2).toUpperCase(),
  corsOrigin: process.env.CORS_ORIGIN || '*',
  logLevel: (process.env.LOG_LEVEL || 'info').toLowerCase(),
  nodeEnv: process.env.NODE_ENV || 'production'
};

export function authEnabled() {
  return config.apiKeys.length > 0;
}
