#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# ── config ──────────────────────────────────────────────────────────
SCHEME="StorageCleaner"
PROJECT="StorageCleaner.xcodeproj"
TEAM_ID="848R6Y8374"
ARCHIVE_PATH="$HOME/Desktop/StorageCleaner.xcarchive"
EXPORT_PATH="$HOME/Desktop/StorageCleaner-Exported"
NOTARY_PROFILE="StorageCleaner"

# ── load password from .env ─────────────────────────────────────────
if [ ! -f .env ]; then
  echo "❌ .env file not found. Create one with:"
  echo '   APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx'
  exit 1
fi
source .env

if [ -z "${APP_SPECIFIC_PASSWORD:-}" ]; then
  echo "❌ APP_SPECIFIC_PASSWORD is not set in .env"
  exit 1
fi

# ── one-time credential store (idempotent) ─────────────────────────
if ! xcrun notarytool list-credentials 2>/dev/null | grep -q "$NOTARY_PROFILE"; then
  echo "→ Storing notary credentials..."
  xcrun notarytool store-credentials "$NOTARY_PROFILE" \
    --apple-id "muhammadrizwan5040@gmail.com" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD"
fi

# ── archive ─────────────────────────────────────────────────────────
echo "→ Archiving..."
xcodebuild archive -project "$PROJECT" \
  -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM_ID"

# ── export ──────────────────────────────────────────────────────────
echo "→ Exporting..."
EXPORT_PLIST=$(mktemp)
cat > "$EXPORT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST"
rm "$EXPORT_PLIST"

# ── create DMG ──────────────────────────────────────────────────────
echo "→ Creating DMG..."
APP_BUNDLE="$EXPORT_PATH/$SCHEME.app"
DMG_PATH="$HOME/Desktop/$SCHEME.dmg"
STAGING_DIR=$(mktemp -d)
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Volume icon from the app icon
ICNS_SRC="StorageCleaner/Assets.xcassets/AppIcon.appiconset/1024.png"
ICNS_PATH=$(mktemp).icns
sips -s format icns "$ICNS_SRC" --out "$ICNS_PATH" &>/dev/null
cp "$ICNS_PATH" "$STAGING_DIR/.VolumeIcon.icns"
rm "$ICNS_PATH"
SetFile -a C "$STAGING_DIR"

hdiutil create -volname "$SCHEME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING_DIR"

# ── notarize ────────────────────────────────────────────────────────
echo "→ Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

# ── staple ──────────────────────────────────────────────────────────
echo "→ Stapling..."
xcrun stapler staple "$DMG_PATH"

echo "✅ Done — $DMG_PATH"
