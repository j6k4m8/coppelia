import Cocoa
import FlutterMacOS
import MediaPlayer

/// Bridges Dart playback metadata to macOS Now Playing.
final class NowPlayingPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private var didSetupRemoteCommands = false

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    setupRemoteCommands()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "coppelia/now_playing",
      binaryMessenger: registrar.messenger
    )
    let instance = NowPlayingPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "update":
      updateNowPlaying(call.arguments, result: result)
    case "clear":
      clearNowPlaying()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func updateNowPlaying(_ arguments: Any?, result: FlutterResult) {
    guard let args = arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "Expected now playing dictionary.",
          details: nil
        )
      )
      return
    }
    let title = args["title"] as? String ?? "Unknown Title"
    let artist = args["artist"] as? String ?? "Unknown Artist"
    let album = args["album"] as? String ?? "Unknown Album"
    let duration = args["duration"] as? Double ?? 0
    let position = max(0, args["position"] as? Double ?? 0)
    let isPlaying = args["isPlaying"] as? Bool ?? false

    var info: [String: Any] = [
      MPMediaItemPropertyTitle: title,
      MPMediaItemPropertyArtist: artist,
      MPMediaItemPropertyAlbumTitle: album,
      MPMediaItemPropertyPlaybackDuration: duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
    ]

    if let artwork = loadAppArtwork() {
      info[MPMediaItemPropertyArtwork] = artwork
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    if #available(macOS 10.13.2, *) {
      MPNowPlayingInfoCenter.default().playbackState =
        isPlaying ? .playing : .paused
    }
    result(nil)
  }

  private func clearNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    if #available(macOS 10.13.2, *) {
      MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
  }

  private func setupRemoteCommands() {
    if didSetupRemoteCommands {
      return
    }
    didSetupRemoteCommands = true

    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.isEnabled = true

    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.sendCommand("play")
      return .success
    }
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.sendCommand("pause")
      return .success
    }
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.sendCommand("toggle")
      return .success
    }
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      self?.sendCommand("next")
      return .success
    }
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      self?.sendCommand("previous")
      return .success
    }
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.sendCommand("seek", arguments: ["position": event.positionTime])
      return .success
    }
  }

  private func sendCommand(_ method: String, arguments: Any? = nil) {
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod(method, arguments: arguments)
    }
  }

  private func loadAppArtwork() -> MPMediaItemArtwork? {
    guard let image = NSImage(named: "AppIcon") else {
      return nil
    }
    return MPMediaItemArtwork(boundsSize: image.size) { _ in
      return image
    }
  }
}
