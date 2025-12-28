import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    NowPlayingPlugin.register(with: self.registrar(forPlugin: "NowPlayingPlugin"))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
