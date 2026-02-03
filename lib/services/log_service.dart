import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for logging app events and errors to a file that users can share.
class LogService {
  static LogService? _instance;
  static Completer<LogService>? _initCompleter;
  File? _logFile;
  Completer<void> _writeLock = Completer<void>()
    ..complete(); // Initial lock is unlocked

  /// Maximum log file size (5 MB)
  static const int maxLogSize = 5 * 1024 * 1024;

  /// Maximum number of archived log files to keep
  static const int maxArchiveCount = 2;

  LogService._();

  /// Gets the singleton instance and initializes it if needed.
  static Future<LogService> get instance async {
    // If already initialized, return immediately
    if (_instance != null) {
      return _instance!;
    }

    // If initialization is in progress, wait for it
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    // Start initialization
    _initCompleter = Completer<LogService>();
    _instance = LogService._();

    try {
      await _instance!._initialize();
      _initCompleter!.complete(_instance!);
    } catch (e) {
      _initCompleter!.completeError(e);
      _instance = null;
      _initCompleter = null;
      rethrow;
    }

    return _instance!;
  }

  Future<void> _initialize() async {
    try {
      final directory = await _getLogsDirectory();
      _logFile = File('${directory.path}/coppelia.log');

      // Rotate log if it's too large
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > maxLogSize) {
          await _rotateLogs(directory);
        }
      }

      // Write session start marker
      await _writeLog('INFO', 'Log session started');

      // Capture Flutter errors
      _setupFlutterErrorCapture();
    } catch (e) {
      // Fail silently - logging shouldn't crash the app
      debugPrint('Failed to initialize logging: $e');
    }
  }

  void _setupFlutterErrorCapture() {
    // Capture Flutter framework errors
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log the error
      _writeLog('FLUTTER_ERROR', details.exception.toString());
      if (details.stack != null) {
        _writeLog('FLUTTER_ERROR', 'Stack: ${details.stack}');
      }
      // Call original handler if it exists
      originalOnError?.call(details);
    };
  }

  Future<Directory> _getLogsDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    final logsDir = Directory('${appSupport.path}/logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  Future<void> _rotateLogs(Directory directory) async {
    // Archive current log
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final archivePath = '${directory.path}/coppelia-$timestamp.log';
    await _logFile!.rename(archivePath);

    // Clean up old archives
    final archives = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('coppelia-') && f.path.endsWith('.log'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // Newest first

    if (archives.length > maxArchiveCount) {
      for (final old in archives.skip(maxArchiveCount)) {
        await old.delete();
      }
    }
  }

  /// Writes a log entry with thread-safe file access.
  /// Uses a lock pattern to prevent concurrent writes.
  Future<void> _writeLog(String level, String message) async {
    if (_logFile == null) return;

    // Wait for any pending write to complete (implements a write queue)
    await _writeLock.future;

    // Create new lock that will be released when this write completes
    final currentWrite = Completer<void>();
    _writeLock = currentWrite;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final entry = '[$timestamp] [$level] $message\n';

      // Append to file (each write is atomic)
      await _logFile!.writeAsString(entry, mode: FileMode.append);
    } catch (e) {
      // Don't use regular print to avoid potential recursion
      debugPrintSynchronously('Failed to write log: $e');
    } finally {
      // Release lock so next write can proceed
      currentWrite.complete();
    }
  }

  /// Logs an informational message.
  Future<void> info(String message) => _writeLog('INFO', message);

  /// Logs a warning message.
  Future<void> warning(String message) => _writeLog('WARN', message);

  /// Logs a debug/print-style message (for manual logging of console output).
  Future<void> print(String message) => _writeLog('PRINT', message);

  /// Logs an error message with optional error object and stack trace.
  Future<void> error(String message,
      [Object? error, StackTrace? stackTrace]) async {
    final errorText = error != null ? ' | Error: $error' : '';
    final stackText = stackTrace != null ? '\n$stackTrace' : '';
    await _writeLog('ERROR', '$message$errorText$stackText');
  }

  /// Logs a debug message (only in debug builds).
  Future<void> debug(String message) async {
    assert(() {
      _writeLog('DEBUG', message);
      return true;
    }());
  }

  /// Gets the path to the current log file for sharing.
  Future<String?> getLogFilePath() async {
    return _logFile?.path;
  }

  /// Gets all log content as a string for display or sharing.
  Future<String> getLogContent() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return 'No logs available';
    }

    try {
      // Try normal UTF-8 reading first
      return await _logFile!.readAsString();
    } catch (e) {
      // If UTF-8 decoding fails, try reading as bytes and decode with error handling
      try {
        final bytes = await _logFile!.readAsBytes();
        // Decode with replacement character (U+FFFD �) for invalid UTF-8 sequences
        const decoder = Utf8Decoder(allowMalformed: true);
        return decoder.convert(bytes);
      } catch (e2) {
        return 'Failed to read logs: $e (fallback also failed: $e2)';
      }
    }
  }

  /// Clears all logs.
  Future<void> clearLogs() async {
    // Wait for any pending writes to complete
    await _writeLock.future;

    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.delete();
    }

    // Reinitialize
    await _initialize();
  }

  /// Closes the log file (call on app shutdown).
  Future<void> close() async {
    await _writeLog('INFO', 'Log session ended');
    // Wait for final write to complete
    await _writeLock.future;
  }
}
