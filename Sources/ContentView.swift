import SwiftUI

struct ContentView: View {
    @StateObject private var mlxEngine = MLXEngine()
    @StateObject private var audioCapture = AudioCapture()

    var body: some View {
        ZStack {
            // Dark elegant background
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // The main "Flow" animation orb
                FlowOrbView(isRecording: audioCapture.isRecording, isProcessing: mlxEngine.isProcessing)
                    .onTapGesture {
                        toggleRecording()
                    }
                
                VStack(spacing: 12) {
                    if audioCapture.isRecording {
                        Text("Listening...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    } else if mlxEngine.isProcessing {
                        Text("Thinking...")
                            .font(.headline)
                            .foregroundColor(.blue)
                    } else {
                        Text("Tap to dictate")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    if mlxEngine.transcribedText != "Waiting for audio..." && !audioCapture.isRecording {
                        Text(mlxEngine.transcribedText)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal, 30)
                            .transition(.opacity)
                    }
                }
                
                Spacer()
                
                // Action Button mapping hint
                HStack(spacing: 8) {
                    Image(systemName: "button.programmable")
                    Text("Map to Action Button via Shortcuts")
                        .font(.footnote)
                }
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            mlxEngine.loadModel()
        }
    }
    
    private func toggleRecording() {
        if audioCapture.isRecording {
            audioCapture.stopRecording()
            mlxEngine.processAudio(url: audioCapture.outputURL)
        } else {
            audioCapture.startRecording()
        }
    }
}

// Sleek, Wispr-style glowing morphing orb animation
struct FlowOrbView: View {
    var isRecording: Bool
    var isProcessing: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0.0
    
    var body: some View {
        ZStack {
            // Ambient outer glow (expands when recording)
            Circle()
                .fill(
                    LinearGradient(
                        colors: isProcessing ? [.blue, .cyan] : (isRecording ? [.purple, .pink, .orange] : [.gray.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .blur(radius: isRecording ? 40 : 20)
                .scaleEffect(isRecording ? 1.5 : (isProcessing ? 1.2 : 1.0))
                .opacity(isRecording ? 0.6 : (isProcessing ? 0.8 : 0.2))
                .animation(.easeInOut(duration: isRecording ? 1.0 : 2.0).repeatForever(autoreverses: true), value: isRecording || isProcessing)
            
            // Expanding sonic rings when recording
            if isRecording {
                Circle()
                    .stroke(Color.pink.opacity(0.6), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(scale)
                    .opacity(2.0 - scale)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            scale = 2.0
                        }
                    }
            }
            
            // Solid inner core
            Circle()
                .fill(
                    LinearGradient(
                        colors: isProcessing ? [.cyan, .blue] : (isRecording ? [.pink, .red] : [.gray, .black]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: isRecording ? .pink.opacity(0.5) : .clear, radius: 15, x: 0, y: 10)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            // Mic icon
            Image(systemName: isProcessing ? "waveform" : (isRecording ? "mic.fill" : "mic"))
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: isRecording)
        }
        .frame(height: 200)
    }
}
