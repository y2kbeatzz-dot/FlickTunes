#!/bin/bash
# Builds a distributable Mac DMG and an UNSIGNED iOS IPA for developer signing.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo 'Xcode is required (macOS only).'; exit 1; }
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen'; exit 1; }
mkdir -p dist
swift scripts/generate_icons.swift
xcodegen generate

xcodebuild -project FlickTunes.xcodeproj -scheme FlickTunesMac -configuration Release -sdk macosx -derivedDataPath "$PWD/.build/mac" CODE_SIGNING_ALLOWED=NO build
MAC_APP="$PWD/.build/mac/Build/Products/Release/RIFT.app"
test -d "$MAC_APP"
rm -rf .build/dmg
mkdir -p .build/dmg
cp -R "$MAC_APP" .build/dmg/RIFT.app
# Apple Silicon requires a valid code signature for execution. An ad-hoc
# signature makes this local build internally consistent, but DOES NOT
# identify the developer or satisfy Gatekeeper notarization.
# Never strip download quarantine from a release automatically.
/usr/bin/codesign --force --sign - --timestamp=none .build/dmg/RIFT.app
/usr/bin/codesign --verify --deep --strict --verbose=2 .build/dmg/RIFT.app
ln -s /Applications .build/dmg/Applications
hdiutil create -volname RIFT -srcfolder .build/dmg -ov -format UDZO "${PWD}/dist/RIFT-macOS.dmg"

xcodebuild -project FlickTunes.xcodeproj -scheme FlickTunesiOS -configuration Release -sdk iphoneos -derivedDataPath "$PWD/.build/ios" CODE_SIGNING_ALLOWED=NO build

# The .app directory, CFBundleExecutable and actual Mach-O binary MUST agree.
# Bundle folder, CFBundleExecutable and Mach-O names are aligned so
# Sideloadly can locate the app correctly.
IOS_APP="$PWD/.build/ios/Build/Products/Release-iphoneos/RIFT.app"
IOS_BINARY="RIFT"
test -d "$IOS_APP" || { echo "ERROR: iPhone .app not produced at $IOS_APP"; exit 1; }
test -x "$IOS_APP/$IOS_BINARY" || { echo "ERROR: Missing executable $IOS_APP/$IOS_BINARY"; exit 1; }
BUNDLE_EXE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$IOS_APP/Info.plist")
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$IOS_APP/Info.plist")
test "$BUNDLE_EXE" = "$IOS_BINARY" || { echo "ERROR: CFBundleExecutable=$BUNDLE_EXE, expected $IOS_BINARY"; exit 1; }
test "$BUNDLE_ID" = "com.flicktunes.iphone" || { echo "ERROR: Unexpected iOS bundle ID: $BUNDLE_ID"; exit 1; }
file "$IOS_APP/$IOS_BINARY" | grep -q 'Mach-O' || { echo "ERROR: iOS executable is not Mach-O"; exit 1; }
/usr/bin/lipo -archs "$IOS_APP/$IOS_BINARY" | grep -qw arm64 || { echo "ERROR: iPhone executable missing arm64"; exit 1; }

rm -rf .build/ipa .build/ipa-verify
rm -f dist/RIFT-iOS-UNSIGNED.ipa
mkdir -p .build/ipa/Payload
cp -R "$IOS_APP" .build/ipa/Payload/RIFT.app
(cd .build/ipa && /usr/bin/zip -q -X -r "$OLDPWD/dist/RIFT-iOS-UNSIGNED.ipa" Payload)

# Fail the CI build instead of publishing an IPA that Sideloadly can't sign.
unzip -tqq dist/RIFT-iOS-UNSIGNED.ipa
mkdir -p .build/ipa-verify
unzip -qq dist/RIFT-iOS-UNSIGNED.ipa -d .build/ipa-verify
PACKAGED_APP="$PWD/.build/ipa-verify/Payload/RIFT.app"
test -x "$PACKAGED_APP/$IOS_BINARY" || { echo "ERROR: IPA lacks executable Payload/RIFT.app/RIFT"; exit 1; }
PACKAGED_EXE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$PACKAGED_APP/Info.plist")
test "$PACKAGED_EXE" = "$IOS_BINARY" || { echo "ERROR: IPA metadata points to $PACKAGED_EXE"; exit 1; }
echo "IPA VERIFIED: Payload/RIFT.app/RIFT (arm64), CFBundleExecutable=$PACKAGED_EXE, CFBundleIdentifier=$BUNDLE_ID"
ls -lh dist/*
echo 'IMPORTANT: The iOS IPA is unsigned and will not install without signing.'
echo 'The Mac app is ad-hoc signed but NOT Apple notarized. Gatekeeper will still block it until approved by the user.'
