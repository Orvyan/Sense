import Foundation

struct IORegHingeAngleReader {
    private let classCandidates = [
        "AppleEmbeddedHinge",
        "AppleHIDTransportHIDEventService",
        "AppleHIDEventService",
        "IOPMrootDomain"
    ]

    private let keyValueRegex = try! NSRegularExpression(
        pattern: #"\"([^\"]*(?:hinge|lid|screen|display|clamshell)[^\"]*(?:angle|tilt|pitch)[^\"]*)\"\s*=\s*([-+]?\d+(?:\.\d+)?)"#,
        options: [.caseInsensitive]
    )

    private let keyValueWithoutQuotesRegex = try! NSRegularExpression(
        pattern: #"(?:hinge|lid|screen|display|clamshell)[^=\n]{0,40}(?:angle|tilt|pitch)[^=\n]{0,40}=\s*([-+]?\d+(?:\.\d+)?)"#,
        options: [.caseInsensitive]
    )

    func readAngleDegrees() -> Double? {
        for className in classCandidates {
            guard let output = runIOReg(arguments: ["-r", "-l", "-w", "0", "-c", className]) else {
                continue
            }

            if let angle = parseAngle(from: output) {
                return angle
            }
        }

        // Last fallback: shallow scan over the first levels of the IORegistry tree.
        if let output = runIOReg(arguments: ["-r", "-l", "-w", "0", "-d", "2"]),
           let angle = parseAngle(from: output) {
            return angle
        }

        return nil
    }

    private func runIOReg(arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func parseAngle(from text: String) -> Double? {
        var candidates: [Double] = []

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        for match in keyValueRegex.matches(in: text, options: [], range: nsRange) {
            guard let valueRange = Range(match.range(at: 2), in: text),
                  let raw = Double(text[valueRange]),
                  let normalized = normalize(raw) else {
                continue
            }
            candidates.append(normalized)
        }

        for match in keyValueWithoutQuotesRegex.matches(in: text, options: [], range: nsRange) {
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let raw = Double(text[valueRange]),
                  let normalized = normalize(raw) else {
                continue
            }
            candidates.append(normalized)
        }

        guard !candidates.isEmpty else {
            return nil
        }

        // Favor realistic laptop hinge angles over zero/open-state booleans.
        let realistic = candidates.filter { $0 >= 10 && $0 <= 160 }
        if let preferred = realistic.sorted().dropFirst(realistic.count / 2).first {
            return preferred
        }

        return candidates.sorted().dropFirst(candidates.count / 2).first
    }

    private func normalize(_ raw: Double) -> Double? {
        guard raw.isFinite else {
            return nil
        }

        let value = abs(raw)

        if value == 0 {
            return 0
        }

        if value <= Double.pi {
            let fractionalPart = abs(value - value.rounded())
            guard fractionalPart > 0.0001 else {
                return nil
            }
            return value * 180 / Double.pi
        }

        if value <= 180 {
            return value
        }

        if value <= 360 {
            return min(value, 360 - value)
        }

        if value <= 1_800 {
            return value / 10
        }

        if value <= 18_000 {
            return value / 100
        }

        if value <= 180_000 {
            return value / 1_000
        }

        return nil
    }
}
