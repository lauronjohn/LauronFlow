import AppKit
import SwiftUI

/// Owns the borderless, click-through floating panel shown while dictating.
final class RecordingWidgetController {
    private let viewModel = RecordingWidgetViewModel()
    private var panel: NSPanel?

    func show() {
        viewModel.phase = .recording
        viewModel.level = 0

        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func updateLevel(_ level: Float) {
        viewModel.level = level
    }

    func setTranscribing() {
        viewModel.phase = .transcribing
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: 100, height: 44)
        let hostingView = NSHostingView(rootView: RecordingWidgetView(model: viewModel))
        hostingView.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        // Visible on every Space, doesn't animate/reposition during Space switches, and
        // stays visible over a fullscreened app — this is a system-wide dictation tool.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = hostingView
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.minY + 90
        )
        panel.setFrameOrigin(origin)
    }
}
