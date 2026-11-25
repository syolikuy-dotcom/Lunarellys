import { Router } from 'express';
import { config, authEnabled } from './config.js';

function escapeHtml(text) {
  return String(text ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const PAGE = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>simple-ytapi — YouTube Data &amp; Media API</title>
<meta name="description" content="Fast scraping-based YouTube REST API for search, metadata, YouTube Music, and multi-engine media downloads.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #09090b;
    --surface: #111114;
    --surface-2: #16161a;
    --border: rgba(255, 255, 255, 0.08);
    --border-strong: rgba(255, 255, 255, 0.14);
    --fg: #f4f4f5;
    --fg-secondary: #a1a1aa;
    --fg-muted: #71717a;
    --sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    --mono: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  }

  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  html {
    scroll-behavior: smooth;
  }

  body {
    background-color: var(--bg);
    color: var(--fg);
    font-family: var(--sans);
    font-size: 14px;
    line-height: 1.5;
    -webkit-font-smoothing: antialiased;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    position: relative;
    overflow-x: hidden;
  }

  .backdrop {
    position: fixed;
    inset: 0;
    z-index: -1;
    pointer-events: none;
    background-image:
      radial-gradient(ellipse 80% 45% at 50% -10%, rgba(255, 255, 255, 0.075), transparent 70%),
      radial-gradient(rgba(255, 255, 255, 0.07) 1px, transparent 1px);
    background-size: 100% 100%, 24px 24px;
    mask-image: linear-gradient(to bottom, rgba(0, 0, 0, 1) 0%, rgba(0, 0, 0, 0.35) 65%, transparent 100%);
    -webkit-mask-image: linear-gradient(to bottom, rgba(0, 0, 0, 1) 0%, rgba(0, 0, 0, 0.35) 65%, transparent 100%);
  }

  a {
    color: inherit;
    text-decoration: none;
  }

  .topbar {
    position: sticky;
    top: 0;
    z-index: 20;
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    background: rgba(9, 9, 11, 0.78);
    border-bottom: 1px solid var(--border);
  }

  .topbar-inner {
    max-width: 960px;
    margin: 0 auto;
    padding: 14px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .brand {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    font-family: var(--mono);
    font-size: 13px;
    font-weight: 600;
    letter-spacing: -0.02em;
  }

  .brand-mark {
    width: 22px;
    height: 22px;
    border-radius: 6px;
    background: linear-gradient(180deg, #27272a 0%, #18181b 100%);
    border: 1px solid var(--border-strong);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12);
    display: grid;
    place-items: center;
  }

  .brand-tag {
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    background: var(--surface);
    border: 1px solid var(--border);
    padding: 1px 6px;
    border-radius: 4px;
  }

  .nav {
    display: flex;
    align-items: center;
    gap: 20px;
    font-size: 13px;
    color: var(--fg-secondary);
  }

  .nav a {
    transition: color 0.15s ease;
  }

  .nav a:hover {
    color: var(--fg);
  }

  .container {
    width: 100%;
    max-width: 960px;
    margin: 0 auto;
    padding: 0 24px;
    flex: 1;
  }

  .hero {
    padding: 64px 0 44px;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }

  .eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-family: var(--mono);
    font-size: 11.5px;
    color: var(--fg-secondary);
    background: var(--surface);
    border: 1px solid var(--border);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.05);
    padding: 4px 10px;
    border-radius: 999px;
    margin-bottom: 20px;
  }

  .eyebrow span {
    color: var(--fg-muted);
  }

  .hero h1 {
    font-size: clamp(28px, 4.8vw, 44px);
    font-weight: 600;
    letter-spacing: -0.035em;
    line-height: 1.12;
    max-width: 680px;
    background: linear-gradient(180deg, #ffffff 30%, #a1a1aa 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .hero p {
    margin-top: 14px;
    font-size: 15px;
    color: var(--fg-secondary);
    max-width: 540px;
    line-height: 1.6;
  }

  .hero-actions {
    margin-top: 26px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    height: 38px;
    padding: 0 16px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    transition: transform 0.12s ease, background-color 0.15s ease, border-color 0.15s ease;
  }

  .btn:active {
    transform: translateY(1px);
  }

  .btn-primary {
    background: #f4f4f5;
    color: #09090b;
    border: 1px solid #ffffff;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
  }

  .btn-primary:hover {
    background: #e4e4e7;
  }

  .btn-secondary {
    background: var(--surface);
    color: var(--fg);
    border: 1px solid var(--border-strong);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }

  .btn-secondary:hover {
    background: var(--surface-2);
    border-color: rgba(255, 255, 255, 0.22);
  }
  .console-wrap {
    max-width: 720px;
    margin: 4px auto 0;
    background: var(--surface);
    border: 1px solid var(--border-strong);
    border-radius: 12px;
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.07),
      0 20px 40px -24px rgba(0, 0, 0, 0.85);
    overflow: hidden;
  }

  .console-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 10px 14px;
    background: rgba(255, 255, 255, 0.02);
    border-bottom: 1px solid var(--border);
    flex-wrap: wrap;
  }

  .tabs {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .tab {
    background: transparent;
    border: 1px solid transparent;
    color: var(--fg-muted);
    font-family: var(--mono);
    font-size: 11.5px;
    padding: 5px 10px;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .tab:hover {
    color: var(--fg-secondary);
  }

  .tab.active {
    background: var(--surface-2);
    color: var(--fg);
    border-color: var(--border-strong);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }

  .console-meta {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .icon-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    background: var(--surface-2);
    border: 1px solid var(--border-strong);
    color: var(--fg-secondary);
    font-family: var(--mono);
    font-size: 11px;
    padding: 4px 10px;
    border-radius: 6px;
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease;
  }

  .icon-btn:hover {
    color: var(--fg);
    border-color: rgba(255, 255, 255, 0.25);
  }

  .request-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 11px 16px;
    background: #0c0c0e;
    border-bottom: 1px solid var(--border);
    font-family: var(--mono);
    font-size: 12px;
    overflow-x: auto;
  }

  .req-left {
    display: flex;
    align-items: center;
    gap: 10px;
    white-space: nowrap;
  }

  .method-badge {
    font-size: 10.5px;
    font-weight: 600;
    color: var(--fg);
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.12);
    padding: 2px 6px;
    border-radius: 4px;
  }

  .endpoint-url {
    color: var(--fg-secondary);
  }

  .endpoint-url b {
    color: var(--fg);
    font-weight: 500;
  }

  .console-body {
    display: grid;
    grid-template-columns: 1fr 1.15fr;
  }

  .pane {
    padding: 16px;
    font-family: var(--mono);
    font-size: 12.5px;
    line-height: 1.65;
    overflow-x: auto;
    background: rgba(0, 0, 0, 0.2);
  }

  .pane pre {
    white-space: pre;
    color: var(--fg-secondary);
    font-family: inherit;
  }

  .telemetry {
    margin-top: 24px;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
  }

  .stat-card {
    background: var(--surface);
    border: 1px solid var(--border);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
    border-radius: 10px;
    padding: 16px 18px;
  }

  .stat-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    color: var(--fg-muted);
    font-size: 12px;
  }

  .stat-val {
    margin-top: 6px;
    font-family: var(--mono);
    font-size: 21px;
    font-weight: 600;
    letter-spacing: -0.02em;
    font-variant-numeric: tabular-nums;
    color: var(--fg);
  }

  .section-head {
    margin-top: 52px;
    margin-bottom: 18px;
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }

  .section-head h2 {
    font-size: 16px;
    font-weight: 600;
    letter-spacing: -0.015em;
  }

  .section-head span {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--fg-muted);
  }

  .bento {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
  }

  .feature-card {
    background: var(--surface);
    border: 1px solid var(--border);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 22px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    gap: 16px;
    transition: border-color 0.2s ease, background-color 0.2s ease;
  }

  .feature-card:hover {
    border-color: var(--border-strong);
    background: var(--surface-2);
  }

  .feature-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .icon-box {
    width: 34px;
    height: 34px;
    border-radius: 8px;
    background: var(--bg);
    border: 1px solid var(--border-strong);
    display: grid;
    place-items: center;
    color: var(--fg);
  }

  .route-tag {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--fg-muted);
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid var(--border);
    padding: 3px 8px;
    border-radius: 5px;
  }

  .feature-card h3 {
    font-size: 15px;
    font-weight: 600;
    letter-spacing: -0.01em;
    margin-bottom: 6px;
  }

  .feature-card p {
    font-size: 13px;
    color: var(--fg-secondary);
    line-height: 1.55;
  }

  footer {
    margin-top: 64px;
    border-top: 1px solid var(--border);
  }

  .footer-inner {
    max-width: 960px;
    margin: 0 auto;
    padding: 22px 24px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    font-size: 12px;
    color: var(--fg-muted);
    gap: 6px;
  }

  @media (max-width: 768px) {
    .hero {
      padding: 44px 0 32px;
    }
    .telemetry {
      grid-template-columns: repeat(2, 1fr);
    }
    .bento {
      grid-template-columns: 1fr;
    }
  }

  @media (max-width: 480px) {
    .topbar-inner, .container, .footer-inner {
      padding-left: 16px;
      padding-right: 16px;
    }
    .nav {
      gap: 14px;
      font-size: 12.5px;
    }
    .hero-actions {
      width: 100%;
    }
    .hero-actions .btn {
      min-width: 180px;
    }
    .console-header {
      padding: 10px 12px;
    }
    .pane {
      padding: 14px 12px;
      font-size: 11.5px;
    }
  }
</style>
</head>
<body>
<div class="backdrop" aria-hidden="true"></div>

<header class="topbar">
  <div class="topbar-inner">
    <a href="/" class="brand">
      <span class="brand-mark">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polygon points="6 4 20 12 6 20 6 4"/></svg>
      </span>
      simple-ytapi
    </a>
  </div>
</header>

<main class="container">
  <section class="hero">
    <h1>YouTube Data, Music &amp; Media Extraction API.</h1>
    <p>Unified JSON endpoints for video search, metadata, YouTube Music streams, and multi-engine downloads behind a single API key.</p>
    <div class="hero-actions">
      <a class="btn btn-primary" href="/docs">
        Open Docs
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>
      </a>
    </div>
  </section>

  <section class="telemetry" aria-label="Service Metrics">
    <div class="stat-card">
      <div class="stat-top">
        <span>Endpoints</span>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><path d="M4 17l6-6-6-6"/><path d="M12 19h8"/></svg>
      </div>
      <div class="stat-val" id="st-endpoints">30</div>
    </div>
    <div class="stat-card">
      <div class="stat-top">
        <span>DL Engines</span>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8"/><path d="M12 17v4"/></svg>
      </div>
      <div class="stat-val" id="st-engines">3</div>
    </div>
    <div class="stat-card">
      <div class="stat-top">
        <span>Auth Mode</span>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
      </div>
      <div class="stat-val" id="st-auth">Key</div>
    </div>
    <div class="stat-card">
      <div class="stat-top">
        <span>Cache Entries</span>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>
      </div>
      <div class="stat-val" id="st-cache">0</div>
    </div>
  </section>

  <div class="section-head">
    <h2>Core Modules</h2>
  </div>

  <section class="bento" aria-label="Core Modules">
    <article class="feature-card">
      <div class="feature-top">
        <div class="icon-box">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
        </div>
      </div>
      <div>
        <h3>Unified Search</h3>
        <p>Filter queries across standard videos, channels, playlists, and Shorts with structured pagination.</p>
      </div>
    </article>

    <article class="feature-card">
      <div class="feature-top">
        <div class="icon-box">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
        </div>
      </div>
      <div>
        <h3>Rich Metadata</h3>
        <p>Video stats, comment threads, channel tabs, playlist items, and regional trending feeds.</p>
      </div>
    </article>

    <article class="feature-card">
      <div class="feature-top">
        <div class="icon-box">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>
        </div>
      </div>
      <div>
        <h3>YouTube Music</h3>
        <p>Tracks, synced lyrics, artist discographies, albums, charts, moods, and direct audio URLs.</p>
      </div>
    </article>

    <article class="feature-card">
      <div class="feature-top">
        <div class="icon-box">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        </div>
      </div>
      <div>
        <h3>Multi-Engine Downloader</h3>
        <p>Resilient video and audio extraction with automatic fallback across ytdl-core, SSYouTube, and SnapYT.</p>
      </div>
    </article>
  </section>
</main>

<footer>
  <div class="footer-inner">
    <span>simple ytapi — © Rex</span>
    <span>Independent scraping interface. Not affiliated with Google LLC.</span>
  </div>
</footer>

<script>
(function() {
  async function loadStats() {
    try {
      const [info, health] = await Promise.all([
        fetch('/api/').then(r => r.ok ? r.json() : null),
        fetch('/api/health').then(r => r.ok ? r.json() : null)
      ]);
      if (info) {
        if (Array.isArray(info.endpoints)) {
          document.getElementById('st-endpoints').textContent = info.endpoints.length;
        }
        if (typeof info.auth === 'string') {
          document.getElementById('st-auth').textContent = info.auth.toLowerCase().startsWith('api key') ? 'Key' : 'Open';
        }
      }
      if (health && health.cache && typeof health.cache.entries === 'number') {
        document.getElementById('st-cache').textContent = health.cache.entries.toLocaleString();
      }
    } catch (_) {
      document.getElementById('st-cache').textContent = '-';
    }
  }
  loadStats();
})();
</script>
</body>
</html>`;

export function buildIndexRouter() {
  const router = Router();
  router.get('/', (req, res) => {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.send(PAGE);
  });
  return router;
}

export function indexPage() {
  return PAGE;
}
