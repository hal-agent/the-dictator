import AVFoundation
import Foundation

class AudioCapture: ObservableObject {
    @Published var isRecording = false
    private var audioRecorder: AVAudioRecorder?
    
    var outputURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("dictation.wav")
    }
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
