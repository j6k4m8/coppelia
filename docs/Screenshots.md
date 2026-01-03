# Screenshot generation

`Coppelia` exposes a dedicated integration test + helper to record consistent UI shots
for macOS and mobile platforms. Use this to capture any pages that are stable enough for
documentation or marketing.

## How it works

-   `integration_test/screenshots_test.dart` boots the app with real services, lands on the
    login screen (no session required), and asks the integration binding to write a PNG.
-   `integration_test/screenshot_helper.dart` centralizes the `takeScreenshot` wiring so
    future targets can reuse the same logic.
-   The generated files land under `build/screenshots/`; the helper script copies them
    into `docs/screenshots/<device>/` so the repository keeps a record of the latest captures.

## Running the generator

Use `tools/capture-screenshots.sh` to drive the test on every platform you care about:

```bash
./tools/capture-screenshots.sh --device macos --device "iPhone 17" --device "Pixel 9 Pro"
```

The script:

1. Ensures a writable Flutter SDK copy exists at `.flutter-sdk/` inside the repo (the
   script clones your system Flutter install the first time so we can write the cache
   stamps without hitting permission errors) and calls that copy with `flutter drive`.
2. Reads `build/flutter_driver_commands_0.log` after each run and extracts the base64
   screenshot that `IntegrationTestWidgetsFlutterBinding.reportData` publishes.
3. Saves the decoded PNG into `docs/screenshots/<device>/screenshot-<target>-<device>.png`
   and removes the temporary log.
4. Passes the `SCREENSHOT_TARGET` `dart-define` (default: `login`) straight through to
   the test so you can label the files however you like.
5. Optionally accepts `--server`, `--username`, and `--password` so that any non-login
   target can automatically sign into a Jellyfin server before capturing the UI.
6. Copies every `build/screenshots/*.png` into `docs/screenshots/<device>/`.

Repeat the command whenever you need fresh artwork. If you want to capture additional
pages, change `SCREENSHOT_TARGET` (for example: `--target settings` to grab the Settings
screen) or extend `screenshots_test.dart` to navigate inside the app before asking for a
frame.

## Output layout

-   `docs/screenshots/<device>/screenshot-<target>-<platform>.png`

For example: `docs/screenshots/macos/screenshot-login-macos.png`.
