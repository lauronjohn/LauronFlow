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
}
