<h1 align=center>Coppelia</h1>
<p align="center">
  A native macOS + iOS app for Jellyfin music libraries (Windows/Linux/Android coming soon).
</p>
<p align="center">
  <img src="https://img.shields.io/badge/iPhone+iPad-000000?style=for-the-badge&logo=ios&logoColor=white" alt="iOS Supported"/>&nbsp;
    <img src="https://img.shields.io/badge/Platform-macOS-333333?style=for-the-badge&logo=apple&logoColor=white" alt="macOS Platform"/> &nbsp;
  <img src="https://img.shields.io/badge/Framework-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter Framework"/>
</p>

Coppelia is a cross-platform app designed for Jellyfin music libraries. I built it because I couldn't find an app that was:

-   native / low-resource
-   beautiful
-   open source

If you hold in your heart other bulletpoints than these, please share and help make Coppelia better!

## Screenshots

| ![](./docs/Screenshot-Artist.jpg)   | ![](./docs/Screenshot-Queue.jpg)    |
| ----------------------------------- | ----------------------------------- |
| ![](./docs/Screenshot-Settings.jpg) | ![](./docs/Screenshot-Homepage.jpg) |

|                           |                            |                           |                             |
| ------------------------- | -------------------------- | ------------------------- | --------------------------- |
| ![](docs/iPhone-Auth.png) | ![](docs/iPhone-Cache.png) | ![](docs/iPhone-Home.png) | ![](docs/iPhone-Tracks.png) |

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

## Developing

-   macOS: `docs/Developing-macOS.md`
-   iOS (Simulator): `docs/Developing-iOS.md`

## Notes

-   The Jellyfin server URL should be your base URL (for example `https://jellyfin.example.com`).
-   Cached audio is stored using Flutter's cache manager to speed up repeat playback.
