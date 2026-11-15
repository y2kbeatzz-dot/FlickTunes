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
MAC_APP="$PWD/.build/mac/Build/Products/Release/FlickTunesMac.app"
test -d "$MAC_APP"
rm -rf .build/dmg
mkdir -p .build/dmg
cp -R "$MAC_APP" .build/dmg/FlickTunes.app
# Apple Silicon requires a valid code signature for execution. An ad-hoc
# signature makes our local prototype internally consistent, but DOES NOT
# identify the developer or satisfy Gatekeeper notarization.
# Never strip download quarantine from a release automatically.
/usr/bin/codesign --force --sign - --timestamp=none .build/dmg/FlickTunes.app
/usr/bin/codesign --verify --deep --strict --verbose=2 .build/dmg/FlickTunes.app
ln -s /Applications .build/dmg/Applications
hdiutil create -volname FlickTunes -srcfolder .build/dmg -ov -format UDZO "${PWD}/dist/FlickTunes-macOS.dmg"

xcodebuild -project FlickTunes.xcodeproj -scheme FlickTunesiOS -configuration Release -sdk iphoneos -derivedDataPath "$PWD/.build/ios" CODE_SIGNING_ALLOWED=NO build
IOS_APP="$PWD/.build/ios/Build/Products/Release-iphoneos/FlickTunesiOS.app"
test -d "$IOS_APP"
rm -rf .build/ipa
mkdir -p .build/ipa/Payload
cp -R "$IOS_APP" .build/ipa/Payload/FlickTunes.app
(cd .build/ipa && /usr/bin/zip -q -r "$OLDPWD/dist/FlickTunes-iOS-UNSIGNED.ipa" Payload)
ls -lh dist/*
echo 'IMPORTANT: The iOS IPA is unsigned and will not install without signing.'
echo 'The Mac app is ad-hoc signed but NOT Apple notarized. Gatekeeper will still block it until approved by the user.'
