# Developing on Linux

## Requirements

-   Flutter 3.3+ with Linux desktop enabled (`flutter doctor` should show Linux).
-   GTK development headers and build tooling:
    -   `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`

## Setup

```bash
flutter pub get
```

## Run on Linux

```bash
flutter devices
flutter run -d linux
```

Hot reload is available during `flutter run` (`r` for hot reload, `R` for hot restart).

## Tests

```bash
flutter test
```

## Notes

-   If you are missing GTK headers, install the packages listed above with your distro's package manager.
