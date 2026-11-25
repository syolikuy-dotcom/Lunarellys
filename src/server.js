import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import { config } from './config.js';
import { rateLimit, apiKeyAuth, validateInput, notFound, errorHandler, requireAdminAuth, adminRateLimit } from './middleware.js';
import apiRouter from './routes.js';
import { buildDocsRouter } from './docs.js';
import { buildIndexRouter } from './index-page.js';

process.on('unhandledRejection', (reason) => {
  console.error(`[unhandledRejection] ${reason instanceof Error ? reason.message : reason}`);
});

process.on('uncaughtException', (err) => {
  console.error(`[uncaughtException] ${err.message || err}`);
});

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);

app.use(helmet({
  referrerPolicy: { policy: 'no-referrer' },
  contentSecurityPolicy: {
    useDefaults: true,
    directives: {
      'default-src': ["'self'"],
      'style-src': ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
      'font-src': ["'self'", 'https://fonts.gstatic.com', 'data:'],
      'script-src': ["'self'", "'unsafe-inline'"],
      'script-src-attr': ["'unsafe-inline'"],
      'img-src': ["'self'", 'https:', 'data:', 'blob:'],
      'media-src': ["'self'", 'https:', 'blob:'],
      'connect-src': ["'self'", 'https:'],
      'upgrade-insecure-requests': []
    }
  },
  crossOriginResourcePolicy: { policy: 'cross-origin' }
}));

app.use(compression({
  filter: (req, res) => {
    if (req.path.includes('/proxy-stream')) return false;
    return compression.filter(req, res);
  }
}));

app.use((req, res, next) => {
  const origin = req.get('origin');
  if (config.corsOrigin === '*') {
    res.setHeader('Access-Control-Allow-Origin', '*');
  } else if (origin && config.corsOrigin.split(',').map((o) => o.trim()).includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, HEAD, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-API-Key, X-User-Token, X-Admin-Passcode, Authorization, Range');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges, Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  next();
});

app.use(express.json({ limit: '2mb' }));

app.get('/favicon.ico', (req, res) => res.status(204).end());

if (config.publicDocs) {
  app.use('/docs', buildDocsRouter());
} else {
  app.use('/docs', adminRateLimit, requireAdminAuth, buildDocsRouter());
}

app.use('/api', rateLimit, apiKeyAuth, validateInput, apiRouter);
app.use('/', buildIndexRouter());
app.use('/', rateLimit, apiKeyAuth, validateInput, apiRouter);

app.use(notFound);
app.use(errorHandler);

const server = app.listen(config.port, () => {
  console.log(`[lunarellys-api] listening on :${config.port} (env=${config.nodeEnv}, auth=${config.apiKeys.length ? 'on' : 'off'})`);
});
server.headersTimeout = 15000;
server.keepAliveTimeout = 65000;
server.requestTimeout = 120000;

function shutdown(signal) {
  console.log(`[lunarellys-api] ${signal} received, closing server`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 8000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

export default app;
