# simple-ytapi

Fast scraping-based REST API for YouTube by Rex: search, video metadata, channels, playlists, trending, YouTube Music, and three download engines. Node.js 24 (ESM) + Express.js, four runtime dependencies, built for free container hosts (Northflank Developer Sandbox, Railway, Render).

## Features

- YouTube search: all, video, channel, playlist, shorts
- Video details with description, likes, related videos, chapters, comments (paginated)
- Channel details and channel videos / shorts / streams tabs
- Playlist details with video list
- Trending feed per region
- YouTube Music: search (10 filters), song with lyrics and stream URLs, artist, album, playlist, home, explore, charts, moods, suggestions
- Downloaders: V1 `@distube/ytdl-core`, V2 SSYouTube (PoW challenge solver in worker thread), V3 SnapYT (format listing), plus `/download/all` fallback chain
- API key auth (multi-key, timing-safe compare), rate limiting, Helmet, CORS, input validation, centralized error handling, process-level crash guards

## Quick start

    cp .env.example .env
    npm install
    npm start

Server runs on `PORT` (default 3000). Landing page: `http://localhost:3000/`. Interactive documentation and API tester: `http://localhost:3000/docs`.

## Configuration (.env)

| Variable | Default | Description |
|---|---|---|
| `PORT` | 3000 | Server port |
| `API_KEYS` | (empty = auth off) | Comma-separated API keys. Leave empty to disable auth |
| `RATE_LIMIT_WINDOW_MS` | 60000 | Rate limit window |
| `RATE_LIMIT_MAX` | 60 | Max requests per IP per window |
| `CACHE_TTL_MS` | 300000 | Cache TTL for scrape results |
| `CACHE_MAX_ENTRIES` | 500 | LRU cache size |
| `DEFAULT_REGION` | ID | Default gl/region for search and trending |
| `CORS_ORIGIN` | * | Comma-separated allowed origins, or * |
| `LOG_LEVEL` | info | info or warn |

## Authentication

Send the key in any of:

    X-API-Key: <key>
    Authorization: Bearer <key>
    ?api_key=<key>

All API endpoints live under the `/api` prefix. Health check `/api/health` and docs `/docs` do not require a key.

## Endpoints

General:

    GET /api/                      API info and endpoint list
    GET /api/health                Health check with cache stats

Search:

    GET /api/search?q=             All result types
    GET /api/search/video?q=       Videos only
    GET /api/search/channel?q=     Channels only
    GET /api/search/playlist?q=    Playlists only
    GET /api/search/shorts?q=      Shorts only

YouTube data:

    GET /api/video?id=             Video details (id = video ID or URL)
    GET /api/video/comments?id=    Comments (use continuation for next page)
    GET /api/channel?id=           Channel details (id = UC..., @handle, or URL)
    GET /api/channel/videos?id=    Channel tab videos (tab=videos|shorts|streams)
    GET /api/playlist?id=          Playlist details
    GET /api/trending?region=      Trending feed (region default ID)

YouTube Music:

    GET /api/music/search?q=&filter=   filter: songs videos albums artists playlists
                                   community_playlists featured_playlists podcasts
                                   episodes profiles
    GET /api/music/suggestions?q=      Search suggestions
    GET /api/music/song?id=            Song detail with lyrics, queue, related, stream
    GET /api/music/artist?id=          Artist page (UC...)
    GET /api/music/album?id=           Album tracks (MPREb...)
    GET /api/music/playlist?id=        Music playlist tracks (PL...)
    GET /api/music/home                Home feed
    GET /api/music/explore             Explore feed
    GET /api/music/charts              Charts
    GET /api/music/moods               Moods and genres
    GET /api/music/mood?browseId=&params=   Playlists for one mood
    GET /api/music/stream?id=          Direct audio/video stream URLs (IOS player)
    GET /api/music/audio?id=           Best audio stream only

Downloaders (return direct upstream URLs, not proxied):

    GET /api/download/v1?url=&type=&quality=   @distube/ytdl-core
    GET /api/download/v2?url=&type=&quality=   SSYouTube
    GET /api/download/v3?url=&type=&quality=   SnapYT
    GET /api/download/all?url=&type=           first engine that succeeds

`type` = `video` or `audio`. `quality` examples: `720` for video height, `128` for audio bitrate, `720p` accepted on V3.

Stream URL notes: V1/V2 URLs expire after ~6 hours; V2 tunnel links expire faster. Audio formats are native YouTube containers (m4a/webm/opus), not MP3 transcodes.

## Example

    curl -H "X-API-Key: YOUR_KEY" "http://localhost:3000/api/search/video?q=lofi"

    curl -H "X-API-Key: YOUR_KEY" "http://localhost:3000/download/v2?url=https://youtu.be/dQw4w9WgXcQ&type=audio&quality=320"

## Deploy to Northflank (recommended, free and always-on)

1. Push this folder to a GitHub repo
2. Northflank: create a project, then run the bundled template `northflank.template.json` (Templates, paste or via CLI):

       nf template run --file northflank.template.json \
         --argument GIT_ACCOUNT=<github-user> \
         --argument GIT_REPO=https://github.com/<github-user>/<repo> \
         --argument API_KEYS=<your-key>

   The template creates one Combined service (build + deploy) named simple-ytapi: Dockerfile build (node:24-alpine), deploy plan nf-compute-10, public port 3000, health check `/api/health`, runtime variables from the API_KEYS/DEFAULT_REGION arguments.
3. Manual alternative: create a Combined service, select the repo, build type Dockerfile, add a public port on 3000, and add the runtime variables (`API_KEYS` required, see Configuration above).

## Deploy to Railway (alternative)

1. Push this folder to a GitHub repo
2. railway.app: New Project, Deploy from repo (NIXPACKS builder is preconfigured in `railway.json`)
3. Variables: set `API_KEYS` (required in production), optional `DEFAULT_REGION`, `RATE_LIMIT_MAX`
4. Health check path `/health` is preconfigured

Memory footprint: ~90 MB RSS baseline, no native builds, no headless browser.

## Project structure

    src/
      server.js            Express app, security middleware, lifecycle
      config.js            Env parsing
      middleware.js        Rate limit, API key auth, validation, error handler
      routes.js            Route handlers + cache layer
      routes-registry.js   Endpoint metadata (feeds / and /docs)
      docs.js              Dashboard documentation + tester (single page)
      lib/http.js          Fetch wrapper, retry, probes, parsers
      lib/cache.js         TTL + LRU cache
      scrapers/
        search.js          YouTube search (ytInitialData)
        youtube.js         Video, comments, channel, playlist, trending
        music.js           YouTube Music InnerTube (WEB_REMIX + IOS player)
        downloader-v1.js   ytdl-core engine
        downloader-v2.js   SSYouTube engine (PoW in worker thread)
        downloader-v3.js   SnapYT engine

## Stability notes

- Downstream errors from YouTube are mapped to 400 (bad input), 403/404 (unplayable/private), 502 (upstream failure), 429 (rate limit), never a crash
- Unhandled rejections and uncaught exceptions are caught and logged without dropping the process
- Scraper requests carry timeouts and one retry with backoff
- Cache dedupes concurrent identical requests indirectly through short TTLs; heavy PoW work runs outside the event loop in a worker thread
