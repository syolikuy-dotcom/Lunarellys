import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import { config } from './config.js';
import { rateLimit, apiKeyAuth, validateInput, notFound, errorHandler } from './middleware.js';
import apiRouter from './routes.js';
import { buildDocsRouter } from './docs.js';
import { buildIndexRouter } from './index-page.js';

process.on('unhandledRejection', (reason) => {
  console.error(`[unhandledRejection] ${reason instanceof Error ? reason.stack : reason}`);
});

process.on('uncaughtException', (err) => {
  console.error(`[uncaughtException] ${err.stack || err}`);
});

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);

app.use(helmet({
  contentSecurityPolicy: {
    useDefaults: true,
    directives: {
      'default-src': ["'self'"],
      'style-src': ["'self'", "'unsafe-inline'"],
      'script-src': ["'self'", "'unsafe-inline'"],
      'script-src-attr': ["'unsafe-inline'"],
      'img-src': ["'self'", 'https:', 'data:'],
      'connect-src': ["'self'"],
      'upgrade-insecure-requests': []
    }
  },
  crossOriginResourcePolicy: { policy: 'cross-origin' }
}));

app.use(compression());

app.use((req, res, next) => {
  const origin = req.get('origin');
  if (config.corsOrigin === '*') {
    res.setHeader('Access-Control-Allow-Origin', '*');
  } else if (origin && config.corsOrigin.split(',').map((o) => o.trim()).includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-API-Key, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  next();
});

app.use(express.json({ limit: '100kb' }));

app.get('/favicon.ico', (req, res) => res.status(204).end());

app.use('/docs', buildDocsRouter());
app.use('/api', rateLimit, apiKeyAuth, validateInput, apiRouter);
app.use('/', buildIndexRouter());
app.use('/', rateLimit, apiKeyAuth, validateInput, apiRouter);

app.use(notFound);
app.use(errorHandler);

const server = app.listen(config.port, () => {
  console.log(`[youtube-rest-api] listening on :${config.port} (env=${config.nodeEnv}, auth=${config.apiKeys.length ? 'on' : 'off'})`);
});

function shutdown(signal) {
  console.log(`[youtube-rest-api] ${signal} received, closing server`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 8000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

export default app;
