# Lunarellys Music Platform

Full-stack **Lunarellys** music streaming platform — Node.js 20+ (ESM) + Express backend, built-in Web Player, interactive REST API docs, and a Flutter Android/Desktop client, developed by **Ikhwan Romadon**.

## Quick Setup for Pterodactyl / VPS / Docker

1. Clone or upload this repository to your Pterodactyl Node.js Egg (Node.js 20 or 22 recommended).
2. Set Startup Command:
   ```bash
   npm install --omit=dev && npm start
   ```
3. Configure Environment Variables (optional — works plug-and-play out of the box!):
   - `PORT` or `SERVER_PORT`: Automatically mapped by Pterodactyl Allocation (e.g. `4686`).
   - `PUBLIC_BASE_URL`: Set to your node URL if behind a proxy or direct HTTP port, e.g. `http://nodedenisrealbaik.sinar.bonus.smasnug.web.id:4686`.
   - `API_KEYS`: Leave empty for open plug-and-play access, or set comma-separated keys.
   - `ADMIN_PASSCODE`: Optional passcode for `/api/admin/stats` & `/docs`.
   - `PUBLIC_DOCS`: Set `true` to make `/docs` accessible without admin passcode.
   - `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`: Optional Google OAuth 2.0 credentials for synced playlists/likes. Authorized redirect URI: `<PUBLIC_BASE_URL>/api/auth/google/callback`.

## Key Endpoints

- `GET /` — **Lunarellys Web Player**
- `GET /docs` — **Interactive API Documentation & Tester**
- `GET /api/node/info` — **Public Node Discovery** (used by Flutter & Web 1-tap server setup)
- `GET /api/health` — **Health Check & Cache Stats**
- `GET /api/music/*` — Home, Explore, Charts, Moods, Search, Suggestions, Song, Artist, Album, Playlist, Lyrics, Radio, Range-aware `/proxy-stream`, Artwork proxy
- `GET /api/auth/*` & `GET|PUT /api/user/sync` — Google OAuth & Cloud Library Sync

## Building the Flutter App

See `flutter_app/README.md` for build instructions and default node overrides (`--dart-define=API_BASE_URL=http://nodedenisrealbaik.sinar.bonus.smasnug.web.id:4686`).
