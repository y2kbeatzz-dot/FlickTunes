import CoreMotion
import Foundation

/// User-initiated gesture recognition. Only listens while FlickTunes is open.
final class FlickGesture: ObservableObject {
    @Published var enabled = false
    private let motion = CMMotionManager()
    private var lastTrigger = Date.distantPast
    var onFlick: (() -> Void)?

    func start() {
        guard motion.isDeviceMotionAvailable else { enabled = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] measurement, _ in
            guard let self, let measurement else { return }
            let a = measurement.userAcceleration
            // Threshold avoids small movements. No background motion collection.
            let quickForward = a.z < -1.45 || a.x > 1.85
            guard quickForward, Date().timeIntervalSince(self.lastTrigger) > 2.5 else { return }
            self.lastTrigger = Date()
            self.onFlick?()
        }
        enabled = true
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        enabled = false
    }

    deinit { motion.stopDeviceMotionUpdates() }
}
