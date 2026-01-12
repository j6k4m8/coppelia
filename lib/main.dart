import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/app_info.dart';

/// Entry point for the Coppelia music player.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.load();
  if (Platform.isAndroid) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.matelsky.coppelia.audio',
      androidNotificationChannelName: 'Coppelia Playback',
      androidNotificationOngoing: true,
    );
  }
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      size: const Size(1280, 800),
      minimumSize: const Size(320, 360),
      center: true,
      titleBarStyle:
          Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
      backgroundColor: Colors.transparent,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const CoppeliaApp());
}
