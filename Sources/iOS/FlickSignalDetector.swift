import Foundation

/// A small, platform-independent signal detector so gesture thresholds can be
/// tested without CoreMotion or a physical iPhone.
struct FlickSample {
    let time: TimeInterval  // Monotonic CoreMotion timestamp.
    let ax: Double
    let ay: Double
    let az: Double
    let rx: Double
    let ry: Double
    let rz: Double
}

/// Detects an acceleration burst in ANY direction, followed by release.
/// Rotational movement increases confidence but is not mandatory.
struct FlickSignalDetector {
    /// 0: Easy, 0.4: Normal, 1: Firm.
    var sensitivity: Double = 0.4

    private var beganAt: TimeInterval?
    private var highSamples = 0
    private var peakAcceleration = 0.0
    private var peakRotation = 0.0
    private var lastDetectionAt = -Double.infinity

    var threshold: Double {
        0.20 + max(0, min(1, sensitivity)) * 0.46
    }

    mutating func reset() {
        beganAt = nil
        highSamples = 0
        peakAcceleration = 0
        peakRotation = 0
    }

    mutating func process(_ sample: FlickSample) -> Bool {
        let acceleration = sqrt(sample.ax * sample.ax + sample.ay * sample.ay + sample.az * sample.az)
        let rotation = sqrt(sample.rx * sample.rx + sample.ry * sample.ry + sample.rz * sample.rz)
        guard sample.time.isFinite, acceleration.isFinite, rotation.isFinite else {
            reset()
            return false
        }
        guard sample.time - lastDetectionAt > 2.2 else { return false }

        // A burst lasting longer than half a second is usually walking,
        // a long shake, or a different movement. Only short flicks qualify.
        if let beganAt, sample.time - beganAt > 0.55 {
            let qualified = qualifies
            reset()
            if qualified {
                lastDetectionAt = sample.time
                return true
            }
        }

        if acceleration >= threshold {
            if beganAt == nil { beganAt = sample.time }
            highSamples += 1
            peakAcceleration = max(peakAcceleration, acceleration)
            peakRotation = max(peakRotation, rotation)

            // Very clear gestures can trigger before the deceleration phase.
            if highSamples >= 3 && peakAcceleration >= threshold * 2.0 {
                reset()
                lastDetectionAt = sample.time
                return true
            }
        } else if beganAt != nil {
            // The release/deceleration after a short impulse is the most
            // reliable sign of a deliberate flick.
            let qualified = qualifies
            reset()
            if qualified {
                lastDetectionAt = sample.time
                return true
            }
        }
        return false
    }

    private var qualifies: Bool {
        highSamples >= 2 &&
            (peakAcceleration >= threshold * 1.27 ||
             (peakAcceleration >= threshold && peakRotation >= 0.85))
    }
}
