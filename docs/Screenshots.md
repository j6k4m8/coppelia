# Screenshot generation

`Coppelia` exposes a dedicated integration test + helper to record consistent UI shots
for macOS and mobile platforms. Use this to capture current app pages straight from your
real Jellyfin account and save the latest PNGs into the repo.

## How it works

-   `integration_test/screenshots_test.dart` boots the app with real services, lands on the
    login screen (no session required), optionally signs into your real Jellyfin server,
    drives the app to a named target, and asks the integration binding to write a PNG.
-   `integration_test/screenshot_helper.dart` centralizes the `takeScreenshot` wiring so
    future targets can reuse the same logic.
-   The helper script reads the test output from `build/flutter_driver_commands_0.log`,
    decodes the reported PNG, and writes it into `docs/screenshots/<device>/`.

## Running the generator

Create a local `.screenshot.env` from the checked-in example:

```bash
cp .screenshot.env.example .screenshot.env
```

Fill in your real Jellyfin server, username, and password. The file is ignored by git.

Then use `tools/capture-screenshots.sh` to drive the test on every platform you care about:

```bash
./tools/capture-screenshots.sh --device macos --device "iPhone 17" --device "Pixel 9 Pro"
```

If `.screenshot.env` is present, the script automatically captures the default authenticated
suite:

-   `home`
-   `albums`
-   `artists`
-   `tracks`
-   `playlists`
-   `album-detail`
-   `artist-detail`
-   `queue`
-   `settings`

Without credentials, the script falls back to the unauthenticated `login` screen only.

You can still run specific targets directly:

```bash
./tools/capture-screenshots.sh \
  --device macos \
  --target home \
  --target album-detail \
  --target queue
```

The script:

1. Ensures a writable Flutter SDK copy exists at `.flutter-sdk/` inside the repo (the
   script clones your system Flutter install the first time so we can write the cache
   stamps without hitting permission errors) and calls that copy with `flutter drive`.
2. Reads `build/flutter_driver_commands_0.log` after each run and extracts the base64
   screenshot that `IntegrationTestWidgetsFlutterBinding.reportData` publishes.
3. Saves the decoded PNG into `docs/screenshots/<device>/screenshot-<target>-<device>.png`
   and removes the temporary log.
4. Loads auth from `.screenshot.env`, `--env-file`, the `SCREENSHOT_*` environment
   variables, or explicit `--server` / `--username` / `--password` flags.
5. Passes the `SCREENSHOT_TARGET` `dart-define` straight through to the test so you can
   capture specific top-level views and detail pages without tapping through the UI.

Repeat the command whenever you need fresh artwork. If you want to capture additional
pages, pass more `--target` values or extend `screenshots_test.dart` with another target.

## Available targets

-   `login`
-   `home`
-   `albums`
-   `artists`
-   `tracks`
-   `playlists`
-   `album-detail`
-   `artist-detail`
-   `playlist-detail`
-   `queue`
-   `settings`

`queue` will seed playback from your real library when the queue is empty so the screen
has actual content. That means it can briefly start a real track before the script pauses
playback again.

## Output layout

-   `docs/screenshots/<device>/screenshot-<target>-<device>.png`

For example: `docs/screenshots/macos/screenshot-login-macos.png`.
