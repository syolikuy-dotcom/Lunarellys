import crypto from 'node:crypto';
import { config, authEnabled, verifyWebToken, adminConfigured, verifyAdminPasscode } from './config.js';

function createRateLimiter({ windowMs, max, prefix }) {
  const buckets = new Map();
  let lastSweep = Date.now();

  return function limiter(req, res, next) {
    const now = Date.now();
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    const key = `${prefix}:${ip}`;

    if (now - lastSweep > windowMs || buckets.size > 10000) {
      for (const [bKey, bucket] of buckets) {
        if (bucket.reset < now) buckets.delete(bKey);
      }
      lastSweep = now;
    }

    let bucket = buckets.get(key);
    if (!bucket || bucket.reset < now) {
      bucket = { count: 0, reset: now + windowMs };
      buckets.set(key, bucket);
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
  };
}

export const rateLimit = createRateLimiter({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMax,
  prefix: 'global'
});

export const strictAuthRateLimit = createRateLimiter({
  windowMs: 5 * 60 * 1000,
  max: 25,
  prefix: 'auth'
});

export const adminRateLimit = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 15,
  prefix: 'admin'
});

export const downloadRateLimit = createRateLimiter({
  windowMs: 60 * 1000,
  max: 40,
  prefix: 'dl'
});

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
  if (
    req.path === '/health'
    || req.path === '/auth/google/start'
    || req.path === '/auth/google/callback'
    || req.path === '/auth/google/callback/'
  ) {
    return next();
  }

  const webToken = req.get('x-web-token') || req.query.web_token || null;
  if (webToken && verifyWebToken(String(webToken))) {
    return next();
  }

  const provided = req.get('x-api-key')
    || (req.get('authorization')?.startsWith('Bearer ') ? req.get('authorization').slice(7) : null)
    || req.query.api_key
    || null;

  if (!provided) {
    return res.status(401).json({
      success: false,
      error: 'unauthorized'
    });
  }

  const match = config.apiKeys.some((key) => timingSafeEqual(provided, key));
  if (!match) {
    return res.status(401).json({
      success: false,
      error: 'unauthorized'
    });
  }
  next();
}

export function requireAdminAuth(req, res, next) {
  if (!adminConfigured()) {
    return res.status(403).json({
      success: false,
      error: 'admin access disabled'
    });
  }
  const passcode = req.get('x-admin-passcode') || '';
  if (!verifyAdminPasscode(passcode)) {
    return res.status(403).json({
      success: false,
      error: 'forbidden'
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
    error: 'not found'
  });
}

export function errorHandler(err, req, res, next) {
  const status = err.status || err.statusCode || 500;
  const isClientError = status >= 400 && status < 500;
  const log = status >= 500 ? console.error : console.warn;
  log(`[${new Date().toISOString()}] ${req.method} ${req.path} -> ${status}: ${err.message}`);

  if (res.headersSent) return next(err);

  const body = {
    success: false,
    error: isClientError ? (err.message || 'bad request') : 'internal server error',
    status
  };
  if (isClientError && err.details && typeof err.details === 'object') {
    body.details = err.details;
  }
  res.status(status).json(body);
}

export function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
