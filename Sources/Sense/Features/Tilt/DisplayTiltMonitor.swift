import Foundation

@MainActor
final class DisplayTiltMonitor: ObservableObject {
    @Published private(set) var reading = TiltReading(
        degrees: nil,
        source: "No sensor source found",
        reliability: 0
    )

    private var timer: Timer?
    private var pollTask: Task<Void, Never>?
    private var smoothedAngle: Double?
    private let hidReader = HIDHingeAngleReader()

    func start() {
        stop()

        let timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        timer.tolerance = 0.25
        self.timer = timer
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pollTask?.cancel()
        pollTask = nil
        smoothedAngle = nil
    }

    private func poll() {
        pollTask?.cancel()

        pollTask = Task { [weak self] in
            guard let self else {
                return
            }

            if let angle = hidReader?.readAngleDegrees(), !Task.isCancelled {
                apply(angle: angle, source: "Hinge Sensor (HID)", reliability: 0.98)
                return
            }

            let angle = await Task.detached(priority: .userInitiated) {
                IORegHingeAngleReader().readAngleDegrees()
            }.value

            guard !Task.isCancelled else { return }

            if let angle {
                apply(angle: angle, source: "Hinge Sensor (IORegistry)", reliability: 0.72)
            } else {
                apply(angle: nil, source: "No hinge data available", reliability: 0.0)
            }
        }
    }

    private func smooth(value: Double) -> Double {
        let alpha = 0.32

        guard let smoothedAngle else {
            smoothedAngle = value
            return value
        }

        let next = ((1 - alpha) * smoothedAngle) + (alpha * value)
        self.smoothedAngle = next
        return next
    }

    private func apply(angle: Double?, source: String, reliability: Double) {
        if let angle {
            let filtered = smooth(value: angle)
            reading = TiltReading(
                degrees: filtered,
                source: source,
                reliability: reliability
            )
        } else {
            reading = TiltReading(
                degrees: nil,
                source: source,
                reliability: reliability
            )
        }
    }
}
