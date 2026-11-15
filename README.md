# FlickTunes ✨

**Flick your music to your Mac.**

FlickTunes is a two-app **SwiftUI prototype**: an iPhone sender and a Mac receiver. It finds nearby devices with **MultipeerConnectivity**, lets you pair with approval on the Mac, and transfers the Apple Music track and playback time. The Mac receiver controls the actual **Music.app** with AppleScript.

## 📦 Download the IPA and DMG

1. Open **[FlickTunes Releases](../../releases)**. You can also check **[Build workflow runs](../../actions/workflows/build.yml)**.
2. Open the newest **FlickTunes Development Build** prerelease (or a versioned release).
3. Under **Assets**, download **FlickTunes-macOS.dmg** for your Mac or **FlickTunes-iOS-UNSIGNED.ipa** for iPhone. These are direct files, **not** GitHub Actions artifact ZIPs.
4. Optional: use `SHA256SUMS.txt` to check the downloaded files.

Every push to `main` and every manual **Run workflow** generates its own development release. Version tags starting with `v` produce named version releases. This design avoids the exhausted **GitHub Actions artifact storage quota** because files are published as GitHub Release assets instead.

**Important:** The iPhone IPA is **unsigned**. An unsigned IPA is a build artifact, *not an installable app*. You must code-sign it with an Apple Development certificate/team for your device, for example by building and running `FlickTunesiOS` from Xcode with your Apple ID. The Mac app is **ad-hoc signed but not notarized**: macOS Gatekeeper may block opening it until you explicitly approve it under Privacy & Security. No Apple Developer certificate is included in this repository.

## 🍎 Mac: “FlickTunes is damaged and can’t be opened”

The downloadable macOS app is a **development build**. The build is ad-hoc signed but **not Apple Developer ID signed or notarized**. A browser download is quarantined by macOS; Gatekeeper may display “damaged” even when the archive is intact. This message can also indicate a genuinely corrupted or modified app, so first confirm you got the expected release file.

1. Download the DMG from this repository's **Releases** page, not from mirrors. You can compare the `shasum -a 256 ~/Downloads/FlickTunes-macOS.dmg` output against the matching entry in the release's `SHA256SUMS.txt`.
2. Mount the DMG and copy **FlickTunes.app** into **Applications**.
3. First try the Apple-supported path: open the app once, then open **System Settings → Privacy & Security → Open Anyway**, if macOS provides that option.
4. If macOS still blocks your own verified development app, and you understand this bypasses Gatekeeper for *that app only*, run:

   ```bash
   xattr -dr com.apple.quarantine "/Applications/FlickTunes.app"
   open "/Applications/FlickTunes.app"
   ```

   **Do not** disable Gatekeeper globally or run this command against an entire Applications folder. These steps are for a trusted build you downloaded and verified, **not** an unknown app.

To check app signature validity, run `codesign --verify --deep --strict --verbose=2 "/Applications/FlickTunes.app"`. If the signature check fails or the release checksum does not match, delete that copy and download again instead of bypassing the warning.

For normal, warning-free distribution, the project needs a **Developer ID Application** certificate and Apple notarization. Ad-hoc signing alone does not make a downloadable app trusted by Gatekeeper.

## 🛠 Build locally on your Mac

Requirements: Mac running macOS 14+, full Xcode, Homebrew and XcodeGen.

```bash
brew install xcodegen
swift scripts/generate_icons.swift
xcodegen generate
open FlickTunes.xcodeproj
```

Set `FlickTunesiOS` as the scheme, choose your connected iPhone and select a signing **Team** in Xcode's Signing & Capabilities tab; build/run. For the Mac choose `FlickTunesMac`. Or build unsigned packages from the Terminal:

```bash
bash scripts/build_artifacts.sh
```

Output:
- `dist/FlickTunes-macOS.dmg`
- `dist/FlickTunes-iOS-UNSIGNED.ipa`

## 🎵 How to use

1. Open **FlickTunes Mac** and keep the app running; it advertises nearby.
2. Play a song with Apple's **Music** app on your iPhone.
3. Open **FlickTunes iPhone**, authorize access to your Music library and local network, and tap your Mac when it appears.
4. Approve pairing on Mac.
5. Tap **Flick to Mac**, or enable **motion flick** in the iPhone app and flick the phone *gently*. The app must be open for motion detection.
6. If the Mac finds that song in the Music library, Music.app should play at the transferred timestamp, and the iPhone pauses after the Mac confirms playback (configurable).

## Known limitations and privacy

- **Not Apple's native Handoff**. The gesture is in FlickTunes, not the background Music app or the system. Requires FlickTunes on both devices.
- The iOS `MPMusicPlayerController.systemMusicPlayer` can expose the now-playing Music library item, but not every Apple Music item is guaranteed accessible. The app never captures actual audio. See [Apple documentation](https://developer.apple.com/documentation/mediaplayer/mpmusicplayercontroller/systemmusicplayer).
- The Mac uses Music library search by title and artist. Tracks absent from its **Music library** will not automatically resume, even if streaming is available on Apple Music. It reports a clear failure rather than silently switching playback to a different song.
- The Mac may ask for **Automation** permission to control Music. Approve it. On first run also allow nearby network access.
- No accounts, servers, analytics, tracking or subscriptions. Device discovery and data transfer stay nearby using encrypted MultipeerConnectivity sessions.
- Only use the motion gesture with a safe, gentle movement; do not throw your phone.
- Untested on actual paired devices. Compiler and signing behavior must be verified with the GitHub Actions run and device testing.

## Repo layout

```
Sources/Shared/        Codable transfer data + nearby pairing + design
Sources/iOS/           iPhone Apple Music now playing + motion gesture UI
Sources/macOS/         Mac Music automation + receiver UI
scripts/              Generate app icon + build IPA and DMG
.github/workflows/     Automatic macOS GitHub Actions build
project.yml            XcodeGen source of truth
```

Version 0.1.0 — prototype under development.
