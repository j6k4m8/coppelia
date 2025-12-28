# Developing on Android

## Requirements

- Flutter 3.3+ with Android support enabled (`flutter doctor` should show Android).
- Android Studio or Android SDK + platform tools (`adb` in PATH).
- An Android emulator or a physical device with USB debugging enabled.

## Setup

```bash
flutter pub get
```

## Run on an Emulator

```bash
flutter emulators
flutter emulators --launch <emulator-id>
flutter devices
flutter run -d <device-id>
```

Hot reload is available during `flutter run` (`r` for hot reload, `R` for hot restart).

## Run on a Device

```bash
flutter devices
flutter run -d <device-id>
```

## Tests

```bash
flutter test
flutter test integration_test -d <device-id>
```

## Notes

- For an emulator hitting a local Jellyfin server, use `http://10.0.2.2:8096`.
- If your Jellyfin server uses plain HTTP, add a network security config to allow
  cleartext traffic.
