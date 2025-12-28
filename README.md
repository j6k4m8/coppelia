<h1 align=center>Coppelia</h1>
<p align="center">
  A native macOS app for Jellyfin music libraries (Windows/Linux/iOS/Android coming soon).
</p>

Coppelia is a cross-platform app designed for Jellyfin music libraries. macOS is the only supported platform right now, with other platforms coming soon. I built it because I couldn't find an app that was:

-   native / low-resource
-   beautiful
-   open source

If you hold in your heart other bulletpoints than these, please share and help make Coppelia better!

## Screenshots

| ![](./docs/Screenshot-Artist.jpg)   | ![](./docs/Screenshot-Queue.jpg)    |
| ----------------------------------- | ----------------------------------- |
| ![](./docs/Screenshot-Settings.jpg) | ![](./docs/Screenshot-Homepage.jpg) |

## Features

-   Jellyfin authentication
-   Fast library browsing and search (albums, artists, genres, playlists)
-   Audio playback with queue controls, play-next, and clear-queue
    -   macOS Now Playing integration + media key shortcuts
-   Favorite and unfavorite tracks/albums/artists
-   Playback resume that restores your last track and position when you reopen the app
-   Configurable home shelves, sidebar sections, and layout choices
-   Appearance controls: theme mode, font family, and font scale
-   Cached playlists/tracks/audio with size reporting and cache management
-   Artwork fallbacks and rich detail views with context actions
-   **NO ELECTRON 🫦**

## Roadmap

-   Android support
-   Windows, Linux, iOS support (can you help??)
-   Offline mode
-   Playlist creation and editing
-   More playback features (shuffle, repeat, etc)
-   Your idea here?

---

## Getting Started (Developer)

1. Install Flutter 3.3+ with desktop support enabled.
2. Run `flutter pub get`.
3. Launch the macOS app with `flutter run -d macos`.

Hot reload is available during `flutter run` as usual (`r` in the terminal or your IDE hot reload button).

## Tests

-   Run unit tests with `flutter test`.
-   Run integration tests with `flutter test integration_test` on a macOS target.

## Notes

-   The Jellyfin server URL should be your base URL (for example `https://jellyfin.example.com`).
-   Cached audio is stored using Flutter's cache manager to speed up repeat playback.
