import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/app_info.dart';
import 'services/log_service.dart';

/// Entry point for the Coppelia music player.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load app info first
  await AppInfo.load();

  // Initialize logging service
  final logService = await LogService.instance;
  await logService.info('App starting - version ${AppInfo.displayVersion}');
  if (Platform.isAndroid) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.matelsky.coppelia.audio',
      androidNotificationChannelName: 'Coppelia Playback',
      androidNotificationOngoing: true,
    );
  }
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    logService.info('Initializing MediaKit for desktop platforms');
    MediaKit.ensureInitialized();
    logService.info('MediaKit initialized for desktop platforms');
  }
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    logService.info('Initializing window manager for desktop platforms');
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
    logService.info('Window manager initialized');
  }

  runApp(const CoppeliaApp());
}
