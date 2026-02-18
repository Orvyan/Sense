import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            AmbientBackground(glowPulse: glowPulse)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                header

                HStack(spacing: 18) {
                    WeightCard(viewModel: viewModel)
                    TiltCard(viewModel: viewModel)
                }

                TrackpadCard(viewModel: viewModel)
            }
            .padding(28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                glowPulse.toggle()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sense")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text("Use your trackpad as a scale and see live display tilt in degrees")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.8))
            }

            Spacer()

            StatusChip(text: "Force Touch", isActive: viewModel.isPressing)
            StatusChip(text: "Fingers: \(viewModel.fingerCount)", isActive: viewModel.fingerCount > 0)
            StatusChip(text: "Pressure: \(viewModel.pressurePercent)%", isActive: viewModel.pressurePercent > 0)
        }
    }
}

private struct WeightCard: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Label("Trackpad Scale", systemImage: "scalemass")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                HStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 16)

                        Circle()
                            .trim(from: 0, to: viewModel.weightProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [Color.cyan, Color.blue, Color.green, Color.cyan],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.42, dampingFraction: 0.74), value: viewModel.weightProgress)

                        VStack(spacing: 6) {
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.7))

                            Text(viewModel.formattedWeight)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(width: 220, height: 220)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Calibration")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("Use tare with no load, then press on the trackpad to measure.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button("Tare") {
                                viewModel.tare()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Reset") {
                                viewModel.clearTare()
                            }
                            .buttonStyle(.bordered)
                        }

                        Picker("Unit", selection: $viewModel.selectedUnit) {
                            ForEach(DashboardViewModel.WeightUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct TiltCard: View {
    @ObservedObject var viewModel: DashboardViewModel

    private var needleRotation: Angle {
        let degrees = -120 + (viewModel.tiltIndicatorProgress * 240)
        return .degrees(degrees)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Label("Display Tilt", systemImage: "angle")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                HStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .trim(from: 0.18, to: 0.82)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.25), Color.red.opacity(0.8), Color.orange.opacity(0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .rotationEffect(.degrees(90))

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color.orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 4, height: 100)
                            .clipShape(Capsule())
                            .offset(y: -50)
                            .rotationEffect(needleRotation)
                            .animation(.spring(response: 0.34, dampingFraction: 0.8), value: viewModel.tiltIndicatorProgress)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)

                        VStack {
                            Spacer()
                            Text(viewModel.formattedTilt)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .contentTransition(.numericText())
                                .padding(.bottom, 10)
                        }
                    }
                    .frame(width: 220, height: 220)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sensor Source")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text(viewModel.tiltSource)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Text("Reliability")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.65))

                            ProgressView(value: viewModel.tiltReliability)
                                .tint(Color.orange)
                                .frame(width: 130)
                        }

                        Text("Some Mac models do not expose hinge data at the hardware level.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct TrackpadCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    private let trackpadAspectRatio: CGFloat = 12194.0 / 7408.0
    private let fingerColors: [Color] = [.cyan, .mint, .yellow, .orange, .pink, .purple]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Trackpad Input Surface", systemImage: "hand.tap")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text("Place one or more fingers on the trackpad. Each finger appears with its own color.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.75))

                GeometryReader { proxy in
                    let points = viewModel.touchPoints.sorted { $0.id < $1.id }
                    let hardwareRect = trackpadSurfaceRect(in: proxy.size)
                    let inputRect = hardwareRect
                    let hardwareRadius = max(20, min(32, hardwareRect.height * 0.17))
                    let inputRadius = hardwareRadius

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: hardwareRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: hardwareRect.width, height: hardwareRect.height)
                            .position(x: hardwareRect.midX, y: hardwareRect.midY)

                        RoundedRectangle(cornerRadius: hardwareRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.35), Color.black.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: inputRect.width, height: inputRect.height)
                            .position(x: inputRect.midX, y: inputRect.midY)

                        TrackpadCaptureView { sample in
                            viewModel.handleTrackpadSample(sample)
                        }
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: inputRadius, style: .continuous))
                        .frame(width: inputRect.width, height: inputRect.height)
                        .position(x: inputRect.midX, y: inputRect.midY)

                        RoundedRectangle(cornerRadius: inputRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            .frame(width: inputRect.width, height: inputRect.height)
                            .position(x: inputRect.midX, y: inputRect.midY)

                        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                            let markerPosition = markerPosition(
                                for: point.normalizedPosition,
                                in: inputRect
                            )

                            TouchPointMarker(
                                index: index + 1,
                                color: fingerColors[index % fingerColors.count]
                            )
                            .position(x: markerPosition.x, y: markerPosition.y)
                            .shadow(color: fingerColors[index % fingerColors.count].opacity(0.55), radius: 16)
                        }

                        if points.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "hand.tap")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                Text("Touch the trackpad to visualize fingers")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.55))
                            }
                            .frame(width: inputRect.width, height: inputRect.height)
                            .position(x: inputRect.midX, y: inputRect.midY)
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 240)
            }
        }
    }

    private func trackpadSurfaceRect(in container: CGSize) -> CGRect {
        let width = min(container.width, container.height * trackpadAspectRatio)
        let height = width / trackpadAspectRatio
        let x = (container.width - width) * 0.5
        let y = (container.height - height) * 0.5
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func markerPosition(for normalizedPoint: CGPoint, in rect: CGRect) -> CGPoint {
        return CGPoint(
            x: rect.minX + (normalizedPoint.x * rect.width),
            y: rect.minY + ((1 - normalizedPoint.y) * rect.height)
        )
    }
}

private struct TouchPointMarker: View {
    let index: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.96), color.opacity(0.2)],
                        center: .center,
                        startRadius: 1,
                        endRadius: 24
                    )
                )
                .frame(width: 44, height: 44)

            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 20, height: 20)

            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.9))
        }
    }
}

private struct StatusChip: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(isActive ? 0.95 : 0.65))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            )
            .animation(.easeInOut(duration: 0.18), value: isActive)
    }
}

private struct AmbientBackground: View {
    let glowPulse: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.14), Color(red: 0.04, green: 0.11, blue: 0.2), Color(red: 0.12, green: 0.09, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.22))
                .frame(width: 560, height: 560)
                .blur(radius: 70)
                .offset(x: -360, y: -260)
                .scaleEffect(glowPulse ? 1.12 : 0.84)

            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 460, height: 460)
                .blur(radius: 68)
                .offset(x: 380, y: 280)
                .scaleEffect(glowPulse ? 0.9 : 1.14)

            RoundedRectangle(cornerRadius: 120)
                .fill(Color.white.opacity(0.03))
                .rotationEffect(.degrees(18))
                .scaleEffect(1.45)
                .blendMode(.plusLighter)
        }
    }
}
