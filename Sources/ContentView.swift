import SwiftUI

struct ContentView: View {
    @StateObject private var mlxEngine = MLXEngine()
    @StateObject private var audioCapture = AudioCapture()

    var body: some View {
        ZStack {
            // Dark background
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top "Dynamic Island" style overlay
                HStack {
                    Image(systemName: "mic.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(audioCapture.isRecording ? "Hold to stop" : "Hold to speak")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "power")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(Color(white: 0.2))
                            .clipShape(Circle())
                        
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(Color(white: 0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(white: 0.1))
                .cornerRadius(30)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                Spacer()
                
                // Status/Animation Area
                VStack(spacing: 20) {
                    if audioCapture.isRecording {
                        WaveformView()
                            .frame(height: 60)
                            .padding(.horizontal, 40)
                    } else if mlxEngine.isProcessing {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(white: 0.3))
                    }
                    
                    if mlxEngine.transcribedText != "Waiting for audio..." {
                        Text(mlxEngine.transcribedText)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(white: 0.15))
                            .cornerRadius(16)
                            .padding(.horizontal, 30)
                    }
                }
                
                Spacer()
                
                // Action Button hint (matches the style of bottom bar)
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Text("Trigger via Action Button")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                    
                    Spacer()
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(white: 0.4))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(white: 0.1))
                .cornerRadius(30)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            mlxEngine.loadModel()
        }
    }
}

// Simple audio waveform animation mimicking the Dynamic Island equalizer
struct WaveformView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<8) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 6, height: isAnimating ? CGFloat.random(in: 10...50) : 10)
                    .animation(
                        Animation.easeInOut(duration: 0.3)
                            .repeatForever()
                            .delay(Double(i) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
