#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

swiftc \
    "$ROOT_DIR/VacManager.swift" \
    "$ROOT_DIR/Tests/RackOffSmokeTest.swift" \
    -o "$BUILD_DIR/RackOffSmokeTest" \
    -target arm64-apple-macos12.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework UserNotifications \
    -parse-as-library

"$BUILD_DIR/RackOffSmokeTest"
