import SwiftUI

struct ContentView: View {
    @StateObject private var mlxEngine = MLXEngine()
    @StateObject private var audioCapture = AudioCapture()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("NeuralFlow")
                .font(.largeTitle)
                .bold()
            
            Text("Zero-Latency Local Dictation")
                .foregroundColor(.secondary)
            
            Spacer()
            
            if audioCapture.isRecording {
                Text("Listening...")
                    .foregroundColor(.red)
                    .pulseAnimation()
            } else {
                Text(mlxEngine.transcribedText)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Spacer()
            
            Button(action: {
                if audioCapture.isRecording {
                    audioCapture.stopRecording()
                    mlxEngine.processAudio(url: audioCapture.outputURL)
                } else {
                    audioCapture.startRecording()
                }
            }) {
                Text(audioCapture.isRecording ? "Stop & Process" : "Start Dictation")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(audioCapture.isRecording ? Color.red : Color.blue)
                    .cornerRadius(15)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

extension View {
    func pulseAnimation() -> some View {
        self.opacity(0.5)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
    }
}
