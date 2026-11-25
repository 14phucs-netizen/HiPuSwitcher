#!/bin/bash

set -e

# Version: ưu tiên biến môi trường, sau đó file VERSION, cuối cùng là 1.0.0
APP_VERSION="${APP_VERSION:-$(cat VERSION 2>/dev/null | tr -d '[:space:]')}"
APP_VERSION="${APP_VERSION:-1.0.0}"
APP_BUILD="${APP_BUILD:-$(date +%Y%m%d%H%M)}"
APP_COPYRIGHT="${APP_COPYRIGHT:-© 2026 PhucVang. Bảo lưu mọi quyền.}"
echo "Version ${APP_VERSION} (build ${APP_BUILD})"

# 1. Build the release binary
echo "Building HiPuSwitcher target..."
swift build -c release --product HiPuSwitcher

# Get the path to the built binaries
BIN_PATH=$(swift build -c release --show-bin-path)

# Function to package an app
package_app() {
    local target_name="$1"
    local display_name="$2"
    local is_ui_element="$3" # "true" or "false"
    local has_custom_resources="$4" # "true" or "false"
    local icns_file="$5"
    local menu_icon_name="$6"
    
    local app_dir="${target_name}.app"
    local contents_dir="${app_dir}/Contents"
    local macos_dir="${contents_dir}/MacOS"
    local resources_dir="${contents_dir}/Resources"
    
    echo "Packaging ${app_dir}..."
    rm -rf "${app_dir}"
    mkdir -p "${macos_dir}"
    mkdir -p "${resources_dir}"
    
    # Copy the binary
    cp "${BIN_PATH}/${target_name}" "${macos_dir}/"

    # Stamp LC_BUILD_VERSION with the active macOS SDK (e.g. 27.2) so macOS 26+ enables
    # native Liquid Glass window chrome, borderless grouped Forms, floating sidebar, and controls.
    local sdk_ver
    sdk_ver=$(xcrun --show-sdk-version 2>/dev/null || echo "26.0")
    xcrun vtool -set-build-version macos 14.0 "${sdk_ver}" -replace -output "${macos_dir}/${target_name}" "${macos_dir}/${target_name}"
    
    # Compile full-bleed AppIcon.xcassets into Assets.car + AppIcon.icns (for native macOS 26/27 full-bleed squircle)
    local icon_plist_entries=""
    if [ -d "AppIcon.xcassets" ] && xcrun --find actool >/dev/null 2>&1; then
        echo "Compiling AppIcon.xcassets with actool..."
        xcrun actool "AppIcon.xcassets" \
            --compile "${resources_dir}" \
            --platform macosx \
            --minimum-deployment-target 14.0 \
            --app-icon AppIcon \
            --output-partial-info-plist "/tmp/${target_name}_icon_partial.plist" >/dev/null
        rm -f "/tmp/${target_name}_icon_partial.plist"
        icon_plist_entries="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>"
    else
        if [ -n "$icns_file" ] && [ -f "$icns_file" ]; then
            cp "$icns_file" "${resources_dir}/icon.icns"
        elif [ -f "icon.icns" ]; then
            cp "icon.icns" "${resources_dir}/icon.icns"
        fi
        icon_plist_entries="    <key>CFBundleIconFile</key>
    <string>icon.icns</string>"
    fi
    
    if [ "$has_custom_resources" = "true" ] && [ -n "$menu_icon_name" ]; then
        if [ -f "${menu_icon_name}.png" ]; then
            cp "${menu_icon_name}.png" "${resources_dir}/"
        fi
        if [ -f "${menu_icon_name}@2x.png" ]; then
            cp "${menu_icon_name}@2x.png" "${resources_dir}/"
        fi
    fi

    # Copy Swift Package resource bundles
    # Chỉ copy bundle của chính dự án và dependency khai báo trong Package.swift
    # (tránh kéo theo bundle cũ còn sót trong thư mục build).
    for bundle in "${BIN_PATH}"/HiPuLauncher_*.bundle "${BIN_PATH}"/KeyboardShortcuts_*.bundle "${BIN_PATH}"/Fuse_*.bundle; do
        if [ -d "$bundle" ]; then
            local bundle_name=$(basename "$bundle")
            echo "Copying resource bundle ${bundle_name} to Resources..."
            cp -R "$bundle" "${resources_dir}/"
        fi
    done
    
    # Create Info.plist
    cat <<PLIST > "${contents_dir}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${target_name}</string>
${icon_plist_entries}
    <key>CFBundleIdentifier</key>
    <string>com.hipu.${target_name}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${display_name}</string>
    <key>CFBundleDisplayName</key>
    <string>${display_name}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>NSHumanReadableCopyright</key>
    <string>${APP_COPYRIGHT}</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <${is_ui_element}/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSWindowTabbingMode</key>
    <string>manual</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Ứng dụng cần quyền điều khiển để hỗ trợ các phím tắt và quản lý ứng dụng.</string>
</dict>
</plist>
PLIST

    # Sign with a stable Apple Development identity if available (so macOS remembers
    # Accessibility permissions across rebuilds), otherwise fall back to ad-hoc.
    local sign_id="${CODESIGN_IDENTITY:-}"
    if [ -z "$sign_id" ]; then
        sign_id=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development:" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
    fi
    if [ -n "$sign_id" ]; then
        echo "Signing ${app_dir} with Hardened Runtime: ${sign_id}"
        local entitlements_args=()
        if [ -f "HiPuSwitcher.entitlements" ]; then
            entitlements_args=(--entitlements "HiPuSwitcher.entitlements")
        fi
        codesign --force --deep --options runtime --timestamp "${entitlements_args[@]}" --sign "${sign_id}" "${app_dir}"
    else
        echo "Signing ${app_dir} with ad-hoc signature (-)"
        codesign --force --deep --sign - "${app_dir}"
    fi
    echo "Successfully packaged and signed ${app_dir}"
}

# Package HiPuSwitcher (the App Switcher)
package_app "HiPuSwitcher" "HiPu Switcher" "true" "true" "icon_switcher.icns" "MenuBarIconTemplate"

echo "Build and packaging complete!"
