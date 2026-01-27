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

-   App startup and shutdown events
-   Authentication attempts and results
-   API errors and network failures
-   Playback errors
-   Critical state changes

Sensitive information like passwords is **never** logged.

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
