import SwiftUI
import AppKit

struct TrackpadCaptureView: NSViewRepresentable {
    let onSample: (TrackpadSample) -> Void

    func makeNSView(context: Context) -> TrackpadCaptureNSView {
        let view = TrackpadCaptureNSView()
        view.onSample = onSample
        return view
    }

    func updateNSView(_ nsView: TrackpadCaptureNSView, context: Context) {
        nsView.onSample = onSample
    }
}

final class TrackpadCaptureNSView: NSView {
    var onSample: ((TrackpadSample) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var localPressureMonitor: Any?
    private var localTouchMonitor: Any?
    private var pointerIsActive = false

    private var latestPressure: Double = 0
    private var latestStage: Int = 0
    private var latestIsPressing = false
    private var latestCentroid: CGPoint?
    private var latestFingerCount = 0
    private var latestTouchPoints: [TouchPoint] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func setup() {
        wantsLayer = true
        allowedTouchTypes = [.indirect]
        // Keep trackpad touch callbacks enabled across macOS versions.
        if responds(to: Selector(("setAcceptsTouchEvents:"))) {
            setValue(true, forKey: "acceptsTouchEvents")
        }
        wantsRestingTouches = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            window.acceptsMouseMovedEvents = true
            window.makeFirstResponder(self)
            installPressureMonitor()
            installTouchMonitor()
        } else {
            removePressureMonitor()
            removeTouchMonitor()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseDown(with event: NSEvent) {
        pointerIsActive = true
        latestIsPressing = true
        latestPressure = normalizePressure(event.pressure)
        latestStage = event.stage
        window?.makeFirstResponder(self)
        emit(using: event)
    }

    override func mouseDragged(with event: NSEvent) {
        latestIsPressing = true
        latestPressure = normalizePressure(event.pressure)
        latestStage = event.stage
        emit(using: event)
    }

    override func pressureChange(with event: NSEvent) {
        latestIsPressing = true
        latestPressure = normalizePressure(event.pressure)
        latestStage = event.stage
        emit(using: event)
    }

    override func mouseUp(with event: NSEvent) {
        pointerIsActive = false
        latestIsPressing = false
        latestPressure = 0
        latestStage = 0
        latestFingerCount = 0
        latestTouchPoints = []
        latestCentroid = nil
        emit(using: event)
    }

    override func mouseMoved(with event: NSEvent) {
        emit(using: event)
    }

    override func touchesBegan(with event: NSEvent) {
        refreshTouches(event)
        emit(using: event)
    }

    override func touchesMoved(with event: NSEvent) {
        refreshTouches(event)
        emit(using: event)
    }

    override func touchesEnded(with event: NSEvent) {
        refreshTouches(event)
        emit(using: event)
    }

    override func touchesCancelled(with event: NSEvent) {
        refreshTouches(event)
        emit(using: event)
    }

    private func refreshTouches(_ event: NSEvent) {
        let touches = event.touches(matching: .touching, in: nil)
        updateTouchState(from: touches)
    }

    private func emit(using event: NSEvent) {
        guard let onSample else { return }

        let activeTouches = currentActiveTouches(from: event)
        if !activeTouches.isEmpty {
            updateTouchState(from: activeTouches)
        } else if event.type == .leftMouseUp {
            latestFingerCount = 0
            latestTouchPoints = []
            latestCentroid = nil
        }

        let sample = TrackpadSample(
            pressure: latestPressure,
            stage: latestStage,
            fingerCount: latestFingerCount,
            centroid: latestCentroid,
            touchPoints: latestTouchPoints,
            timestamp: Date(),
            isPressing: latestIsPressing
        )

        onSample(sample)
    }

    private func updateTouchState(from touches: Set<NSTouch>) {
        guard !touches.isEmpty else {
            latestFingerCount = 0
            latestTouchPoints = []
            latestCentroid = nil
            return
        }

        let sortedPositions = touches
            .map { CGPoint(x: $0.normalizedPosition.x, y: $0.normalizedPosition.y) }
            .sorted {
                if $0.x == $1.x { return $0.y < $1.y }
                return $0.x < $1.x
            }

        let points = sortedPositions.enumerated().map { index, position in
            TouchPoint(id: index + 1, normalizedPosition: position)
        }

        latestTouchPoints = points
        latestFingerCount = points.count

        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for point in points {
            sumX += point.normalizedPosition.x
            sumY += point.normalizedPosition.y
        }

        latestCentroid = CGPoint(
            x: sumX / CGFloat(points.count),
            y: sumY / CGFloat(points.count)
        )
    }

    private func currentActiveTouches(from event: NSEvent) -> Set<NSTouch> {
        let windowTouches = event.touches(matching: .touching, in: nil)
        if !windowTouches.isEmpty {
            return windowTouches
        }

        let localTouches = event.touches(matching: .touching, in: self)
        return localTouches
    }

    private func installPressureMonitor() {
        guard localPressureMonitor == nil else { return }

        localPressureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.pressure]) { [weak self] event in
            guard let self else {
                return event
            }

            if let selfWindow = self.window,
               let eventWindow = event.window,
               eventWindow !== selfWindow {
                return event
            }

            guard self.window != nil else { return event }

            let localPoint = self.convert(event.locationInWindow, from: nil)
            let inside = self.bounds.contains(localPoint)
            guard self.pointerIsActive || inside else {
                return event
            }

            self.latestIsPressing = true
            self.latestPressure = self.normalizePressure(event.pressure)
            self.latestStage = event.stage
            self.emit(using: event)
            return event
        }
    }

    private func removePressureMonitor() {
        if let localPressureMonitor {
            NSEvent.removeMonitor(localPressureMonitor)
            self.localPressureMonitor = nil
        }
    }

    private func installTouchMonitor() {
        guard localTouchMonitor == nil else { return }

        let mask: NSEvent.EventTypeMask = [
            .mouseMoved,
            .scrollWheel,
            .gesture,
            .beginGesture,
            .endGesture,
            .swipe,
            .magnify,
            .rotate,
            .smartMagnify
        ]

        localTouchMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else {
                return event
            }

            if let selfWindow = self.window,
               let eventWindow = event.window,
               eventWindow !== selfWindow {
                return event
            }

            guard let window = self.window else { return event }

            // Keep touch tracking alive without requiring an initial click.
            if window.firstResponder !== self {
                window.makeFirstResponder(self)
            }
            self.emit(using: event)
            return event
        }
    }

    private func removeTouchMonitor() {
        if let localTouchMonitor {
            NSEvent.removeMonitor(localTouchMonitor)
            self.localTouchMonitor = nil
        }
    }

    private func normalizePressure(_ pressure: Float) -> Double {
        min(1, max(0, Double(pressure)))
    }

}
