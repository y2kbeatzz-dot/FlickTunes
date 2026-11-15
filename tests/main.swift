import Foundation

func sample(_ time: Double, _ x: Double, _ y: Double = 0, _ z: Double = 0,
            rotation: Double = 0) -> FlickSample {
    FlickSample(time: time, ax: x, ay: y, az: z, rx: rotation, ry: 0, rz: 0)
}

func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    guard condition() else {
        fputs("FAILED: \(description)\n", stderr)
        exit(1)
    }
}

// A stationary iPhone must never send a song.
var detector = FlickSignalDetector()
for i in 0..<100 {
    check(!detector.process(sample(Double(i) * 0.02, 0.03)), "Stationary noise")
}

// A short wrist movement on the Y axis must register, regardless of
// portrait/landscape device orientation.
detector.reset()
check(!detector.process(sample(3.0, 0, 0.72)), "Beginning impulse")
check(!detector.process(sample(3.02, 0, 0.82)), "Second impulse")
check(detector.process(sample(3.04, 0, 0.02)), "Flick release detected")

// A repeated flick during cooldown must not double-send.
check(!detector.process(sample(3.15, 0, 1.0)), "Cooldown")
check(!detector.process(sample(3.17, 0, 1.0)), "Cooldown still active")

// A further deliberate swipe, after cooldown, should work again.
check(!detector.process(sample(6.0, 0, 0, -0.78)), "Second gesture starts")
check(!detector.process(sample(6.02, 0, 0, -0.85)), "Second gesture continues")
check(detector.process(sample(6.04, 0, 0, 0.01)), "Second gesture release")

check(PortalURL.normalized("example.com")?.absoluteString == "https://example.com",
      "Bare links receive HTTPS")
check(PortalURL.normalized("https://openai.com/path")?.host == "openai.com",
      "HTTPS links transfer")
check(PortalURL.normalized("file:///etc/passwd") == nil,
      "Local file URLs are not opened as links")
check(PortalURL.normalized("javascript:alert(1)") == nil,
      "Unsafe URL protocols are refused")

print("Flick gesture and Portal URL smoke tests passed.")
