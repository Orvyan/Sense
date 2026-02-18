import SwiftUI
import AppKit

@main
struct SenseApp: App {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: viewModel)
                .frame(minWidth: 760, minHeight: 560)
                .background(
                    ResizableWindowConfigurator(
                        minSize: NSSize(width: 760, height: 560)
                    )
                )
                .onAppear {
                    viewModel.start()
                }
                .onDisappear {
                    viewModel.stop()
                }
        }
        .defaultSize(width: 1240, height: 900)
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
    }
}

private struct ResizableWindowConfigurator: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(from: nsView)
        }
    }

    private func configureWindow(from view: NSView) {
        guard let window = view.window else { return }
        window.styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable])
        window.minSize = minSize
        window.title = "Sense"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
    }
}
