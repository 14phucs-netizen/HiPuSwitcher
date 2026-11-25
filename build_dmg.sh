#!/bin/bash

set -e

APP_SOURCE="${1:-/Applications/HiPuSwitcher.app}"
APP_VERSION="${APP_VERSION:-$(cat VERSION 2>/dev/null | tr -d '[:space:]')}"
APP_VERSION="${APP_VERSION:-1.0.0}"

VOL_NAME="HiPu Switcher"
DMG_NAME="HiPuSwitcher-${APP_VERSION}.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BG_IMAGE="${SCRIPT_DIR}/scratch/dmg_background.png"
OUT_DMG="${SCRIPT_DIR}/${DMG_NAME}"

if [ ! -d "${APP_SOURCE}" ]; then
    echo "Error: ${APP_SOURCE} not found!"
    exit 1
fi

if [ ! -f "${BG_IMAGE}" ]; then
    echo "Error: DMG background ${BG_IMAGE} not found!"
    exit 1
fi

WORK_DIR=$(mktemp -d /tmp/hipu_dmg.XXXXXX)
STAGE_DIR="${WORK_DIR}/stage"
RW_DMG="${WORK_DIR}/temp_rw.dmg"

cleanup() {
    if [ -d "/Volumes/${VOL_NAME}" ]; then
        hdiutil detach "/Volumes/${VOL_NAME}" -quiet -force 2>/dev/null || true
    fi
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

echo "Staging ${APP_SOURCE}..."
mkdir -p "${STAGE_DIR}/.background"
cp -R "${APP_SOURCE}" "${STAGE_DIR}/HiPuSwitcher.app"
ln -s /Applications "${STAGE_DIR}/Applications"
cp "${BG_IMAGE}" "${STAGE_DIR}/.background/background.png"

# Copy app icon as volume icon if available
if [ -f "${APP_SOURCE}/Contents/Resources/AppIcon.icns" ]; then
    cp "${APP_SOURCE}/Contents/Resources/AppIcon.icns" "${STAGE_DIR}/.VolumeIcon.icns"
fi

# Unmount any stale volume with the same name
if [ -d "/Volumes/${VOL_NAME}" ]; then
    hdiutil detach "/Volumes/${VOL_NAME}" -quiet -force || true
fi

echo "Creating temporary read-write DMG..."
hdiutil create \
    -srcfolder "${STAGE_DIR}" \
    -volname "${VOL_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 40m \
    "${RW_DMG}" >/dev/null

echo "Mounting temporary DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 1

# Enable custom volume icon bit if SetFile is available
if command -v SetFile >/dev/null 2>&1 && [ -f "/Volumes/${VOL_NAME}/.VolumeIcon.icns" ]; then
    SetFile -a C "/Volumes/${VOL_NAME}" || true
fi

echo "Configuring Finder drag-and-drop window layout..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {240, 160, 900, 548}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.png"
        set position of item "HiPuSwitcher.app" of container window to {175, 192}
        set position of item "Applications" of container window to {485, 192}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Hide .background and .fseventsd and flush .DS_Store
chflags hidden "/Volumes/${VOL_NAME}/.background" 2>/dev/null || true
sync
sleep 1

echo "Detaching temporary DMG..."
hdiutil detach "${DEVICE}" -quiet || hdiutil detach "/Volumes/${VOL_NAME}" -force -quiet

echo "Compressing final read-only DMG: ${OUT_DMG}..."
rm -f "${OUT_DMG}"
hdiutil convert "${RW_DMG}" -format UDZO -imagekey zlib-level=9 -o "${OUT_DMG}" >/dev/null

# Sign the DMG if a signing certificate is available
SIGN_ID="${CODESIGN_IDENTITY:-}"
if [ -z "$SIGN_ID" ]; then
    SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development:" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
fi
if [ -n "$SIGN_ID" ]; then
    echo "Signing ${DMG_NAME} with: ${SIGN_ID}"
    codesign --force --timestamp --sign "${SIGN_ID}" "${OUT_DMG}"
fi

ls -lh "${OUT_DMG}"
echo "DMG ready: ${OUT_DMG}"
