import fs from 'node:fs';
import path from 'node:path';

const DATA_DIR = path.resolve(process.cwd(), 'data');
const USERS_FILE = path.resolve(DATA_DIR, 'users.json');

let storeCache = null;

function ensureLoaded() {
  if (storeCache) return storeCache;
  try {
    if (fs.existsSync(USERS_FILE)) {
      const raw = fs.readFileSync(USERS_FILE, 'utf8');
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object' && parsed.users && typeof parsed.users === 'object') {
        storeCache = parsed;
        return storeCache;
      }
    }
  } catch {
    // Fallback to clean store
  }
  storeCache = { users: {} };
  return storeCache;
}

function persist() {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true, mode: 0o700 });
    const tmp = `${USERS_FILE}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(storeCache, null, 2), { encoding: 'utf8', mode: 0o600 });
    fs.renameSync(tmp, USERS_FILE);
    try { fs.chmodSync(USERS_FILE, 0o600); } catch {}
  } catch (err) {
    console.warn(`[user-store] persist skipped: ${err.message}`);
  }
}

export function upsertUserProfile(profile) {
  const store = ensureLoaded();
  const id = String(profile.id || '').trim();
  if (!id) throw new Error('user id required');
  const existing = store.users[id] || {};
  const now = new Date().toISOString();
  const next = {
    id,
    email: String(profile.email || existing.email || '').slice(0, 180),
    name: String(profile.name || existing.name || 'Archys Listener').slice(0, 120),
    picture: String(profile.picture || existing.picture || '').slice(0, 500),
    createdAt: existing.createdAt || now,
    lastLoginAt: now,
    library: existing.library || {
      likedSongs: [],
      playlists: [],
      followedArtists: [],
      savedAlbums: [],
      savedPlaylists: [],
      recentlyPlayed: [],
      updatedAt: null
    }
  };
  store.users[id] = next;
  persist();
  return next;
}

export function getUserById(id) {
  const store = ensureLoaded();
  return store.users[String(id)] || null;
}

export function getUserStats() {
  const store = ensureLoaded();
  return { totalUsers: Object.keys(store.users).length };
}

function sanitizeArray(val, maxItems = 250) {
  if (!Array.isArray(val)) return [];
  const out = [];
  for (const item of val) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
    if (JSON.stringify(item).length > 16384) continue;
    out.push(item);
    if (out.length >= maxItems) break;
  }
  return out;
}

export function updateUserLibrary(id, payload = {}) {
  const store = ensureLoaded();
  const user = store.users[String(id)];
  if (!user) return null;

  const current = user.library || {};
  const nextLibrary = {
    likedSongs: payload.likedSongs !== undefined ? sanitizeArray(payload.likedSongs, 500) : (current.likedSongs || []),
    playlists: payload.playlists !== undefined ? sanitizeArray(payload.playlists, 100) : (current.playlists || []),
    followedArtists: payload.followedArtists !== undefined ? sanitizeArray(payload.followedArtists, 200) : (current.followedArtists || []),
    savedAlbums: payload.savedAlbums !== undefined ? sanitizeArray(payload.savedAlbums, 200) : (current.savedAlbums || []),
    savedPlaylists: payload.savedPlaylists !== undefined ? sanitizeArray(payload.savedPlaylists, 200) : (current.savedPlaylists || []),
    recentlyPlayed: payload.recentlyPlayed !== undefined ? sanitizeArray(payload.recentlyPlayed, 80) : (current.recentlyPlayed || []),
    updatedAt: new Date().toISOString()
  };

  user.library = nextLibrary;
  store.users[String(id)] = user;
  persist();
  return nextLibrary;
}
