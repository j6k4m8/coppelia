# TODO

-   [ ] when you start loading a track (for playback), if it's not cached, do the "spinner" loading progress indicator on the track scrub bar. until it's ready to play. (still not working)
-   [x] remove "Offline only" filter chip (keep offline-only filtering behavior)
-   [x] add OS-level Android media session + notification controls (lockscreen/notification)
-   [ ] UI thrash: scroll gets janky again during updates (investigate repaint storms)
-   [ ] Android: generate app icons from `assets/logo_app_icon.svg`.
-   [x] Android: media session + notification controls (play/pause/next).
-   [ ] play controls
    -   [x] shuffle
    -   [ ] repeat queue / playlist
    -   [ ] repeat track
-   [x] on homepage, make all the cards have a no-margin art, NOT full bleed, but rather:
    -   [x] for side-by-side, the card art should be full height, with text to the right (with margin)
    -   [x] for cards where the art is above the text, art is full width (no margin), no bottom border radius, text below with margin. ditto playlists.
-   [ ] gestures:
    -   [ ] on mobile now playing bottom panel or side panel, swipe up to open full now playing screen, swipe left/right on the song art and text to skip tracks. should "smooth pursuit" the finger, with next/prev track art and text peeking out on sides when swiping.
    -   [ ] on mobile Now Playing popover screen, swipe down to dismiss, swipe left and right to skip tracks (should have album art of next/prev track peek out on sides when swiping)
    -   [ ] on mobile homepage, swipe right on "background" or left edge to open/close side nav. and swipe left on side nav or the darkened background to close side nav.
