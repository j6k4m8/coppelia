/// Callback type for log messages.
typedef LogCallback = void Function(String level, String message);

/// Simple logger with pluggable callback.
class CastLogger {
  static LogCallback? _callback;

  /// Set a custom log callback. Pass null to disable logging.
  static void setCallback(LogCallback? callback) {
    _callback = callback;
  }

  /// Log a debug message.
  static void debug(String message) {
    _callback?.call('DEBUG', message);
  }

  /// Log an info message.
  static void info(String message) {
    _callback?.call('INFO', message);
  }

  /// Log a warning message.
  static void warning(String message) {
    _callback?.call('WARNING', message);
  }

  /// Log an error message.
  static void error(String message) {
    _callback?.call('ERROR', message);
  }
}
