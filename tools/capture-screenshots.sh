#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGETS=()
DEVICES=()
CLI_SERVER=""
CLI_USERNAME=""
CLI_PASSWORD=""
ENV_FILE=""
DEFAULT_ENV_FILE="$PROJECT_ROOT/.screenshot.env"
OUTPUT_DIR="$PROJECT_ROOT/docs/screenshots"
LIBRARY_TARGETS=(
  "home"
  "albums"
  "artists"
  "tracks"
  "playlists"
  "album-detail"
  "artist-detail"
  "queue"
  "settings"
)
SYSTEM_FLUTTER="$(command -v flutter || true)"
if [[ -z "$SYSTEM_FLUTTER" ]]; then
  echo "flutter command not found; install Flutter first."
  exit 1
fi
SYSTEM_FLUTTER_ROOT="$(cd "$(dirname "$(dirname "$SYSTEM_FLUTTER")")" && pwd)"
LOCAL_FLUTTER="$PROJECT_ROOT/.flutter-sdk"
if [[ ! -d "$LOCAL_FLUTTER" ]]; then
  echo "Copying Flutter SDK to $LOCAL_FLUTTER (own copy so we can write cache stamps)..."
  cp -R "$SYSTEM_FLUTTER_ROOT" "$LOCAL_FLUTTER"
fi
chmod -R u+w "$LOCAL_FLUTTER/bin/cache"
FLUTTER_BIN="$LOCAL_FLUTTER/bin/flutter"

usage() {
  cat <<'EOF'
Usage: capture-screenshots.sh [--device DEVICE]...

Runs the integration screenshot test on macOS, iOS, or Android devices and
copies the generated PNGs into docs/screenshots/<device>.

Options:
  --device DEVICE   One or more Flutter device IDs (default: macos)
  --target NAME     Screenshot target label. Repeat to capture multiple pages.
                   Available targets: login, home, albums, artists, tracks,
                   playlists, album-detail, artist-detail, playlist-detail,
                   queue, settings.
  --env-file FILE   Load screenshot credentials from a local env file.
                   Defaults to ./.screenshot.env when present.
  --output-dir DIR  Destination directory (default: docs/screenshots)
  --server URL      Jellyfin URL to auto-login before capturing
  --username NAME   Username for the server login
  --password PWD    Password for the server login
  --help            Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      shift
      DEVICES+=("$1")
      ;;
    --target)
      shift
      TARGETS+=("$1")
      ;;
    --env-file)
      shift
      ENV_FILE="$1"
      ;;
    --output-dir)
      shift
      OUTPUT_DIR="$1"
      ;;
    --server)
      shift
      CLI_SERVER="$1"
      ;;
    --username)
      shift
      CLI_USERNAME="$1"
      ;;
    --password)
      shift
      CLI_PASSWORD="$1"
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$ENV_FILE" && -f "$DEFAULT_ENV_FILE" ]]; then
  ENV_FILE="$DEFAULT_ENV_FILE"
fi

if [[ -n "$ENV_FILE" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Env file not found: $ENV_FILE"
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

SERVER="${CLI_SERVER:-${SCREENSHOT_SERVER:-}}"
USERNAME="${CLI_USERNAME:-${SCREENSHOT_USERNAME:-}}"
PASSWORD="${CLI_PASSWORD:-${SCREENSHOT_PASSWORD:-}}"

if [[ ${#DEVICES[@]} -eq 0 ]]; then
  DEVICES+=("macos")
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  if [[ -n "$SERVER" && -n "$USERNAME" && -n "$PASSWORD" ]]; then
    TARGETS=("${LIBRARY_TARGETS[@]}")
  else
    TARGETS=("login")
  fi
fi

for target in "${TARGETS[@]}"; do
  if [[ "$target" != "login" &&
    ( -z "$SERVER" || -z "$USERNAME" || -z "$PASSWORD" ) ]]; then
    echo "Target \"$target\" requires auth. Set SCREENSHOT_SERVER, SCREENSHOT_USERNAME,"
    echo "and SCREENSHOT_PASSWORD, pass --server/--username/--password, or create"
    echo ".screenshot.env from .screenshot.env.example."
    exit 1
  fi
done

mkdir -p "$OUTPUT_DIR"

for device in "${DEVICES[@]}"; do
  echo "Capturing screenshots on $device..."

  for target in "${TARGETS[@]}"; do
    echo "  Target: $target"
    DART_ARGS=(--dart-define="SCREENSHOT_TARGET=$target")
    if [[ -n "$SERVER" ]]; then
      DART_ARGS+=(--dart-define="SCREENSHOT_SERVER=$SERVER")
    fi
    if [[ -n "$USERNAME" ]]; then
      DART_ARGS+=(--dart-define="SCREENSHOT_USERNAME=$USERNAME")
    fi
    if [[ -n "$PASSWORD" ]]; then
      DART_ARGS+=(--dart-define="SCREENSHOT_PASSWORD=$PASSWORD")
    fi
    if [[ "$target" != "login" ]]; then
      DART_ARGS+=(--dart-define="SCREENSHOT_DISABLE_SCROLLBARS=true")
    fi
    "$FLUTTER_BIN" drive \
      --driver=integration_test/driver.dart \
      --target=integration_test/screenshots_test.dart \
      -d "$device" \
      "${DART_ARGS[@]}"

    LOG_FILE="$PROJECT_ROOT/build/flutter_driver_commands_0.log"
    if [[ -f "$LOG_FILE" ]]; then
      mkdir -p "$OUTPUT_DIR/$device"
      python3 - "$LOG_FILE" "$OUTPUT_DIR/$device/screenshot-$target-$device.png" <<'PY'
import base64
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
pattern = re.compile(r'"result":"[^"]+","failureDetails":\[\],"data":{"screenshot":"([^"]+)","target":"([^"]+)","platform":"([^"]+)"}')
matches = list(pattern.finditer(text))
if not matches:
    raise SystemExit(1)
match = matches[-1]
pathlib.Path(sys.argv[2]).write_bytes(base64.b64decode(match.group(1)))
PY
      rm "$LOG_FILE"
    fi
  done

  echo "  Screenshots saved to $OUTPUT_DIR/$device/"
done
