import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let skysetChannel = FlutterMethodChannel(
      name: "com.matelsky.coppelia/skyset",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    skysetChannel.setMethodCallHandler { call, result in
      if call.method == "getUserHomeDirectory" {
        result(FileManager.default.homeDirectoryForCurrentUser.path)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    NowPlayingPlugin.register(
      with: flutterViewController.registrar(
        forPlugin: "NowPlayingPlugin"
      )
    )

    super.awakeFromNib()
  }
}
