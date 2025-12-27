# Coppelia

Coppelia is a cross-platform Flutter client designed for Jellyfin music libraries with a macOS-first aesthetic. It blends a polished, glassy UI with native Flutter rendering so the experience feels fast and at home on the desktop.

## Features

- Jellyfin authentication and playlist browsing
- Featured track shelf and playlist detail view
- Audio playback with queue controls
- Cached playlists, tracks, and audio streams
- macOS-focused styling inspired by premium music apps

## Getting Started

1. Install Flutter 3.3+ with desktop support enabled.
2. Run `flutter pub get`.
3. Launch the macOS app with `flutter run -d macos`.

Hot reload is available during `flutter run` as usual (`r` in the terminal or your IDE hot reload button).

## Tests

- Run unit tests with `flutter test`.
- Run integration tests with `flutter test integration_test` on a macOS target.

## Notes

- The Jellyfin server URL should be your base URL (for example `https://jellyfin.example.com`).
- Cached audio is stored using Flutter's cache manager to speed up repeat playback.
