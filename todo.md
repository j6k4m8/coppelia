# TODO

## HIGH PRIORITY

-   [ ] When a track is playing, the updating Now Playing section causes the entire application to re-render on each update, which makes the OS-level menu bar unusable, adds scroll janks, and thrashes performance.

## Bugs

-   [x] playback should require double-click (single click does not play).
-   [x] bug: search is janky, typing immediately selects all and next key replaces. multi ms lag on this.
-   [x] scroll alphabet should subsample uniformly based upon vertical space. So if your window is very vertically short, it doesn't show every letter.
-   [x] bug: light mode doesn't change backgrounds, it just changes text color and then it's invisible/ugly.
-   [x] scrub bar is progress-only and pulses while buffering
-   [x] when sidebar is invisible and play is on bottom instead, the search and weird icon thingy are misaligned, and float out in the middle of nowhere instead of on the right side. in fact, the weird icon thing can be totally eliminated altogether in all layouts.
-   [x] the giant greeting ("Good evening, jordan") should only appear on homepage, not on all pages. on other pages, that real estate should be used for page title.
-   [x] "prev" button should track to the start of the current track if more than 5s in, otherwise go to previous track.

## Features / Improvements

-   [x] add pages for artists, albums, genres
-   [x] add sidebar dropdown (like we already have for Playlists) for "Favorites"
    -   [x] albums
    -   [x] songs
    -   [x] artists
-   [x] implement search functionality
-   [x] integrate with macOS media controls and menubar stuff
-   [x] when starting mid-playlist, queue view should start at current index
-   [x] add settings page for cache management, themes, etc.
-   [x] make window chrome elegant (match theme)
-   [x] show subtle glowing loading bar while tracks buffer
-   [x] toggle now playing side vs bottom
-   [x] add right-click context menus for tracks, albums, artists
-   [x] homepage improvements
    -   [x] show recently played
    -   [x] the top right Coppelia icon should show version
-   [x] make all pages responsive
-   [x] make all albums, artists, genres, playlists clickable in track listings, cards, and now-playing
-   [x] add play history page, and queue page.
-   [x] on long listing pages (albums, artists, etc):
    -   [x] add back to top button
    -   [x] add toggle between list view and grid view
    -   [x] remember scroll position when navigating away and back
    -   [x] add first-char-prefix / quick scroll bar on the side when scrolling
-   [x] make sidebar scrollable and resizable
-   [x] move sign out button to settings page
-   [x] on homepage, library stats should be for whole library, not just playlist-visible items
-   [x] allow resizing arbitrary shapes for responsiveness, don't limit sizes
-   [x] "back" button is inside album card hero / page header. instead it should be left of the title of the page, left of the text.
-   [ ] add ability to clear queue
-   [ ] add "Albums" to artist pages
-   [ ] add link to artist page(s) from album page

## Low Priority

-   [ ] use Inter font
-   [ ] add auto build and release pipeline to github actions workflows
-   [ ] settings page has:
    -   [ ] toggle each section of homepage
    -   [ ] toggle each sidebar item
-   [x] make settings page a hamburger icon after Home, instead of button way at the bottom
-   [x] allow collapse of all sidebar sections, not just favs
-   [ ] indicate how much cache / disk space is being used by cached media
-   [x] in appearance/themes, allow tracking the system theme which overrides the light-dark setting.
-   [x] "good evening {user}" should be "welcome back {user}", "good morning {user}", afternoon, and:
    -   [x] 4-6am: "Some early bird tunes"
    -   [x] 10pm-4am: "Late night vibes"
-   [x] bug: the library stats header say "1 artist". that's definitely wrong.
-   [ ] on all pages the "card" hero should be part of the scrollable area, not fixed at the top.
-   [ ] should be able to click to navigate artist and album from now playing
-   [ ] playlists on the homepage should have a circular play button on them for single click play
-   [ ] scroll bounce jank
