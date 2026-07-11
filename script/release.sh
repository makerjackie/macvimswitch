#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)}"
EXPECTED_BUNDLE_ID="com.jackiexiao.macvimswitch"
APP_PATH="$ROOT_DIR/dist/MacVimSwitch.app"
RELEASE_DIR="$ROOT_DIR/release"
ZIP_PATH="$RELEASE_DIR/MacVimSwitch-${VERSION}.zip"
DMG_PATH="$RELEASE_DIR/MacVimSwitch.dmg"

if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)"
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "错误：钥匙串中没有 Developer ID Application 证书。" >&2
    exit 1
fi

echo "使用签名身份：$SIGNING_IDENTITY"
rm -rf "$RELEASE_DIR" "$ROOT_DIR/MacVimSwitch.dmg"
mkdir -p "$RELEASE_DIR"

VERSION="$VERSION" SIGNING_IDENTITY="$SIGNING_IDENTITY" ./build.sh

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ "$actual_bundle_id" != "$EXPECTED_BUNDLE_ID" || "$actual_version" != "$VERSION" ]]; then
    echo "错误：发布元数据不匹配：bundle=$actual_bundle_id version=$actual_version" >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dvvv "$APP_PATH" 2>&1 | grep -E 'Identifier=|Authority=|TeamIdentifier=|Timestamp='
codesign -dr - "$APP_PATH" 2>&1

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
asc notarization submit --file "$ZIP_PATH" --wait --timeout 1h --output table
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

DMG_ROOT="$(mktemp -d /tmp/macvimswitch-dmg.XXXXXX)"
trap 'rm -rf "$DMG_ROOT"' EXIT
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
    -volname "MacVimSwitch" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
asc notarization submit --file "$DMG_PATH" --wait --timeout 1h --output table
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vv --type open --context context:primary-signature "$DMG_PATH"

shasum -a 256 "$DMG_PATH" | tee "$RELEASE_DIR/SHA256SUMS.txt"
echo "发布包已生成：$DMG_PATH"
