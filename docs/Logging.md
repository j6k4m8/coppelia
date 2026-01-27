# Logging and Diagnostics

Coppelia includes a built-in logging system to help diagnose issues and troubleshoot problems users may encounter.

## Features

-   **Automatic log rotation**: Logs are automatically rotated when they reach 5 MB to prevent excessive disk usage
-   **Archive management**: Up to 2 archived log files are kept for historical reference
-   **Session tracking**: Each app launch creates a new log session with timestamps
-   **Error tracking**: Critical errors like authentication failures are automatically logged with stack traces

## Accessing Logs

Users can access logs through the app's Settings:

1. Open Coppelia
2. Go to **Settings** (Cmd+,)
3. Navigate to the **Account** tab
4. Scroll down to the **Diagnostics** section
5. Click **View logs**

## Log Dialog Features

The log viewer dialog provides several options:

-   **View logs**: See recent log entries in a scrollable viewer
-   **Copy**: Copy all log content to clipboard for sharing
-   **Copy path**: Copy the file path to access logs directly in Finder
-   **Show in Finder** (macOS only): Open the logs folder in Finder
-   **Clear logs**: Delete all logs and start fresh

## Log Location

Logs are stored in the app's Application Support directory:

-   **macOS**: `~/Library/Application Support/com.matelsky.coppelia/logs/coppelia.log`
-   **Linux**: `~/.local/share/com.matelsky.coppelia/logs/coppelia.log`
-   **Windows**: `%APPDATA%\com.matelsky.coppelia\logs\coppelia.log`

## Sharing Logs with Developers

When reporting issues on GitHub, including your logs can help developers diagnose problems faster:

1. Open the logs dialog in Settings → Account → Diagnostics
2. Click **Copy** to copy all logs to clipboard
3. Paste the logs in your GitHub issue
4. Alternatively, click **Copy path** and attach the log file directly

## What Gets Logged

The logging system captures:

-   **App lifecycle**: Startup and shutdown events with version information
-   **Authentication**: Login attempts, successes, and failures with error details
-   **Logged messages**: Calls to `LogService.instance.info()`, `.warning()`, `.error()`, `.debug()`, and `.print()`
-   **Flutter errors**: Framework errors and exceptions
-   **Playback flow**: Detailed tracking of the entire playback initialization process
    -   Playlist/album play requests
    -   Track fetching from server
    -   Queue setup and validation
    -   **Audio format details** (container, codec, bitrate, sample rate)
    -   Audio player state changes (playing, paused, buffering, loading)
    -   Track transitions with format information
    -   Play/pause/resume commands
-   **Network requests**: API calls to Jellyfin server with response status
-   **Errors**: All errors with full stack traces for debugging
-   **State changes**: Critical application state transitions

### Playback Logging Details

When you play music, the logs will show:

1. `playPlaylist` or `playAlbum` - Initial request to play content
2. `JellyfinClient: Fetching tracks` - Network request to Jellyfin server
3. `_playFromList: Starting with X tracks` - Queue preparation **with codec/format info**
    - Example: `[container=flac, codec=flac, bitrate=1411200, sampleRate=44100Hz]`
4. `_playFromList: Setting queue` - Audio player queue setup
5. `Playback action: set queue` - Queue set result (success/failure)
6. `Playback action: play` - Play command result
7. `Player state: playing=true, processingState=...` - Audio player state updates
8. `Current index changed` - Track changes
9. `Now playing: "Track Name" [container/codec]` - Current track with format info
    - Example: `Now playing: "Song Title" by Artist [flac/flac]`

This detailed logging helps diagnose freezing issues by showing exactly where the process stops. **The codec and container information is especially useful for identifying if certain formats (like WAV, FLAC, or high-bitrate files) are causing problems.**

Sensitive information like passwords and access tokens is **never** logged.

## For Developers

### Adding Log Statements

To add logging in your code:

```dart
import '../services/log_service.dart';

Future<void> myFunction() async {
  final logService = await LogService.instance;

  // Info level
  await logService.info('Something interesting happened');

  // Warning level
  await logService.warning('This might be a problem');

  // Error level with exception
  try {
    // ...
  } catch (error, stackTrace) {
    await logService.error('Operation failed', error, stackTrace);
  }

  // Debug (only in debug builds)
  await logService.debug('Detailed debugging info');
}
```

### Log Levels

-   **INFO**: General informational messages about app state
-   **WARN**: Warning messages about potential issues
-   **ERROR**: Error messages with optional error object and stack trace
-   **DEBUG**: Detailed debug information (only in debug builds)

### Best Practices

-   Log critical errors that users might report
-   Include context in log messages (what operation was being performed)
-   Don't log sensitive user data (passwords, tokens, personal info)
-   Use appropriate log levels
-   Keep log messages concise but informative
