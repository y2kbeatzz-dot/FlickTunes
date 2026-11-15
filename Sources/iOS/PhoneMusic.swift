import Foundation
import MediaPlayer

@MainActor
final class PhoneMusic: ObservableObject {
    @Published var song: TransferPacket?
    @Published var message = "Grant music access, then play a song in Apple Music."
    @Published var pauseOnSuccess = true

    func requestAccess() async {
        let authorization = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in continuation.resume(returning: status) }
        }
        if authorization == .authorized { refresh() }
        else { message = "Allow Media & Apple Music access in iPhone Settings." }
    }

    func refresh() {
        let player = MPMusicPlayerController.systemMusicPlayer
        guard let item = player.nowPlayingItem else {
            song = nil
            message = "No accessible song. Start a track in Apple's Music app and try Refresh."
            return
        }
        let title = item.title ?? ""
        guard !title.isEmpty else {
            song = nil
            message = "This track did not expose a title to FlickTunes."
            return
        }
        song = TransferPacket(
            title: title,
            artist: item.artist ?? "Unknown Artist",
            album: item.albumTitle ?? "",
            storeID: item.playbackStoreID,
            position: max(0, player.currentPlaybackTime),
            duration: max(0, item.playbackDuration),
            wasPlaying: player.playbackState == .playing,
            sentAt: Date()
        )
        message = "Ready to send to your Mac"
    }

    func pauseAfterSuccessfulTransfer() {
        if pauseOnSuccess { MPMusicPlayerController.systemMusicPlayer.pause() }
    }
}
