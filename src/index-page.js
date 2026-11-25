import { Router } from 'express';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { createWebToken } from './config.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PAGE_TEMPLATE = readFileSync(join(__dirname, 'web', 'player.html'), 'utf8');

export function buildIndexRouter() {
  const router = Router();
  router.get('/', (req, res) => {
    const token = createWebToken();
    const html = PAGE_TEMPLATE.replace('__LUNARELLYS_WEB_TOKEN__', token);
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.send(html);
  });
  return router;
}

export function indexPage() {
  return PAGE_TEMPLATE.replace('__LUNARELLYS_WEB_TOKEN__', createWebToken());
}
