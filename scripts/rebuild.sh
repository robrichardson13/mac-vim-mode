#!/usr/bin/env bash
# Build vim-mode[-<feature>].app from this checkout and relaunch it in the background.
# Usage: rebuild.sh [--no-launch]
set -euo pipefail
trap 'echo "rebuild.sh: line $LINENO failed: $BASH_COMMAND" >&2' ERR

if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--no-launch" ]; }; then
  echo "usage: rebuild.sh [--no-launch]" >&2
  exit 64
fi

cd "$(git rev-parse --show-toplevel)"

feature=$(cat .vim-mode-feature 2>/dev/null || true)
# A leaked suffix in the canonical checkout would give the main build a throwaway identity.
if [ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ] && [ -n "$feature" ]; then
  echo "canonical checkout: ignoring leaked .vim-mode-feature ($feature)"
  feature=""
fi

APP="vim-mode${feature:+-$feature}"
BUNDLE_ID="io.robrichardson.vim-mode${feature:+.$feature}"
BUNDLE=".build/app/$APP.app"
LOG=".build/rebuild-$APP.log"
mkdir -p .build

echo "building ${APP}…"
if ! swift build -c release --product vim-mode > "$LOG" 2>&1; then
  grep -E 'error:' "$LOG" | tail -30 || true
  echo "build failed: full log $LOG"
  exit 1
fi

pkill -x "$APP" 2>/dev/null || true
for _ in $(seq 50); do pgrep -x "$APP" >/dev/null || break; sleep 0.1; done

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp .build/release/vim-mode "$BUNDLE/Contents/MacOS/$APP"
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
codesign --force --sign - --identifier "$BUNDLE_ID" "$BUNDLE" 2>> "$LOG"
echo "built $PWD/$BUNDLE ($BUNDLE_ID)"

[ "${1:-}" = "--no-launch" ] && exit 0
# Background: agents rebuild to check their work, and a plain open takes Rob's focus.
# Retried because open fails with -600 for a moment after the old process has gone.
for _ in $(seq 10); do open -g "$BUNDLE" 2>/dev/null && break; sleep 0.3; done
pgrep -x "$APP" >/dev/null || open -g "$BUNDLE"
echo "relaunched $APP"
