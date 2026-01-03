import 'package:package_info_plus/package_info_plus.dart';

/// Static app metadata for display.
class AppInfo {
  /// App name used across the UI.
  static const String name = 'Coppelia';

  static String _version = '0.0.0';
  static String _buildNumber = '0';
  static bool _loaded = false;

  /// Human-friendly version string.
  static String get version => _version;

  /// Build number string.
  static String get buildNumber => _buildNumber;

  /// Display-friendly version string.
  static String get displayVersion {
    if (_buildNumber.isEmpty || _buildNumber == _version) {
      return _version;
    }
    return '$_version ($_buildNumber)';
  }

  /// Platform target label.
  static const String platformLabel = 'macOS';

  /// Loads version/build metadata from the platform if available.
  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
      if (_buildNumber == _version) {
        _buildNumber = '';
      }
    } catch (_) {
      _version = _version;
      _buildNumber = _buildNumber;
    }
    _loaded = true;
  }
}
