#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT_DIR"

echo "==> Swift-Core-Tests"
swift test

echo "==> iOS-Build"
xcodebuild -scheme MigraineTrackerApp -project MigraineTracker.xcodeproj -destination 'generic/platform=iOS Simulator' build

echo "==> Manuelle QA-Checkliste"
echo "Siehe docs/Teststrategie-und-Release-Checkliste.md"
