import SwiftUI
import Combine

struct TouchPoint: Identifiable, Hashable {
    let id: Int
    let normalizedPosition: CGPoint
}

struct TrackpadSample {
    let pressure: Double
    let stage: Int
    let fingerCount: Int
    let centroid: CGPoint?
    let touchPoints: [TouchPoint]
    let timestamp: Date
    let isPressing: Bool
}

struct TiltReading {
    let degrees: Double?
    let source: String
    let reliability: Double
}

@MainActor
final class DashboardViewModel: ObservableObject {
    enum WeightUnit: String, CaseIterable, Identifiable {
        case grams = "g"
        case newton = "N"

        var id: String { rawValue }
    }

    @Published private(set) var pressure: Double = 0
    @Published private(set) var weightGrams: Double = 0
    @Published private(set) var fingerCount: Int = 0
    @Published private(set) var centroid: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @Published private(set) var touchPoints: [TouchPoint] = []
    @Published private(set) var stage: Int = 0
    @Published private(set) var isPressing: Bool = false

    @Published private(set) var tiltDegrees: Double?
    @Published private(set) var tiltSource: String = "No sensor source found"
    @Published private(set) var tiltReliability: Double = 0

    @Published var tareOffset: Double = 0
    @Published var selectedUnit: WeightUnit = .grams

    private let tiltMonitor = DisplayTiltMonitor()
    private var cancellables = Set<AnyCancellable>()

    private var smoothedPressure: Double = 0
    private let pressureFilterAlpha: Double = 0.18
    private let gramsPerFullPressure: Double = 2_700
    private let maxUIWeightGrams: Double = 1_500

    init() {
        tiltMonitor.$reading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                guard let self else { return }
                tiltDegrees = reading.degrees
                tiltSource = reading.source
                tiltReliability = reading.reliability
            }
            .store(in: &cancellables)
    }

    func start() {
        tiltMonitor.start()
    }

    func stop() {
        tiltMonitor.stop()
    }

    func handleTrackpadSample(_ sample: TrackpadSample) {
        stage = sample.stage
        fingerCount = sample.fingerCount
        touchPoints = sample.touchPoints
        isPressing = sample.isPressing || sample.fingerCount > 0 || !sample.touchPoints.isEmpty

        if let centroid = sample.centroid {
            self.centroid = centroid
        }

        // Strict live behavior: when force is released, reset immediately to zero.
        let hasForce = sample.pressure > 0.003
        guard hasForce else {
            smoothedPressure = 0
            pressure = 0
            weightGrams = 0
            return
        }

        let filteredPressure = lowPassFilter(next: sample.pressure)
        pressure = filteredPressure
        let rawWeight = max(0, filteredPressure - tareOffset) * gramsPerFullPressure
        weightGrams = rawWeight
    }

    func tare() {
        tareOffset = pressure
    }

    func clearTare() {
        tareOffset = 0
    }

    var weightProgress: Double {
        min(max(weightGrams / maxUIWeightGrams, 0), 1)
    }

    var pressurePercent: Int {
        Int((pressure * 100).rounded())
    }

    var formattedWeight: String {
        switch selectedUnit {
        case .grams:
            return "\(Int(weightGrams.rounded())) g"
        case .newton:
            let newton = weightGrams / 101.97
            return String(format: "%.2f N", newton)
        }
    }

    var formattedTilt: String {
        guard let tiltDegrees else { return "--.-°" }
        return String(format: "%.1f°", tiltDegrees)
    }

    var tiltIndicatorProgress: Double {
        guard let tiltDegrees else { return 0 }
        return min(max(tiltDegrees / 150, 0), 1)
    }

    private func lowPassFilter(next value: Double) -> Double {
        smoothedPressure = ((1 - pressureFilterAlpha) * smoothedPressure) + (pressureFilterAlpha * value)
        return smoothedPressure
    }
}
