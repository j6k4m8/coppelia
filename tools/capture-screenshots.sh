#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGETS=("login")
DEVICES=()
SERVER=""
USERNAME=""
PASSWORD=""
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
  --target NAME     Screenshot target label (default: login)
  --server URL      Jellyfin URL to auto-login before capturing (default: none)
  --username NAME   Username for the server login (default: empty)
  --password PWD    Password for the server login (default: empty)
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
    --server)
      shift
      SERVER="$1"
      ;;
    --username)
      shift
      USERNAME="$1"
      ;;
    --password)
      shift
      PASSWORD="$1"
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

if [[ ${#DEVICES[@]} -eq 0 ]]; then
  DEVICES+=("macos")
fi

mkdir -p "$PROJECT_ROOT/docs/screenshots"

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
      mkdir -p "$PROJECT_ROOT/docs/screenshots/$device"
      python3 - "$LOG_FILE" "$PROJECT_ROOT/docs/screenshots/$device/screenshot-$target-$device.png" <<'PY'
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

  echo "  Screenshots saved to docs/screenshots/$device/"
done
