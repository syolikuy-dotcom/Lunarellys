# Lunarellys Music — Flutter Client

A cross-platform Flutter music streaming client developed by **Ikhwan Romadon**, combining obsidian emerald editorial layouts, dynamic album artwork theming, synced LRC lyrics, customizable player styles, and seamless Pterodactyl self-hosted node support.

## Features
- **Live Streaming & Range Proxy**: Connects to your Lunarellys Node.js / Pterodactyl backend (`/api/music/proxy-stream`) for zero-CORS, seekable audio playback via `just_audio` + `just_audio_background`.
- **Synced & Plain Lyrics**: Real-time LRC lyrics via `/api/music/lyrics` with auto-highlighting and tap-to-seek.
- **Customizable Player & Slider Styles**: Switch between **Blur**, **Classic**, **Glow Animated**, and **Live Mesh** player backdrops plus **Default**, **Wavy**, **Slim**, and **Squiggly** progress sliders directly inside **Settings**.
- **Dynamic Album Colors & Persistent Queue**: Extracts vibrant palette colors from album artwork (`palette_generator`) and restores your active queue across restarts.
- **Offline Downloads**: Download tracks directly to device storage (`path_provider`) and listen offline.
- **1-Tap Pterodactyl Setup**: Connect to any Pterodactyl node (e.g. `http://nodedenisrealbaik.sinar.bonus.smasnug.web.id:4686/`) via the hidden admin panel (tap the version card in **About** 7×, then enter the Admin Passcode) with live `/api/node/info` health probing, or bake it in at build time with `--dart-define=API_BASE_URL=...`.

## Build Android APK (Zero-Issue Setup)

1. Navigate to `flutter_app`:
   ```bash
   cd flutter_app
   flutter pub get
   ```

2. (Optional) Bake your Pterodactyl backend URL directly into the APK:
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=http://nodedenisrealbaik.sinar.bonus.smasnug.web.id:4686
   ```
   Or build directly with default config (admins and users can change or test the server URL anytime inside **Settings**):
   ```bash
   flutter build apk --release
   ```

3. Output APK location:
   `build/app/outputs/flutter-apk/app-release.apk`
