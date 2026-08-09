import AppKit

/// Draws a tiny bar-waveform into a menu bar-sized `NSImage` from a rolling window
/// of recent RMS levels. Kept separate from `StatusItemController` since it's pure
/// drawing with no state of its own.
enum WaveformIconRenderer {
    static let barCount = 4

    private static let canvasSize = NSSize(width: 18, height: 18)
    // Not a template color: the recording icon it replaces (`MenuGlyphRecording`)
    // is deliberately non-template too, so "recording" reads as a color change,
    // not just a shape change, regardless of menu bar appearance.
    private static let brandRed = NSColor(red: 0.84, green: 0.11, blue: 0.12, alpha: 1.0)

    /// `levels` should hold up to `barCount` recent RMS samples, most recent last.
    /// Missing samples (e.g. right after a reset) render as a flat, minimal bar.
    static func image(for levels: [Float]) -> NSImage {
        NSImage(size: canvasSize, flipped: false) { rect in
            brandRed.setFill()

            let barWidth: CGFloat = 2.5
            let spacing: CGFloat = 2
            let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
            var x = (rect.width - totalWidth) / 2

            for index in 0..<barCount {
                let level = index < levels.count ? levels[index] : 0
                let normalized = CGFloat(min(max(level * 30, 0), 1))
                let height = max(2, normalized * (rect.height - 4))
                let y = (rect.height - height) / 2
                let barRect = NSRect(x: x, y: y, width: barWidth, height: height)
                NSBezierPath(roundedRect: barRect, xRadius: 1, yRadius: 1).fill()
                x += barWidth + spacing
            }

            return true
        }
    }
}
