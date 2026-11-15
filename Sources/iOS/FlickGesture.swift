import CoreMotion
import Foundation
import UIKit

/// Detects a short, deliberate hand movement, not a screen tap.
/// iOS only permits this while FlickTunes is active in the foreground.
final class FlickGesture: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var lastFlickAt: Date?
    @Published private(set) var message = "Flick gesture is ready."

    private let motion = CMMotionManager()
    private var lastTrigger = Date.distantPast
    private var consecutiveSamples = 0
    var onFlick: (() -> Void)?

    var isSupported: Bool { motion.isDeviceMotionAvailable }

    func start() {
        guard !enabled else { return }
        guard isSupported else {
            message = "Motion detection is unavailable on this device."
            enabled = false
            return
        }
        consecutiveSamples = 0
        motion.deviceMotionUpdateInterval = 1.0 / 35.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] measurement, error in
            guard let self else { return }
            if let error {
                self.message = "Motion sensor error: \(error.localizedDescription)"
                return
            }
            guard let measurement else { return }
            let a = measurement.userAcceleration
            // A short forward/sideways impulse: two consecutive samples
            // suppress one-frame sensor spikes. This is device-relative,
            // not directional tracking toward a physical Mac.
            let forwardImpulse = a.z < -1.15 || abs(a.x) > 1.6
            let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            self.consecutiveSamples = forwardImpulse && magnitude > 1.25
                ? min(self.consecutiveSamples + 1, 3)
                : 0
            guard self.consecutiveSamples >= 2,
                  Date().timeIntervalSince(self.lastTrigger) >= 3.5 else { return }
            self.consecutiveSamples = 0
            self.lastTrigger = Date()
            self.lastFlickAt = self.lastTrigger
            self.message = "Flick detected — sending to your Mac…"
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self.onFlick?()
        }
        enabled = true
        message = "Motion flick is active. Gently flick your iPhone to send."
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        consecutiveSamples = 0
        enabled = false
        message = "Motion paused until FlickTunes is active."
    }

    deinit { motion.stopDeviceMotionUpdates() }
}
