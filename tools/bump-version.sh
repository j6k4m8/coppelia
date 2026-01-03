#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC="$PROJECT_ROOT/pubspec.yaml"

SET_VERSION=""
BUILD_NUMBER=""
BUMP_BUILD=false
BUMP_MAJOR=false
BUMP_MINOR=false
BUMP_PATCH=false

usage() {
  cat <<'EOF'
Usage: bump-version.sh [--set VERSION] [--build N] [--bump-build]
                        [--bump-major|--bump-minor|--bump-patch]

Examples:
  bump-version.sh --set 0.1.0+12
  bump-version.sh --set 0.1.0 --build 12
  bump-version.sh --bump-build
  bump-version.sh --bump-patch
  bump-version.sh --bump-minor
  bump-version.sh --bump-major
  bump-version.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set)
      shift
      SET_VERSION="${1:-}"
      ;;
    --build)
      shift
      BUILD_NUMBER="${1:-}"
      ;;
    --bump-build)
      BUMP_BUILD=true
      ;;
    --bump-major)
      BUMP_MAJOR=true
      ;;
    --bump-minor)
      BUMP_MINOR=true
      ;;
    --bump-patch)
      BUMP_PATCH=true
      ;;
    --help|-h)
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

python3 - "$PUBSPEC" "$SET_VERSION" "$BUILD_NUMBER" \
  "$BUMP_BUILD" "$BUMP_MAJOR" "$BUMP_MINOR" "$BUMP_PATCH" <<'PY'
import re
import sys

path = sys.argv[1]
set_version = sys.argv[2]
build_arg = sys.argv[3]
bump_build = sys.argv[4].lower() == "true"
bump_major = sys.argv[5].lower() == "true"
bump_minor = sys.argv[6].lower() == "true"
bump_patch = sys.argv[7].lower() == "true"

text = open(path, "r", encoding="utf-8").read()
m = re.search(r"^\s*version\s*:\s*(.+)$", text, flags=re.M)
if not m:
    raise SystemExit(f"version not found in {path}")

current = m.group(1).strip()

def split_version(value: str):
    if "+" in value:
        base, build = value.split("+", 1)
    else:
        base, build = value, ""
    return base.strip(), build.strip()

base, build = split_version(current)

def bump_semver(value: str, major=False, minor=False, patch=False):
    parts = value.split("-", 1)
    core = parts[0]
    suffix = "-" + parts[1] if len(parts) > 1 else ""
    nums = core.split(".")
    while len(nums) < 3:
        nums.append("0")
    major_v, minor_v, patch_v = [int(n) if n.isdigit() else 0 for n in nums[:3]]
    if major:
        major_v += 1
        minor_v = 0
        patch_v = 0
    elif minor:
        minor_v += 1
        patch_v = 0
    elif patch:
        patch_v += 1
    return f"{major_v}.{minor_v}.{patch_v}{suffix}"

if bump_major or bump_minor or bump_patch:
    base = bump_semver(base, major=bump_major, minor=bump_minor, patch=bump_patch)

if set_version:
    if "+" in set_version:
        base, build = split_version(set_version)
    else:
        base = set_version.strip()
        if build_arg:
            build = build_arg.strip()
elif build_arg:
    build = build_arg.strip()
elif bump_build:
    if build.isdigit():
        build = str(int(build) + 1)
    else:
        build = "1"

new_version = base + (f"+{build}" if build else "")
text = re.sub(r"^\s*version\s*:\s*.+$", f"version: {new_version}", text, flags=re.M)
open(path, "w", encoding="utf-8").write(text)

print(new_version)
PY
