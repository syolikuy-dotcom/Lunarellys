import crypto from 'node:crypto';
import { config, authEnabled } from './config.js';

const buckets = new Map();
let lastSweep = Date.now();

export function rateLimit(req, res, next) {
  const now = Date.now();
  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const windowMs = config.rateLimitWindowMs;
  const max = config.rateLimitMax;

  if (now - lastSweep > windowMs) {
    for (const [key, bucket] of buckets) {
      if (bucket.reset < now) buckets.delete(key);
    }
    lastSweep = now;
  }

  let bucket = buckets.get(ip);
  if (!bucket || bucket.reset < now) {
    bucket = { count: 0, reset: now + windowMs };
    buckets.set(ip, bucket);
  }
  bucket.count++;

  res.setHeader('X-RateLimit-Limit', String(max));
  res.setHeader('X-RateLimit-Remaining', String(Math.max(0, max - bucket.count)));
  res.setHeader('X-RateLimit-Reset', String(Math.ceil(bucket.reset / 1000)));

  if (bucket.count > max) {
    const retryAfter = Math.ceil((bucket.reset - now) / 1000);
    res.setHeader('Retry-After', String(retryAfter));
    return res.status(429).json({
      success: false,
      error: 'rate limit exceeded',
      retryAfterSeconds: retryAfter
    });
  }
  next();
}

function timingSafeEqual(a, b) {
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  if (bufA.length !== bufB.length) {
    crypto.timingSafeEqual(bufA, bufA);
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

export function apiKeyAuth(req, res, next) {
  if (!authEnabled()) return next();
  if (req.path === '/health' || req.path === '/') return next();

  const provided = req.get('x-api-key')
    || (req.get('authorization')?.startsWith('Bearer ') ? req.get('authorization').slice(7) : null)
    || req.query.api_key
    || null;

  if (!provided) {
    return res.status(401).json({
      success: false,
      error: 'api key required',
      hint: 'send via X-API-Key header, Authorization: Bearer, or api_key query param'
    });
  }

  const match = config.apiKeys.some((key) => timingSafeEqual(provided, key));
  if (!match) {
    return res.status(401).json({
      success: false,
      error: 'invalid api key'
    });
  }
  next();
}

export function validateInput(req, res, next) {
  const suspicious = /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION)\b.*\b(FROM|INTO|TABLE)\b)|(<script)|javascript:|on\w+\s*=/i;
  for (const [key, value] of Object.entries(req.query)) {
    if (typeof value === 'string' && suspicious.test(value) && key !== 'q' && key !== 'query') {
      return res.status(400).json({
        success: false,
        error: `invalid input in parameter '${key}'`
      });
    }
    if (typeof value === 'string' && value.length > 500) {
      return res.status(400).json({
        success: false,
        error: `parameter '${key}' too long (max 500 chars)`
      });
    }
  }
  next();
}

export function notFound(req, res) {
  res.status(404).json({
    success: false,
    error: 'endpoint not found',
    path: req.path,
    docs: '/api/ or /docs'
  });
}

export function errorHandler(err, req, res, next) {
  const status = err.status || err.statusCode || 500;
  const isClientError = status >= 400 && status < 500;
  const log = status >= 500 ? console.error : console.warn;
  log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} -> ${status}: ${err.message}`);

  if (res.headersSent) return next(err);

  const body = {
    success: false,
    error: err.message || 'internal server error',
    status
  };
  if (err.details && typeof err.details === 'object') {
    body.details = err.details;
  }
  if (!isClientError && config.nodeEnv === 'production') {
    body.error = isScrapeError(err) ? err.message : 'internal server error';
  }
  res.status(status).json(body);
}

function isScrapeError(err) {
  return err.name === 'UpstreamError' || err.name === 'HttpError';
}

export function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
