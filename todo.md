# TODO

-   [x] when sidebar now-playing, center the prev-play-next widgets.
-   [ ] when you start loading a track (for playback), if it's not cached, do the "spinner" loading progress indicator on the track scrub bar. until it's ready to play. (still not working)
-   [x] search should search entire library, not just tracks. artists, albums, playlists, etc. different headers for each type of result.
-   [x] app icons! use the fermata icon from the app sidebar.
-   [x] replace the "Home" link with just clicking the app name.
-   [x] add ios CI build and release.
-   [ ] cache eviction does not actually delete off disk, and we accumulate stuff on disk over time.
    -   [ ] cache max size (default to 500MB?)
    -   [ ] cache size reporting in settings should reflect on disk
    -   [ ] "clear cache" should delete files off disk.
    -   [ ] default is LRU cache eviction
        -   [ ] add right-click context menu on track/album/artist to "Make available offline" (pin to cache)
    -   [ ] add "Available offline" section to sidebar (Albums, Artists, Playlists, Tracks)
-   [ ] appearance: add "compact" mode with less padding; three-way switch "Sardinemode" | "Comfortable" | "Spacious"
-   [ ] UI thrash: scroll gets janky again during updates (investigate repaint storms)
-   [ ] Tracks browse should load alphabetically so pagination doesn't fetch items above the viewport.
-   [ ] Tracks browse should include the alphabet scroller widget.
