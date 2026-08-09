import AppKit
import SwiftUI

/// Content for the one-time first-run window `OnboardingWindowController` shows.
/// Purely presentational — the window itself omits a close button so "Get Started"
/// is the only way out, which is what makes this "blocking" rather than dismissable.
struct OnboardingView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Welcome to LauronFlow")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 14) {
                OnboardingRow(
                    symbol: "mic.fill",
                    text: "Fully offline dictation — your audio and transcripts never leave this Mac."
                )
                OnboardingRow(
                    symbol: "keyboard",
                    text: "Hold Right Option (⌥) anywhere, speak, and release — the transcript is typed wherever your cursor is. Changeable anytime in Settings > Shortcuts."
                )
                OnboardingRow(
                    symbol: "arrow.uturn.backward",
                    text: "Typed something wrong? ⌃⌥Z undoes the last thing LauronFlow typed."
                )
                OnboardingRow(
                    symbol: "hand.raised.fill",
                    text: "Next, macOS will ask for Microphone and Accessibility access — both are required to record and type your dictation."
                )
                OnboardingRow(
                    symbol: "clock.fill",
                    text: "Your 14-day free trial starts now. Buy a license anytime from the menu bar icon > Settings > License."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button("Get Started", action: onGetStarted)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(28)
        .frame(width: 460, height: 520)
    }
}

private struct OnboardingRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
