import fs from 'node:fs';
import path from 'node:path';
import { config } from '../config.js';

const DATA_DIR = path.resolve(process.cwd(), 'data');
const CONFIG_FILE = path.resolve(DATA_DIR, 'node-config.json');

let cachedConfig = null;

export function sanitizeNodeUrl(rawUrl) {
  const trimmed = String(rawUrl || '').trim();
  if (!trimmed) {
    throw new Error('Server URL is required');
  }
  if (/[\s\u0000-\u001f]/.test(trimmed)) {
    throw new Error('Server URL must not contain spaces or control characters');
  }
  const withScheme = /^https?:\/\//i.test(trimmed) ? trimmed : `http://${trimmed}`;
  let parsed;
  try {
    parsed = new URL(withScheme);
  } catch {
    throw new Error('Invalid server URL format');
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('Only http:// and https:// URLs are supported');
  }
  if (!parsed.hostname) {
    throw new Error('Server URL hostname is missing');
  }
  return parsed.toString().replace(/\/+$/, '');
}

function readFromDisk() {
  if (cachedConfig) return cachedConfig;
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const raw = fs.readFileSync(CONFIG_FILE, 'utf8');
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object') {
        cachedConfig = {
          serverUrl: parsed.serverUrl ? String(parsed.serverUrl).trim().replace(/\/+$/, '') : '',
          apiKey: parsed.apiKey ? String(parsed.apiKey).trim() : '',
          note: parsed.note ? String(parsed.note).trim().slice(0, 120) : '',
          updatedAt: parsed.updatedAt ? String(parsed.updatedAt) : null
        };
        return cachedConfig;
      }
    }
  } catch {
    // Fallback to clean state
  }
  cachedConfig = {
    serverUrl: config.defaultNodeUrl || '',
    apiKey: config.defaultNodeApiKey || '',
    note: '',
    updatedAt: null
  };
  return cachedConfig;
}

function persistToDisk(next) {
  cachedConfig = next;
  fs.mkdirSync(DATA_DIR, { recursive: true, mode: 0o700 });
  const tmp = `${CONFIG_FILE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(next, null, 2), { encoding: 'utf8', mode: 0o600 });
  fs.renameSync(tmp, CONFIG_FILE);
  try { fs.chmodSync(CONFIG_FILE, 0o600); } catch {}
  return next;
}

export function getRemoteNodeConfig() {
  const current = readFromDisk();
  return {
    serverUrl: current.serverUrl || config.defaultNodeUrl || '',
    apiKey: current.apiKey || config.defaultNodeApiKey || '',
    note: current.note || '',
    updatedAt: current.updatedAt || null
  };
}

export function setRemoteNodeConfig({ serverUrl, apiKey = '', note = '' } = {}) {
  const cleanUrl = sanitizeNodeUrl(serverUrl);
  const cleanKey = String(apiKey || '').trim().slice(0, 256);
  const cleanNote = String(note || '').trim().slice(0, 120);
  const next = {
    serverUrl: cleanUrl,
    apiKey: cleanKey,
    note: cleanNote,
    updatedAt: new Date().toISOString()
  };
  return persistToDisk(next);
}

export function resetRemoteNodeConfig() {
  const next = {
    serverUrl: '',
    apiKey: '',
    note: '',
    updatedAt: new Date().toISOString()
  };
  return persistToDisk(next);
}
