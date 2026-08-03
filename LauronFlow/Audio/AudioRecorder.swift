import AVFoundation
import Foundation

enum AudioRecorderError: Error {
    case formatCreationFailed
    case converterCreationFailed
}

/// Taps the default input, converts to 16kHz mono 16-bit PCM, and streams
/// it straight to a temp WAV file for the duration of the hold.
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private(set) var isRecording = false

    /// Fired on the main thread with a 0...1-ish RMS level for each tap buffer, for a live
    /// waveform visualization. Not persisted anywhere — purely a UI feedback signal.
    var onLevelUpdate: ((Float) -> Void)?

    @discardableResult
    func start() throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lauronflow-\(UUID().uuidString).wav")

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: AudioConstants.sampleRate,
            channels: AudioConstants.channelCount,
            interleaved: true
        ) else {
            throw AudioRecorderError.formatCreationFailed
        }
        self.targetFormat = targetFormat

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: AudioConstants.sampleRate,
            AVNumberOfChannelsKey: AudioConstants.channelCount,
            AVLinearPCMBitDepthKey: AudioConstants.bitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(
            forWriting: tempURL,
            settings: settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
        audioFile = file

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterCreationFailed
        }
        self.converter = converter

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
        return tempURL
    }

    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        converter = nil
        isRecording = false
    }

    private func process(buffer: AVAudioPCMBuffer) {
        if onLevelUpdate != nil {
            let level = Self.rmsLevel(of: buffer)
            DispatchQueue.main.async { [weak self] in
                self?.onLevelUpdate?(level)
            }
        }

        guard let converter, let audioFile, let targetFormat else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: max(capacity, 1)
        ) else { return }

        var conversionError: NSError?
        var consumed = false
        converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            NSLog("AudioRecorder conversion error: \(conversionError)")
            return
        }
        do {
            try audioFile.write(from: outputBuffer)
        } catch {
            NSLog("AudioRecorder write error: \(error)")
        }
    }

    /// Root-mean-square of the buffer's first channel, roughly normalized so typical speech
    /// lands well under 1.0 (headroom for the widget's animation curve to react to peaks).
    private static func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let samples = channelData[0]
        var sumOfSquares: Float = 0
        for i in 0..<frameLength {
            let sample = samples[i]
            sumOfSquares += sample * sample
        }
        return (sumOfSquares / Float(frameLength)).squareRoot()
    }
}
