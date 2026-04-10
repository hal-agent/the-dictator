import AVFoundation
import Foundation

/// Captures raw PCM float32 audio at 16 kHz mono — the format Gemma 4's
/// audio feature extractor expects.
@MainActor
class AudioCapture: ObservableObject {
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private var buffer: [Float] = []
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    /// Maximum recording length in samples (30 seconds at 16 kHz = 480 000).
    /// Gemma 4's feature extractor truncates beyond this anyway.
    private let maxSamples = 480_000

    func requestPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        if !granted {
            errorMessage = "Microphone permission denied."
        }
        return granted
    }

    func startRecording() throws {
        guard !isRecording else { return }
        errorMessage = nil
        buffer.removeAll(keepingCapacity: true)

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioCapture", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create 16kHz target format"])
        }
        self.targetFormat = target
        self.converter = AVAudioConverter(from: inputFormat, to: target)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] inputBuffer, _ in
            self?.handleInput(inputBuffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() -> [Float] {
        guard isRecording else { return buffer }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return buffer
    }

    // MARK: - Private

    private func handleInput(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converter, let targetFormat else { return }
        guard buffer.count < maxSamples else { return }

        // Allocate an output buffer large enough for the resampled frames.
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let estimatedFrames = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 16)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: estimatedFrames
        ) else { return }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard status != .error, error == nil else {
            Task { @MainActor in self.errorMessage = error?.localizedDescription ?? "converter error" }
            return
        }

        // Append samples to the rolling buffer.
        guard let channelData = outputBuffer.floatChannelData?[0] else { return }
        let frameCount = Int(outputBuffer.frameLength)
        let samples = UnsafeBufferPointer(start: channelData, count: frameCount)

        Task { @MainActor in
            let remaining = self.maxSamples - self.buffer.count
            guard remaining > 0 else { return }
            let toAppend = min(remaining, frameCount)
            self.buffer.append(contentsOf: samples.prefix(toAppend))
        }
    }
}
