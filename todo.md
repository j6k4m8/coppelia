# TODO

-   [ ] when you start loading a track (for playback), if it's not cached, do the "spinner" loading progress indicator on the track scrub bar. until it's ready to play. (still not working)
-   [ ] UI thrash: scroll gets janky again during updates (investigate repaint storms)
-   [ ] Android: generate app icons from `assets/logo_app_icon.svg`.
-   [ ] Android: media session + notification controls (play/pause/next).
-   [ ] play controls
    -   [x] shuffle
    -   [ ] repeat queue / playlist
    -   [ ] repeat track
-   [ ] on homepage, make all the cards have a no-margin art, NOT full bleed, but rather:
    -   [ ] for side-by-side, the card art should be full height, with text to the right (with margin)
    -   [ ] for cards where the art is above the text, art is full width (no margin), no bottom border radius, text below with margin. ditto playlists.
