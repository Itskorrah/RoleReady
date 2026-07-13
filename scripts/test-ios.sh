#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
  echo "Xcode command-line tools are required. Run this script on macOS with Xcode 26 or newer." >&2
  exit 1
fi

echo "Selected developer directory: $(xcode-select -p)"
xcodebuild -version

simulator_line="$(xcrun simctl list devices available | sed -nE '/^[[:space:]]+iPhone/ {p;q;}')"
if [[ -z "$simulator_line" ]]; then
  echo "No available iPhone simulator was found. Install an iOS 18 or newer Simulator runtime in Xcode." >&2
  exit 1
fi

simulator_id="$(printf '%s\n' "$simulator_line" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')"
simulator_name="$(printf '%s\n' "$simulator_line" | sed -E 's/^[[:space:]]*//; s/[[:space:]]+\([0-9A-Fa-f-]{36}\).*$//')"
if [[ ! "$simulator_id" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  echo "Unable to parse the simulator identifier from: $simulator_line" >&2
  exit 1
fi

echo "Using simulator: $simulator_name ($simulator_id)"
if ! xcrun simctl boot "$simulator_id" 2>/dev/null; then
  echo "Simulator is already booted or is being prepared."
fi
xcrun simctl bootstatus "$simulator_id" -b

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_bundle="${RESULT_BUNDLE_PATH:-$ROOT/TestResults/RoleReady-$timestamp.xcresult}"
derived_data="${DERIVED_DATA_PATH:-$ROOT/.derived-data}"
code_signing_allowed="${CODE_SIGNING_ALLOWED:-NO}"

if [[ -e "$result_bundle" ]]; then
  echo "Result bundle already exists: $result_bundle" >&2
  echo "Choose a new RESULT_BUNDLE_PATH or remove the previous bundle explicitly." >&2
  exit 1
fi

mkdir -p "$(dirname "$result_bundle")"

echo "Result bundle: $result_bundle"
xcodebuild test \
  -project RoleReady.xcodeproj \
  -scheme RoleReady \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$derived_data" \
  -resultBundlePath "$result_bundle" \
  CODE_SIGNING_ALLOWED="$code_signing_allowed"

echo "RoleReady tests passed."
