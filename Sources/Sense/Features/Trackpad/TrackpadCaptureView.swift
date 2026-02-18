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
    private var pointerIsActive = false

    private var latestPressure: Double = 0
    private var latestStage: Int = 0
    private var latestIsPressing = false
    private var latestCentroid: CGPoint?
    private var latestFingerCount = 0

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
        } else {
            removePressureMonitor()
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
        let touches = event.touches(matching: .touching, in: self)
        updateTouchCentroid(from: touches)
    }

    private func emit(using event: NSEvent) {
        guard let onSample else { return }

        let touchesFromEvent = event.touches(matching: .touching, in: self)
        if !touchesFromEvent.isEmpty {
            updateTouchCentroid(from: touchesFromEvent)
        } else if event.type == .leftMouseUp {
            // Keep stale finger-count from sticking when touch callbacks are delayed.
            latestFingerCount = 0
        }

        let fallback = normalize(point: convert(event.locationInWindow, from: nil))
        let centroid = latestCentroid ?? fallback

        let sample = TrackpadSample(
            pressure: latestPressure,
            stage: latestStage,
            fingerCount: latestFingerCount,
            centroid: centroid,
            timestamp: Date(),
            isPressing: latestIsPressing
        )

        onSample(sample)
    }

    private func updateTouchCentroid(from touches: Set<NSTouch>) {
        latestFingerCount = touches.count

        guard !touches.isEmpty else {
            latestCentroid = nil
            return
        }

        var sumX: CGFloat = 0
        var sumY: CGFloat = 0

        for touch in touches {
            sumX += touch.normalizedPosition.x
            sumY += touch.normalizedPosition.y
        }

        latestCentroid = CGPoint(
            x: sumX / CGFloat(touches.count),
            y: sumY / CGFloat(touches.count)
        )
    }

    private func installPressureMonitor() {
        guard localPressureMonitor == nil else { return }

        localPressureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.pressure]) { [weak self] event in
            guard let self, let window, event.window === window else {
                return event
            }

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

    private func normalizePressure(_ pressure: Float) -> Double {
        min(1, max(0, Double(pressure)))
    }

    private func normalize(point: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let normalizedX = min(1, max(0, point.x / bounds.width))
        let normalizedY = min(1, max(0, point.y / bounds.height))
        return CGPoint(x: normalizedX, y: normalizedY)
    }
}
