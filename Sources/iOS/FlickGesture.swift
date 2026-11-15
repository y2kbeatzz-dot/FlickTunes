import CoreMotion
import Foundation
import UIKit

/// Foreground-only motion gesture: gently flick the phone in any direction.
/// The raw sensor readings are processed entirely on-device.
final class FlickGesture: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var receivingMotion = false
    @Published private(set) var signalLevel = 0.0
    @Published private(set) var detectionCount = 0
    @Published private(set) var lastFlickAt: Date?
    @Published private(set) var message = "Motion gesture is ready."
    @Published var testMode = false

    private let motion = CMMotionManager()
    private var detector = FlickSignalDetector()
    private var lastMeterUpdate = -Double.infinity

    /// 0 = Easy, 0.4 = Normal, 1 = Firm. Saved by the SwiftUI view.
    var sensitivity = 0.4 {
        didSet {
            sensitivity = max(0, min(1, sensitivity))
            detector.sensitivity = sensitivity
        }
    }

    var onFlick: (() -> Void)?
    var isSupported: Bool { motion.isDeviceMotionAvailable }

    func start() {
        guard !enabled else { return }
        guard isSupported else {
            message = "This device doesn't provide motion data. Test on a physical iPhone, not Simulator."
            enabled = false
            return
        }
        detector.reset()
        detector.sensitivity = sensitivity
        lastMeterUpdate = -Double.infinity
        receivingMotion = false
        signalLevel = 0
        enabled = true
        message = "Listening for a gentle flick…"

        // Higher sample frequency catches short, normal wrist motions that
        // the old 35Hz, >1.25g directional threshold often missed.
        motion.deviceMotionUpdateInterval = 1.0 / 50.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] measurement, error in
            guard let self, self.enabled else { return }
            if let error {
                self.message = "Motion sensor error: \(error.localizedDescription)"
                return
            }
            guard let measurement else { return }
            if !self.receivingMotion { self.receivingMotion = true }

            let accel = measurement.userAcceleration
            let rotation = measurement.rotationRate
            let sample = FlickSample(
                time: measurement.timestamp,
                ax: accel.x, ay: accel.y, az: accel.z,
                rx: rotation.x, ry: rotation.y, rz: rotation.z
            )
            let strength = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
            if sample.time - self.lastMeterUpdate > 0.12 {
                self.lastMeterUpdate = sample.time
                self.signalLevel = min(1, strength / max(0.15, self.detector.threshold * 1.9))
            }

            guard self.detector.process(sample) else { return }
            self.detectionCount += 1
            self.lastFlickAt = Date()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if self.testMode {
                self.message = "Flick detected! Test passed (no song sent)."
            } else {
                self.message = "Flick detected! Sending to your Mac…"
                self.onFlick?()
            }
        }
    }

    func stop() {
        guard enabled || motion.isDeviceMotionActive else { return }
        enabled = false
        motion.stopDeviceMotionUpdates()
        detector.reset()
        signalLevel = 0
        receivingMotion = false
        message = "Motion paused. Reopen FlickTunes to resume."
    }

    deinit { motion.stopDeviceMotionUpdates() }
}
