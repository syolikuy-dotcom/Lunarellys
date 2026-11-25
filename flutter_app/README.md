# Lunarellys Music — Flutter Client

A cross-platform Flutter music streaming client inspired by **Metrolist** (Material 3 Expressive, dynamic album art theming, synced lyrics), **Auralis** (charcoal & violet aesthetics, gesture-driven mini-player, adaptive phone/desktop navigation), and **Spotify** (quick-picks grid, editorial layout, seamless queue & radio).

## Features
- **Live Streaming & Range Proxy**: Connects to the Lunarellys Node.js backend (`/api/music/proxy-stream`) for zero-CORS, seekable audio playback via `just_audio` + `just_audio_background` lockscreen/notification controls.
- **Synced & Plain Lyrics**: Real-time LRC lyrics via `/api/music/lyrics` with auto-highlighting and tap-to-seek.
- **Dynamic Material 3 Colors**: Extracts dominant/vibrant colors from currently playing album artwork (`palette_generator`).
- **Offline Downloads**: Download tracks directly to device storage (`path_provider`) and play offline.
- **Pterodactyl Ready**: Configure your Pterodactyl Node.js panel URL (`http://IP:PORT` or `https://domain.com`) and optional API key directly inside **Library → Settings**, or pass `--dart-define=API_BASE_URL=...` at build time.

## Build Android APK (Zero-Issue Setup)

1. Navigate to `flutter_app`:
   ```bash
   cd flutter_app
   flutter pub get
   ```

2. (Optional) Bake your Pterodactyl backend URL directly into the APK:
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:PORT
   ```
   Or build directly with default config (you can change the server URL anytime inside the app's Settings screen):
   ```bash
   flutter build apk --release
   ```

3. Output APK location:
   `build/app/outputs/flutter-apk/app-release.apk`
