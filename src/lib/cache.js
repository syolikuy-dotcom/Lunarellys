export class TtlCache {
  constructor(maxEntries = 500) {
    this.max = maxEntries;
    this.map = new Map();
    this.hits = 0;
    this.misses = 0;
  }

  get(key) {
    const entry = this.map.get(key);
    if (!entry) {
      this.misses++;
      return undefined;
    }
    if (entry.expires < Date.now()) {
      this.map.delete(key);
      this.misses++;
      return undefined;
    }
    this.map.delete(key);
    this.map.set(key, entry);
    this.hits++;
    return entry.value;
  }

  set(key, value, ttlMs) {
    if (this.map.size >= this.max) {
      const oldest = this.map.keys().next().value;
      this.map.delete(oldest);
    }
    this.map.set(key, { value, expires: Date.now() + ttlMs });
    return value;
  }

  delete(key) {
    return this.map.delete(key);
  }

  stats() {
    return { entries: this.map.size, hits: this.hits, misses: this.misses };
  }
}

export function cached(ttlMs, resolver, keyFn = null) {
  const cache = new TtlCache(typeof ttlMs === 'object' ? ttlMs.max : 500);
  const ttl = typeof ttlMs === 'object' ? ttlMs.ttl : ttlMs;
  return async (...args) => {
    const key = keyFn ? keyFn(...args) : JSON.stringify(args);
    const hit = cache.get(key);
    if (hit !== undefined) return hit;
    const value = await resolver(...args);
    cache.set(key, value, ttl);
    return value;
  };
}

export function makeKey(...parts) {
  return parts.map((p) => String(p ?? '')).join('|');
}
