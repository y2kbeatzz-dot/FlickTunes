import AppKit
import Foundation

struct MacPlaybackResult {
    let succeeded: Bool
    let message: String
}

/// Controls the real macOS Music app, never an embedded audio player.
/// Music requires permission under System Settings > Privacy & Security > Automation.
enum MacMusic {
    static func resume(_ packet: TransferPacket) -> MacPlaybackResult {
        // AppleScript uses literal strings escaped for the script language.
        let title = applescriptLiteral(packet.title)
        let artist = applescriptLiteral(packet.artist)
        let seconds = String(format: "%.2f", packet.currentPosition)
        let script = """
        tell application "Music"
            activate
            set matches to (every track of library playlist 1 whose name is \(title))
            set chosen to missing value
            repeat with candidate in matches
                if (artist of candidate as text) is \(artist) then
                    set chosen to candidate
                    exit repeat
                end if
            end repeat
            if chosen is missing value then return "NOT_FOUND"
            play chosen
            delay 0.35
            set player position to \(seconds)
            return "PLAYING"
        end tell
        """
        var errorInfo: NSDictionary?
        let reply = NSAppleScript(source: script)?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let details = (errorInfo["NSAppleScriptErrorMessage"] as? String) ?? "Music automation failed"
            return MacPlaybackResult(succeeded: false, message: "Music couldn't play the song: \(details). Check Automation permission.")
        }
        if reply?.stringValue == "PLAYING" {
            return MacPlaybackResult(succeeded: true, message: "Playing \(packet.title) on Mac at \(Int(packet.currentPosition))s")
        }
        return MacPlaybackResult(succeeded: false, message: "\(packet.title) wasn't found in your Mac Music library. Add it to your library, then try again.")
    }

    private static func applescriptLiteral(_ text: String) -> String {
        // AppleScript quoted strings use backslash escaping.
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }
}
