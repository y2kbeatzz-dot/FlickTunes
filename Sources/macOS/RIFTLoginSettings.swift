import ServiceManagement
import SwiftUI

/// Apple-supported login item registration for the app itself.
/// Requires RIFT.app to be installed in /Applications for reliable behavior.
@MainActor
final class RIFTLoginSettings: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var requiresApproval = false
    @Published var errorMessage: String?

    init() { refresh() }

    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ shouldEnable: Bool) {
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
        refresh()
    }
}

struct RIFTLaunchAtLoginControl: View {
    @ObservedObject var settings: RIFTLoginSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle(isOn: Binding(
                get: { settings.enabled },
                set: { settings.setEnabled($0) }
            )) {
                Label("Launch RIFT at login", systemImage: "power")
                    .font(.headline)
            }
            .tint(FlickStyle.pink)
            Text("Start RIFT automatically when you sign in to your Mac. The receiver stays available from the menu bar even when its window is closed.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.71))
            if settings.requiresApproval {
                Text("macOS needs approval. Open System Settings → General → Login Items & Extensions, then allow RIFT.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if let error = settings.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Text("To stop RIFT completely, use Quit RIFT in the menu bar. Closing its window does not stop transfers.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(17)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
        .onAppear { settings.refresh() }
    }
}
