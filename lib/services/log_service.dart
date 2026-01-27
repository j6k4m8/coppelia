import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Service for logging app events and errors to a file that users can share.
class LogService {
  static LogService? _instance;
  File? _logFile;
  IOSink? _sink;

  /// Maximum log file size (5 MB)
  static const int maxLogSize = 5 * 1024 * 1024;

  /// Maximum number of archived log files to keep
  static const int maxArchiveCount = 2;

  LogService._();

  /// Gets the singleton instance and initializes it if needed.
  static Future<LogService> get instance async {
    if (_instance == null) {
      _instance = LogService._();
      await _instance!._initialize();
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

      // Open for appending
      _sink = _logFile!.openWrite(mode: FileMode.append);

      // Write session start marker
      await _writeLog('INFO', 'Log session started');
    } catch (e) {
      // Fail silently - logging shouldn't crash the app
      print('Failed to initialize logging: $e');
    }
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

  Future<void> _writeLog(String level, String message) async {
    if (_sink == null) return;

    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] [$level] $message\n';

    try {
      _sink!.write(entry);
      await _sink!.flush();
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  /// Logs an informational message.
  Future<void> info(String message) => _writeLog('INFO', message);

  /// Logs a warning message.
  Future<void> warning(String message) => _writeLog('WARN', message);

  /// Logs an error message with optional error object and stack trace.
  Future<void> error(String message, [Object? error, StackTrace? stackTrace]) async {
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
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Failed to read logs: $e';
    }
  }

  /// Clears all logs.
  Future<void> clearLogs() async {
    await _sink?.close();
    _sink = null;

    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.delete();
    }

    // Reinitialize
    await _initialize();
  }

  /// Closes the log file (call on app shutdown).
  Future<void> close() async {
    await _writeLog('INFO', 'Log session ended');
    await _sink?.close();
    _sink = null;
  }
}
