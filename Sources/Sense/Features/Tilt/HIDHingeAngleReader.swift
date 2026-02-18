import Foundation
import IOKit.hid

final class HIDHingeAngleReader {
    private let lock = NSLock()

    private let manager: IOHIDManager
    private var device: IOHIDDevice?

    private var angleElement: IOHIDElement?
    private var fineAngleElement: IOHIDElement?

    private let sensorUsagePage: UInt32 = 0x20
    private let hingePrimaryUsage: UInt32 = 0x8A
    private let angleUsage: UInt32 = 0x47F   // 1151
    private let fineAngleUsage: UInt32 = 0x545 // 1349

    init?() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDPrimaryUsagePageKey as String: Int(sensorUsagePage),
            kIOHIDPrimaryUsageKey as String: Int(hingePrimaryUsage)
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            return nil
        }

        refreshDeviceLocked()
    }

    deinit {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func readAngleDegrees() -> Double? {
        lock.lock()
        defer { lock.unlock() }

        ensureDeviceAndElementsLocked()

        guard let device else {
            return nil
        }

        if let angleElement,
           let raw = readIntValue(from: device, element: angleElement),
           let normalized = normalize(raw: raw, logicalMax: IOHIDElementGetLogicalMax(angleElement)) {
            return normalized
        }

        if let fineAngleElement,
           let raw = readIntValue(from: device, element: fineAngleElement),
           let normalized = normalize(raw: raw, logicalMax: IOHIDElementGetLogicalMax(fineAngleElement)) {
            return normalized
        }

        return nil
    }

    private func ensureDeviceAndElementsLocked() {
        if device == nil {
            refreshDeviceLocked()
        }

        guard let device else { return }

        if angleElement == nil || fineAngleElement == nil {
            cacheElementsLocked(from: device)
        }
    }

    private func refreshDeviceLocked() {
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let first = set.first else {
            device = nil
            angleElement = nil
            fineAngleElement = nil
            return
        }

        device = first
        _ = IOHIDDeviceOpen(first, IOOptionBits(kIOHIDOptionsTypeNone))
        angleElement = nil
        fineAngleElement = nil
    }

    private func cacheElementsLocked(from device: IOHIDDevice) {
        let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] ?? []

        for element in elements {
            let usagePage = IOHIDElementGetUsagePage(element)
            guard usagePage == sensorUsagePage else {
                continue
            }

            let usage = IOHIDElementGetUsage(element)
            if usage == angleUsage {
                angleElement = element
            } else if usage == fineAngleUsage {
                fineAngleElement = element
            }
        }
    }

    private func readIntValue(from device: IOHIDDevice, element: IOHIDElement) -> Int? {
        var maybeValue: Unmanaged<IOHIDValue>? = nil

        let result: IOReturn = withUnsafeMutablePointer(to: &maybeValue) { pointer in
            pointer.withMemoryRebound(to: Unmanaged<IOHIDValue>.self, capacity: 1) { rebound in
                IOHIDDeviceGetValue(device, element, rebound)
            }
        }

        guard result == kIOReturnSuccess,
              let maybeValue else {
            return nil
        }

        return Int(IOHIDValueGetIntegerValue(maybeValue.takeUnretainedValue()))
    }

    private func normalize(raw: Int, logicalMax: CFIndex) -> Double? {
        guard raw >= 0 else {
            return nil
        }

        let max = max(0, logicalMax)
        var degrees: Double

        if max <= 360 {
            degrees = Double(raw)
        } else if max <= 36_000 {
            degrees = Double(raw) / 100
        } else if max <= 360_000 {
            degrees = Double(raw) / 1_000
        } else {
            let asDouble = Double(raw)
            if asDouble <= 360 {
                degrees = asDouble
            } else if asDouble <= 36_000 {
                degrees = asDouble / 100
            } else {
                return nil
            }
        }

        if degrees > 180 {
            degrees = 360 - degrees
        }

        guard degrees.isFinite, degrees >= 0, degrees <= 180 else {
            return nil
        }

        return degrees
    }
}
