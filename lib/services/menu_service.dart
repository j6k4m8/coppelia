import 'dart:io';

import 'package:flutter/services.dart';

/// Handles native menu commands on macOS.
class MenuService {
  static const MethodChannel _channel = MethodChannel('coppelia/menu');

  /// Sets up the menu handler.
  static void initialize({
    required Function() onShowPreferences,
    required Function() onTogglePlayback,
    required Function() onNextTrack,
    required Function() onPreviousTrack,
  }) {
    if (!Platform.isMacOS) {
      return;
    }
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'showPreferences':
          onShowPreferences();
          break;
        case 'togglePlayback':
          onTogglePlayback();
          break;
        case 'nextTrack':
          onNextTrack();
          break;
        case 'previousTrack':
          onPreviousTrack();
          break;
      }
    });
  }
}
