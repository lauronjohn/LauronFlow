import SwiftUI

final class RecordingWidgetViewModel: ObservableObject {
    enum Phase: Equatable {
        case recording
        case transcribing
    }

    @Published var phase: Phase = .recording
    @Published var level: Float = 0
}

/// Small floating pill shown while dictating: live audio-reactive bars while recording,
/// a gentle pulse while the sidecar is transcribing. Echoes the soundbar motif from the
/// app/menu bar icons.
struct RecordingWidgetView: View {
    @ObservedObject var model: RecordingWidgetViewModel
    @State private var pulse = false

    private let barCount = 5
    private let brandRed = Color(red: 0.84, green: 0.11, blue: 0.12)

    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.78))
                .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 3)

            HStack(spacing: 5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(brandRed.opacity(model.phase == .transcribing && pulse ? 0.35 : 1.0))
                        .frame(width: 4, height: barHeight(for: index))
                }
            }
            .animation(.easeOut(duration: 0.09), value: model.level)
            .animation(.easeInOut(duration: 0.7), value: pulse)
        }
        .frame(width: 100, height: 44)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: model.phase) { _, _ in startPulseIfNeeded() }
    }

    private func startPulseIfNeeded() {
        guard model.phase == .transcribing else {
            pulse = false
            return
        }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 6
        switch model.phase {
        case .transcribing:
            // Uniform gentle height while the pulse animation handles opacity motion.
            return base + 10
        case .recording:
            let normalized = CGFloat(min(max(model.level * 30, 0), 1))
            let stagger = 0.55 + 0.45 * abs(sin(Double(index) * 1.7))
            return base + normalized * 24 * stagger
        }
    }
}
