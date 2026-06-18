#!/bin/bash
# Build "Wallpaper Search.app" from source. Pass --install to copy it into /Applications.
set -e
cd "$(dirname "$0")"

BUILD="build"
APP="$BUILD/Wallpaper Search.app"
rm -rf "$BUILD"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling prompt..."
swiftc -O -o "$BUILD/applet" src/main.swift
# This toolchain stamps a bogus LC_BUILD_VERSION (minos 28.0, higher than the SDK)
# that makes macOS refuse the app with "requires macOS 28.0 or later". Rewrite it sane.
vtool -set-build-version macos 12.0 26.5 -replace -output "$BUILD/applet" "$BUILD/applet" >/dev/null

echo "Rendering icon..."
swiftc -O -o "$BUILD/iconmaker" src/iconmaker.swift
"$BUILD/iconmaker" "$BUILD/icon_1024.png"
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512; do
  sips -z $sz $sz "$BUILD/icon_1024.png" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
  d=$((sz*2))
  sips -z $d $d "$BUILD/icon_1024.png" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$BUILD/AppIcon.icns"

echo "Assembling bundle..."
cp "$BUILD/applet"      "$APP/Contents/MacOS/applet"
cp src/wallpaper.py     "$APP/Contents/Resources/wallpaper.py"
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/applet"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Wallpaper Search</string>
  <key>CFBundleDisplayName</key><string>Wallpaper Search</string>
  <key>CFBundleIdentifier</key><string>joe.wallpaper.search</string>
  <key>CFBundleVersion</key><string>3.1</string>
  <key>CFBundleShortVersionString</key><string>3.1</string>
  <key>CFBundleExecutable</key><string>applet</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "Signing (ad hoc)..."
codesign --force -s - "$APP/Contents/MacOS/applet" >/dev/null
codesign --force -s - "$APP" >/dev/null
codesign -v "$APP" && echo "Signature OK"

if [ "$1" = "--install" ]; then
  echo "Installing to /Applications..."
  rm -rf "/Applications/Wallpaper Search.app"
  cp -R "$APP" "/Applications/Wallpaper Search.app"
  echo "Installed. Launch it from Spotlight or /Applications."
else
  echo "Built at: $APP"
  echo "Run ./build.sh --install to put it in /Applications."
fi
