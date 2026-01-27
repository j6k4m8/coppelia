import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  @IBAction @objc func togglePlayback(_ sender: Any?) {
    sendMenuCommand("togglePlayback")
  }

  @IBAction @objc func nextTrack(_ sender: Any?) {
    sendMenuCommand("nextTrack")
  }

  @IBAction @objc func previousTrack(_ sender: Any?) {
    sendMenuCommand("previousTrack")
  }

  private func sendMenuCommand(_ command: String) {
    if let window = NSApplication.shared.windows.first,
       let flutterViewController = window.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "coppelia/menu",
        binaryMessenger: flutterViewController.engine.binaryMessenger
      )
      channel.invokeMethod(command, arguments: nil)
    }
  }
}
