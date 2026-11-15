# FlickTunes ✨

**Flick your music to your Mac.**

FlickTunes is a two-app **SwiftUI prototype**: an iPhone sender and a Mac receiver. It finds nearby devices with **MultipeerConnectivity**, lets you pair with approval on the Mac, and transfers the Apple Music track and playback time. The Mac receiver controls the actual **Music.app** with AppleScript.

**Created by [life999](https://guns.lol/life999)** · [Source code](https://github.com/y2kbeatzz-dot/FlickTunes)

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

## What's new in v0.4.0 — Portal + motion gesture

### Portal: drag from iPhone toward Mac

- Open **Portal • Photos, Files & Links** from FlickTunes on iPhone.
- Select a photo or video from the Photos picker, or any document/video from Files.
- The selection becomes a draggable card. **Hold and drag it LEFT**: the card follows your finger, tilts, and flies off-screen when released far enough. A Send button is available for accessibility.
- On Mac, the received file is saved (without executing it) to **~/Downloads/FlickTunes**. A floating arrival card slides in from the left edge to a position near the pointer; photos can display a real thumbnail. Use **Show in Finder** in the app to locate the item.
- Select an original arrival effect: **Glide**, **Bloom**, or **Fade**. These are transitions within FlickTunes, not Canopy's animations or assets.
- Links can also be dragged off the left edge. They appear in the Mac receiver with an explicit **Open Link** button; they never auto-launch. Clipboard text is only sent when you explicitly tap **Send Clipboard**.
- Transfer uses the existing nearby, encrypted MultipeerConnectivity session. No cloud relay is used. Keep iPhone FlickTunes foregrounded while sending large files; a full-size movie may need to copy locally before sending.

### Music flick troubleshooting

- The iPhone motion detector no longer depends on the direction the phone is held. It detects short, deliberate movements, with sensitivity adjustment.
- New **Test motion without sending** option, live sensor indicator, gesture count, and haptic feedback help distinguish motion detection from a playback/connection problem.
- Portal's screen swipe is separate from the physical Music flick; motion music handoff pauses while Portal is open.

### About / creator

**Created by Ksyusha (life999)**. Both apps link to [guns.lol/life999](https://guns.lol/life999) and include the in-app setup guide.

**What this version does not claim:** There is no physical tracking of an object between displays, system-wide cross-device dragging, Mac-to-iPhone reverse file transfers, or system-level Apple Handoff. The coordinated animations simulate the throw-and-land experience with our own design. This is an independently written preview; do not assume every Canopy capability is present.

### Test

The workflow now runs portable smoke tests for gesture signals and URL handling and builds both apps on a macOS runner. iOS still requires your own signing before installation, and macOS builds are ad-hoc signed, **not notarized**. Real hardware tests are necessary to validate touch interaction, iPhone-to-Mac transfer, appearance and performance.

## What's new in v0.3.1

- **Flick-to-send by default:** Gently flick your iPhone while FlickTunes is open to send the current Apple Music track. Your on/off choice is saved between launches. The regular send button remains available.
- **Remembered Mac:** Pair and approve your Mac once. FlickTunes stores its actual peer identity for future sessions, so you do not need to pick or type the device again.
- **Less connection stacking:** Duplicate Bonjour discoveries are collapsed into one row; incoming invitations are debounced; only one receiver session is allowed; repeated connected notifications do not trigger multiple handoffs.
- **Reconnect without false disconnects:** The iPhone no longer deliberately disconnects the session just because you switch apps. Background suspension by iOS is still possible. Stale disconnect callbacks no longer override a current live connection, and reconnection attempts are bounded.
- **Queued flick:** If your saved Mac is reconnecting, a single flick can be held for up to 20 seconds and sent only to the exact approved Mac identity.
- **Help and About:** Step-by-step setup, connection recovery instructions, a version label, creator credit to **life999**, and a link to [guns.lol/life999](https://guns.lol/life999) in both apps.
- **Mac receiver:** Runs from the menu bar after closing the main window; its setup instructions describe flicking instead of tapping.

For a clean test, install the same latest version on both devices, leave FlickTunes running on the Mac, then open FlickTunes on your iPhone while Apple Music is playing. If an older installation has stale pairings, use **Forget Pairing** on both devices once, then approve again. Avoid repeatedly pressing Pair or Rescan while the status says Connecting.

**Limitations:** MultipeerConnectivity may be suspended when iOS backgrounds the app. This patch reduces unnecessary disconnects but does not guarantee an always-on iPhone background connection. The flick gesture is detected inside FlickTunes while it is active; it cannot run in the background Music app. The Mac can play only matching tracks in its Music library. Device-to-device stability must still be verified on real hardware.

## What's new in v0.2.0

- **Connection stability:** Persists the local peer identity, remembers an approved device, prevents duplicate invitations, and limits automatic reconnection to three spaced attempts. Manual **Rescan** and **Forget Pairing** are available on iPhone; **Forget Pairing** also appears on Mac.
- **Mac menu-bar receiver:** Closing the main window no longer ends the receiver session. Use the FlickTunes menu-bar icon to reopen or quit the app.
- **Setup guide:** Numbered steps and connection troubleshooting inside both apps.
- **About FlickTunes:** Creator credit to **life999** and a direct link to [guns.lol/life999](https://guns.lol/life999).

**iOS limitation:** Multipeer Connectivity may disconnect when the iPhone app enters the background. FlickTunes attempts to reconnect to an approved Mac when brought to the foreground, but cannot guarantee an always-on background connection. These changes still need testing on real paired devices.

## Connection troubleshooting

1. Start FlickTunes on Mac and leave it running (look for its menu-bar icon).
2. Keep Wi-Fi and Bluetooth enabled and allow Local Network on iPhone.
3. Start your song in the Music app **before** opening FlickTunes on iPhone.
4. Tap your Mac, approve the pairing request, and wait for **Connected** before sending.
5. If it gets stuck, tap **Rescan**. If necessary choose **Forget Pairing** on both devices, then pair again.
6. For playback, grant Mac Automation permission and ensure the exact song is in your Mac Music library.

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

Version 0.4.0 — prototype under development. Created by [life999](https://guns.lol/life999).
