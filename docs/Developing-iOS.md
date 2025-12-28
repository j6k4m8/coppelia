# Developing on iOS (Simulator)

## Requirements

- macOS with Xcode and iOS Simulator installed.
- Flutter 3.3+ with iOS support enabled (`flutter doctor` should show iOS).

## Setup

```bash
flutter pub get
```

## Run in the Simulator

```bash
flutter devices
flutter run -d "iPhone 15"
```

Hot reload is available during `flutter run` (`r` for hot reload, `R` for hot restart).

## Tests

```bash
flutter test
flutter test integration_test -d "iPhone 15"
```

## Notes

- If your Jellyfin server is plain HTTP or uses a self-signed cert, you may need
  an App Transport Security exception in `ios/Runner/Info.plist`.
