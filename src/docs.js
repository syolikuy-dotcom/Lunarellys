import { Router } from 'express';
import { routes } from './routes-registry.js';
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
<title>Documentation — Archys API</title>
<meta name="description" content="Interactive REST API documentation and endpoint tester for Archys Music.">
<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 36 36'%3E%3Crect width='36' height='36' rx='10' fill='%230A0E11'/%3E%3Cpath d='M22.34 6.9A11.75 11.75 0 1 0 27.44 25.62A9.75 9.75 0 1 1 22.34 6.9Z' fill='%232EE89B'/%3E%3Crect x='21.25' y='10.75' width='2.8' height='11.5' rx='1.4' fill='white'/%3E%3Crect x='25.95' y='13.75' width='2.8' height='8.5' rx='1.4' fill='white'/%3E%3C/svg%3E">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;500;600&family=Plus+Jakarta+Sans:wght@500;600;700&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #070a0d;
    --surface: rgba(255, 255, 255, 0.055);
    --surface-2: rgba(255, 255, 255, 0.09);
    --surface-elevated: rgba(14, 21, 27, 0.72);
    --border: rgba(255, 255, 255, 0.085);
    --border-strong: rgba(255, 255, 255, 0.14);
    --specular: none;
    --accent: #12d88a;
    --accent-hi: #34f5a4;
    --cyan: #38bdf8;
    --fg: #f4f7f9;
    --fg-secondary: #a8b6c4;
    --fg-muted: #6c7a88;
    --sans: 'Plus Jakarta Sans', 'DM Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
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
    line-height: 1.55;
    -webkit-font-smoothing: antialiased;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    overflow-x: hidden;
  }

  .backdrop {
    position: fixed;
    inset: 0;
    z-index: -1;
    pointer-events: none;
    background:
      radial-gradient(ellipse 68% 48% at 14% -6%, rgba(18, 216, 138, 0.16), transparent 65%),
      radial-gradient(ellipse 56% 42% at 88% 8%, rgba(56, 189, 248, 0.14), transparent 65%),
      radial-gradient(ellipse 55% 45% at 50% 105%, rgba(18, 216, 138, 0.08), transparent 70%),
      radial-gradient(rgba(255, 255, 255, 0.05) 1px, transparent 1px);
    background-size: 100% 100%, 100% 100%, 100% 100%, 26px 26px;
  }

  a {
    color: inherit;
    text-decoration: none;
  }

  .topbar {
    position: sticky;
    top: 0;
    z-index: 30;
    background: rgba(9, 14, 19, 0.78);
    backdrop-filter: blur(14px) saturate(145%);
    -webkit-backdrop-filter: blur(14px) saturate(145%);
    border-bottom: 1px solid var(--border);
    box-shadow: inset 0 -1px 0 rgba(255, 255, 255, 0.04), 0 12px 32px rgba(0, 0, 0, 0.35);
  }

  .topbar-inner {
    max-width: 1280px;
    margin: 0 auto;
    padding: 12px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
  }

  .topbar-left {
    display: flex;
    align-items: center;
    gap: 11px;
    flex-wrap: wrap;
    min-width: 0;
  }

  .brand {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    font-family: var(--sans);
    font-size: 14px;
    font-weight: 700;
    letter-spacing: -0.02em;
  }

  .brand-mark {
    width: 30px;
    height: 30px;
    border-radius: 9px;
    background: linear-gradient(145deg, #121a1e 0%, #0a0e11 100%);
    border: 1px solid rgba(255, 255, 255, 0.12);
    display: grid;
    place-items: center;
    color: #effff8;
    flex-shrink: 0;
  }

  .sep {
    color: var(--fg-muted);
    font-family: var(--mono);
    font-size: 12px;
  }

  .page-label {
    font-size: 13px;
    color: var(--fg-secondary);
    font-weight: 500;
  }

  .menu-toggle {
    display: none;
    align-items: center;
    justify-content: center;
    gap: 6px;
    height: 36px;
    padding: 0 12px;
    border-radius: 12px;
    background: var(--surface);
    backdrop-filter: blur(18px);
    -webkit-backdrop-filter: blur(18px);
    border: 1px solid var(--border-strong);
    box-shadow: var(--specular);
    color: var(--fg);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
  }

  .shell {
    display: grid;
    grid-template-columns: 274px 1fr;
    max-width: 1280px;
    width: 100%;
    margin: 0 auto;
    flex: 1;
  }

  aside {
    border-right: 1px solid var(--border);
    background: rgba(10, 15, 20, 0.65);
    position: sticky;
    top: 55px;
    height: calc(100vh - 55px);
    overflow-y: auto;
    padding: 18px 14px 32px;
    scrollbar-width: thin;
    scrollbar-color: rgba(255, 255, 255, 0.14) transparent;
  }

  .search-wrap {
    position: relative;
    margin-bottom: 14px;
  }

  .search-wrap svg {
    position: absolute;
    left: 11px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--fg-muted);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    height: 38px;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid var(--border);
    box-shadow: var(--specular);
    border-radius: 12px;
    padding: 0 12px 0 34px;
    color: var(--fg);
    font-family: var(--sans);
    font-size: 12.5px;
    outline: none;
    transition: border-color 0.18s ease, background-color 0.18s ease;
  }

  .search-input::placeholder {
    color: var(--fg-muted);
  }

  .search-input:focus {
    border-color: rgba(52, 245, 164, 0.45);
    background: rgba(255, 255, 255, 0.09);
  }

  .nav-group {
    font-family: var(--mono);
    font-size: 10.5px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--fg-muted);
    padding: 14px 10px 6px;
  }

  .nav a {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 7px 10px;
    font-family: var(--mono);
    font-size: 11.5px;
    color: var(--fg-secondary);
    border-radius: 10px;
    border: 1px solid transparent;
    transition: background-color 0.15s ease, color 0.15s ease, border-color 0.15s ease;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .nav a:hover {
    background: rgba(255, 255, 255, 0.07);
    border-color: rgba(255, 255, 255, 0.1);
    color: var(--fg);
  }

  .m {
    font-family: var(--mono);
    font-size: 9.5px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 6px;
    letter-spacing: 0.04em;
    background: rgba(18, 216, 138, 0.14);
    border: 1px solid rgba(52, 245, 164, 0.28);
    color: var(--accent-hi);
    flex-shrink: 0;
  }

  main {
    padding: 36px 40px 64px;
    min-width: 0;
  }

  .doc-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
    flex-wrap: wrap;
    padding-bottom: 24px;
    border-bottom: 1px solid var(--border);
  }

  .doc-header h1 {
    font-size: clamp(24px, 3vw, 30px);
    font-weight: 700;
    letter-spacing: -0.03em;
    background: linear-gradient(135deg, #ffffff 25%, #b8f7dc 75%, #8ae2ff 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .doc-header p {
    color: var(--fg-secondary);
    margin-top: 6px;
    max-width: 620px;
    font-size: 13.5px;
    line-height: 1.6;
  }

  .doc-header code {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--fg);
    background: var(--surface-2);
    border: 1px solid var(--border);
    padding: 1px 6px;
    border-radius: 6px;
  }

  .badge {
    font-family: var(--mono);
    font-size: 11.5px;
    padding: 6px 12px;
    border: 1px solid var(--border-strong);
    border-radius: 999px;
    color: var(--fg-secondary);
    background: rgba(18, 25, 32, 0.72);
    white-space: nowrap;
  }

  .badge b {
    color: var(--accent-hi);
    font-weight: 600;
  }

  .auth-bar {
    margin-top: 20px;
    background: linear-gradient(145deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.025));
    border: 1px solid var(--border);
    box-shadow: 0 10px 24px rgba(0, 0, 0, 0.2);
    border-radius: 16px;
    padding: 13px 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    flex-wrap: wrap;
  }

  .auth-bar-left {
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 12.5px;
    font-weight: 500;
    color: var(--fg-secondary);
  }

  .auth-bar-left svg {
    color: var(--accent-hi);
    flex-shrink: 0;
  }

  .auth-input-group {
    display: flex;
    align-items: center;
    gap: 8px;
    flex: 1;
    max-width: 380px;
    min-width: 220px;
  }

  .auth-input-group input {
    height: 36px;
    font-family: var(--mono);
    font-size: 12px;
  }

  section.endpoint {
    background: linear-gradient(155deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.025));
    border: 1px solid var(--border);
    box-shadow: 0 8px 22px rgba(0, 0, 0, 0.18);
    border-radius: 16px;
    margin-top: 12px;
    overflow: hidden;
    content-visibility: auto;
    contain-intrinsic-size: 52px;
    transition: border-color 0.18s ease, box-shadow 0.18s ease;
  }

  section.endpoint:hover {
    border-color: var(--border-strong);
  }

  .ep-head {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 14px 16px;
    cursor: pointer;
    user-select: none;
    transition: background-color 0.15s ease;
  }

  .ep-head:hover {
    background: rgba(255, 255, 255, 0.045);
  }

  .ep-head h3 {
    font-family: var(--mono);
    font-size: 13px;
    font-weight: 500;
    color: var(--fg);
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ep-head .desc {
    font-size: 12.5px;
    color: var(--fg-muted);
    flex-shrink: 0;
    max-width: 46%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .caret {
    color: var(--fg-muted);
    display: grid;
    place-items: center;
    transition: transform 0.15s ease, color 0.15s ease;
    flex-shrink: 0;
  }

  .endpoint.open .caret {
    transform: rotate(90deg);
    color: var(--accent-hi);
  }

  .ep-body {
    display: none;
    border-top: 1px solid var(--border);
    padding: 18px 16px;
    background: rgba(5, 8, 11, 0.36);
  }

  .endpoint.open .ep-body {
    display: block;
  }

  .ep-desc-mobile {
    display: none;
    font-size: 13px;
    color: var(--fg-secondary);
    margin-bottom: 14px;
  }

  .table-wrap {
    overflow-x: auto;
    border: 1px solid var(--border);
    border-radius: 12px;
    background: rgba(7, 10, 14, 0.72);
    margin-bottom: 16px;
  }

  .params {
    width: 100%;
    border-collapse: collapse;
  }

  .params th {
    font-family: var(--mono);
    font-size: 10.5px;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-muted);
    text-align: left;
    padding: 9px 12px;
    border-bottom: 1px solid var(--border);
    background: rgba(255, 255, 255, 0.03);
  }

  .params td {
    padding: 9px 12px;
    border-bottom: 1px solid var(--border);
    font-size: 12.5px;
    color: var(--fg-secondary);
    vertical-align: top;
  }

  .params tr:last-child td {
    border-bottom: none;
  }

  .params td.pname {
    font-family: var(--mono);
    color: var(--fg);
    white-space: nowrap;
  }

  .req {
    font-family: var(--mono);
    color: var(--accent-hi);
    background: rgba(18, 216, 138, 0.12);
    border: 1px solid rgba(52, 245, 164, 0.25);
    font-size: 9.5px;
    padding: 1px 5px;
    border-radius: 5px;
    margin-left: 6px;
  }

  .opt {
    font-family: var(--mono);
    color: var(--fg-muted);
    font-size: 10px;
    margin-left: 6px;
  }

  .pty {
    font-family: var(--mono);
    color: var(--fg-muted);
    font-size: 11.5px;
  }

  .param-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 12px;
    margin-bottom: 16px;
  }

  .field label {
    display: block;
    font-family: var(--mono);
    font-size: 11px;
    color: var(--fg-secondary);
    margin-bottom: 5px;
  }

  input, select, textarea {
    width: 100%;
    height: 38px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--border);
    box-shadow: none;
    border-radius: 11px;
    color: var(--fg);
    padding: 0 12px;
    font-family: var(--mono);
    font-size: 12px;
    outline: none;
    transition: border-color 0.15s ease, background-color 0.15s ease;
  }

  input::placeholder {
    color: var(--fg-muted);
    font-family: var(--sans);
  }

  input:focus, select:focus, textarea:focus {
    border-color: rgba(52, 245, 164, 0.45);
    background: rgba(255, 255, 255, 0.08);
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    height: 36px;
    padding: 0 16px;
    border-radius: 999px;
    font-family: var(--sans);
    font-size: 12.5px;
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.18s cubic-bezier(0.22, 1, 0.36, 1), filter 0.15s ease, background-color 0.15s ease;
    background: linear-gradient(135deg, var(--accent-hi), var(--accent));
    border: 1px solid rgba(255, 255, 255, 0.14);
    box-shadow: 0 8px 20px rgba(18, 216, 138, 0.22);
    color: #03150d;
  }

  .btn:hover {
    filter: brightness(1.06);
  }

  .btn:active {
    transform: translateY(1px);
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-ghost {
    background: rgba(255, 255, 255, 0.07);
    border: 1px solid var(--border-strong);
    box-shadow: var(--specular);
    color: var(--fg-secondary);
  }

  .btn-ghost:hover {
    color: var(--fg);
    border-color: rgba(255, 255, 255, 0.28);
    background: rgba(255, 255, 255, 0.12);
    filter: none;
  }

  .btn-row {
    display: flex;
    gap: 10px;
    margin-top: 14px;
    flex-wrap: wrap;
    align-items: center;
  }

  .status {
    font-family: var(--mono);
    font-size: 11.5px;
    padding: 4px 10px;
    border-radius: 999px;
    display: none;
  }

  .status-ok {
    background: rgba(18, 216, 138, 0.14);
    border: 1px solid rgba(52, 245, 164, 0.32);
    color: var(--accent-hi);
    display: inline-block;
  }

  .status-err {
    background: rgba(239, 68, 68, 0.14);
    border: 1px solid rgba(239, 68, 68, 0.32);
    color: #fca5a5;
    display: inline-block;
  }

  .elapsed {
    color: var(--fg-muted);
    font-family: var(--mono);
    font-size: 11.5px;
    display: none;
  }

  .ex-label {
    font-family: var(--mono);
    font-size: 10.5px;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-muted);
    margin-bottom: 6px;
  }

  pre {
    background: rgba(7, 10, 14, 0.78);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 12px 14px;
    font-family: var(--mono);
    font-size: 12px;
    line-height: 1.55;
    color: var(--fg-secondary);
    overflow: auto;
    max-height: 420px;
    white-space: pre;
  }

  .grid2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .live-out {
    margin-top: 12px;
    border-color: var(--border-strong);
    color: var(--fg);
  }

  footer {
    margin-top: 56px;
    padding-top: 24px;
    border-top: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    color: var(--fg-muted);
    font-size: 12px;
    gap: 6px;
  }

  @media (prefers-reduced-motion: reduce) {
    html {
      scroll-behavior: auto;
    }
    * {
      transition: none !important;
      animation: none !important;
    }
  }

  @media (max-width: 900px) {
    .menu-toggle {
      display: inline-flex;
    }

    .shell {
      grid-template-columns: 1fr;
    }

    aside {
      display: none;
      position: fixed;
      top: 55px;
      left: 0;
      right: 0;
      bottom: 0;
      height: calc(100vh - 55px);
      z-index: 25;
      background: rgba(8, 12, 16, 0.94);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      border-right: none;
      padding: 16px 20px 40px;
    }

    aside.open {
      display: block;
    }

    main {
      padding: 24px 16px 56px;
    }

    .ep-head .desc {
      display: none;
    }

    .ep-desc-mobile {
      display: block;
    }

    .grid2 {
      grid-template-columns: 1fr;
    }
  }

  @media (max-width: 480px) {
    .topbar-inner {
      padding: 12px 16px;
    }

    .auth-bar {
      flex-direction: column;
      align-items: stretch;
    }

    .auth-input-group {
      max-width: 100%;
    }
  }
</style>
</head>
<body>
<div class="backdrop" aria-hidden="true"></div>

<header class="topbar">
  <div class="topbar-inner">
    <div class="topbar-left">
      <a href="/" class="brand">
        <span class="brand-mark" aria-hidden="true">
          <svg width="20" height="20" viewBox="0 0 108 108" fill="none">
            <path d="M54 24L76 80H65L54 50L43 80H32L54 24Z" fill="#F5F8FC"/>
            <rect x="42" y="60" width="24" height="7" rx="3.5" fill="#5DA7E8"/>
          </svg>
        </span>
        Archys
      </a>
      <span class="sep">/</span>
      <span class="page-label">API Docs</span>
    </div>
    <button type="button" class="menu-toggle" id="menu-toggle" aria-expanded="false" aria-controls="sidebar">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="4" y1="7" x2="20" y2="7"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="17" x2="20" y2="17"/></svg>
      Endpoints
    </button>
  </div>
</header>

<div class="shell">
  <aside id="sidebar">
    <div class="search-wrap">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
      <input type="search" class="search-input" id="nav-filter" placeholder="Filter endpoints..." autocomplete="off">
    </div>
    <nav class="nav" id="nav"></nav>
  </aside>

  <main>
    <header class="doc-header">
      <div>
        <h1>API Documentation</h1>
        <p>All endpoints accept HTTP <code>GET</code> requests and return structured JSON. Authenticate via the <code>X-API-Key</code> header, <code>Authorization: Bearer</code>, or <code>api_key</code> query parameter.</p>
      </div>
      <div class="badge" id="authbadge">checking...</div>
    </header>

    <div class="auth-bar">
      <div class="auth-bar-left">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
        <span>Session API Key</span>
      </div>
      <div class="auth-input-group">
        <input type="password" id="apikey-in" placeholder="Paste X-API-Key (stored in current tab)">
        <button type="button" class="btn btn-ghost" id="toggle-key">Show</button>
      </div>
    </div>

    <section class="endpoint open" id="ep-root">
      <div class="ep-head" data-toggle="ep-root">
        <span class="m">GET</span>
        <h3>/api/</h3>
        <span class="desc">Service metadata and endpoint index</span>
        <span class="caret">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
        </span>
      </div>
      <div class="ep-body">
        <p class="ep-desc-mobile">Service metadata and endpoint index</p>
        <div class="grid2">
          <div>
            <div class="ex-label">Request</div>
            <pre>GET /api/</pre>
          </div>
          <div>
            <div class="ex-label">Response</div>
            <pre>{
  "success": true,
  "name": "Archys REST API",
  "service": "archys-api",
  "version": "4.3.6",
  "auth": "open",
  "region": "ID"
}</pre>
          </div>
        </div>
        <div class="btn-row">
          <button type="button" class="btn" data-run-root="/api/">Send Request</button>
          <span class="status" id="st-root"></span>
          <span class="elapsed" id="el-root"></span>
        </div>
        <pre class="live-out" id="out-root" style="display:none"></pre>
      </div>
    </section>

    <section id="sections"></section>

    <footer>
      <span>Archys Music API Documentation</span>
      <span>Responses are cached server-side. Stream URLs expire after ~6 hours.</span>
    </footer>
  </main>
</div>

<script>
const GROUPS = ${JSON.stringify(routes).replace(/</g, '\\u003c')};
let API_KEY = sessionStorage.getItem('yt_api_key') || '';

function esc(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function getGroupName(path) {
  const seg = (path.startsWith('/api/') ? path.slice(5) : path.replace('/', '')).split('/')[0] || 'root';
  if (seg.startsWith('search')) return 'search';
  if (seg.startsWith('music')) return 'youtube music';
  if (seg.startsWith('download')) return 'downloader';
  if (seg === 'video' || seg === 'channel' || seg === 'playlist' || seg === 'trending') return 'youtube data';
  return 'general';
}

function renderNav(filter = '') {
  const nav = document.getElementById('nav');
  const q = filter.trim().toLowerCase();
  const groups = {};

  for (const r of GROUPS) {
    if (q && !r.path.toLowerCase().includes(q) && !(r.description || '').toLowerCase().includes(q)) {
      continue;
    }
    const name = getGroupName(r.path);
    (groups[name] = groups[name] || []).push(r);
  }

  let html = '';
  for (const [name, items] of Object.entries(groups)) {
    html += '<div class="nav-group">' + esc(name) + '</div>';
    for (const r of items) {
      const id = 'ep-' + r.path.replace(/[^a-z0-9]/gi, '_');
      html += '<a href="#' + id + '" data-nav-target="' + id + '"><span class="m">GET</span>' + esc(r.path) + '</a>';
    }
  }
  nav.innerHTML = html || '<div class="nav-group">No matching routes</div>';
}

function paramInputs(r, id) {
  if (!r.params || !r.params.length) return '';
  let html = '<div class="table-wrap"><table class="params"><thead><tr><th>Parameter</th><th>Type</th><th>Description</th></tr></thead><tbody>';
  for (const p of r.params) {
    html += '<tr>'
      + '<td class="pname">' + esc(p.name) + (p.required ? '<span class="req">required</span>' : '<span class="opt">optional</span>') + '</td>'
      + '<td class="pty">' + esc(p.type) + '</td>'
      + '<td>' + esc(p.description) + '</td>'
      + '</tr>';
  }
  html += '</tbody></table></div>';
  html += '<div class="param-grid">';
  for (const p of r.params) {
    html += '<div class="field">'
      + '<label for="p-' + id + '-' + esc(p.name) + '">' + esc(p.name) + '</label>'
      + '<input id="p-' + id + '-' + esc(p.name) + '" data-param="' + esc(p.name) + '" placeholder="' + esc(p.description || '') + '">'
      + '</div>';
  }
  html += '</div>';
  return html;
}

function renderSections() {
  const root = document.getElementById('sections');
  let html = '';
  for (const r of GROUPS) {
    const id = 'ep-' + r.path.replace(/[^a-z0-9]/gi, '_');
    html += '<section class="endpoint" id="' + id + '">'
      + '<div class="ep-head" data-toggle="' + id + '">'
      + '<span class="m">GET</span>'
      + '<h3>' + esc(r.path) + '</h3>'
      + '<span class="desc">' + esc(r.description) + '</span>'
      + '<span class="caret"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg></span>'
      + '</div>'
      + '<div class="ep-body" data-rendered="0"></div></section>';
  }
  root.innerHTML = html;
}

function hydrateEndpoint(id) {
  const section = document.getElementById(id);
  if (!section) return;
  const body = section.querySelector('.ep-body');
  if (!body || body.dataset.rendered === '1') return;

  const r = GROUPS.find((x) => 'ep-' + x.path.replace(/[^a-z0-9]/gi, '_') === id);
  if (!r) return;

  body.innerHTML = '<p class="ep-desc-mobile">' + esc(r.description) + '</p>'
    + paramInputs(r, id)
    + '<div class="grid2">'
    + '<div><div class="ex-label">Example Request</div><pre>' + esc(r.example.request) + '</pre></div>'
    + '<div><div class="ex-label">Example Response</div><pre>' + esc(r.example.response) + '</pre></div>'
    + '</div>'
    + '<div class="btn-row">'
    + '<button type="button" class="btn" data-run-ep="' + id + '">Send Request</button>'
    + '<span class="status" id="st-' + id + '"></span>'
    + '<span class="elapsed" id="el-' + id + '"></span>'
    + '</div>'
    + '<pre class="live-out" id="out-' + id + '" style="display:none"></pre>';
  body.dataset.rendered = '1';
}

function buildUrl(id) {
  const r = GROUPS.find((x) => 'ep-' + x.path.replace(/[^a-z0-9]/gi, '_') === id);
  const container = document.getElementById(id);
  const inputs = container.querySelectorAll('input[data-param]');
  const qs = new URLSearchParams();
  for (const input of inputs) {
    const v = input.value.trim();
    if (v) qs.set(input.dataset.param, v);
  }
  return r.path + (qs.toString() ? '?' + qs.toString() : '');
}

function setStatus(id, cls, text, ms) {
  const st = document.getElementById('st-' + id);
  const el = document.getElementById('el-' + id);
  st.className = 'status ' + cls;
  st.textContent = text;
  el.style.display = 'inline';
  el.textContent = ms + 'ms';
}

async function runTest(path, id) {
  const out = document.getElementById('out-' + id);
  const btns = document.querySelectorAll('button[data-run-ep], button[data-run-root]');
  btns.forEach((b) => { b.disabled = true; });
  const t0 = performance.now();

  try {
    const headers = {};
    if (API_KEY) headers['X-API-Key'] = API_KEY;
    const res = await fetch(path, { headers });
    const ms = Math.round(performance.now() - t0);
    const json = await res.json();
    setStatus(id, res.ok ? 'status-ok' : 'status-err', res.status + ' ' + res.statusText, ms);
    out.textContent = JSON.stringify(json, null, 2);
    out.style.display = 'block';
  } catch (err) {
    setStatus(id, 'status-err', 'network error', Math.round(performance.now() - t0));
    out.textContent = String(err);
    out.style.display = 'block';
  } finally {
    btns.forEach((b) => { b.disabled = false; });
  }
}

document.addEventListener('click', (e) => {
  const head = e.target.closest('[data-toggle]');
  if (head) {
    const id = head.dataset.toggle;
    const target = document.getElementById(id);
    if (target) {
      if (id !== 'ep-root') hydrateEndpoint(id);
      target.classList.toggle('open');
    }
    return;
  }

  const navLink = e.target.closest('[data-nav-target]');
  if (navLink) {
    const id = navLink.dataset.navTarget;
    const target = document.getElementById(id);
    if (target) {
      hydrateEndpoint(id);
      target.classList.add('open');
    }
    const sidebar = document.getElementById('sidebar');
    const toggle = document.getElementById('menu-toggle');
    sidebar.classList.remove('open');
    toggle.setAttribute('aria-expanded', 'false');
    return;
  }

  const runRootBtn = e.target.closest('[data-run-root]');
  if (runRootBtn) {
    runTest(runRootBtn.dataset.runRoot, 'root');
    return;
  }

  const runEpBtn = e.target.closest('[data-run-ep]');
  if (runEpBtn) {
    const id = runEpBtn.dataset.runEp;
    runTest(buildUrl(id), id);
  }
});

const menuToggle = document.getElementById('menu-toggle');
const sidebar = document.getElementById('sidebar');
menuToggle.addEventListener('click', () => {
  const isOpen = sidebar.classList.toggle('open');
  menuToggle.setAttribute('aria-expanded', String(isOpen));
});

document.getElementById('nav-filter').addEventListener('input', (e) => {
  renderNav(e.target.value);
});

const kin = document.getElementById('apikey-in');
const toggleKeyBtn = document.getElementById('toggle-key');
kin.value = API_KEY;
kin.addEventListener('input', () => {
  API_KEY = kin.value.trim();
  sessionStorage.setItem('yt_api_key', API_KEY);
});
toggleKeyBtn.addEventListener('click', () => {
  const hidden = kin.type === 'password';
  kin.type = hidden ? 'text' : 'password';
  toggleKeyBtn.textContent = hidden ? 'Hide' : 'Show';
});

async function loadAuthBadge() {
  try {
    const info = await fetch('/api/').then((r) => r.json());
    document.getElementById('authbadge').innerHTML = info.auth && info.auth.startsWith('API key')
      ? 'auth <b>required</b>'
      : 'auth <b>open</b>';
  } catch {
    document.getElementById('authbadge').textContent = 'offline';
  }
}

renderNav();
renderSections();
loadAuthBadge();
</script>
</body>
</html>`;

export function buildDocsRouter() {
  const router = Router();
  router.get('/', (req, res) => {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.send(PAGE);
  });
  return router;
}
