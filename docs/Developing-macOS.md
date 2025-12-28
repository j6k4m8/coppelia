# Developing on macOS

## Requirements

- Flutter 3.3+ with macOS desktop support enabled.
- Xcode (for simulator tooling and signing).

## Setup

```bash
flutter pub get
```

## Run

```bash
flutter run -d macos
```

Hot reload is available during `flutter run` (`r` for hot reload, `R` for hot restart).

## Tests

```bash
flutter test
flutter test integration_test -d macos
```

