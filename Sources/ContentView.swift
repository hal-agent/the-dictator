import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var mlxEngine = MLXEngine()
    @StateObject private var audioCapture = AudioCapture()
    @State private var lastCopiedToast: String?

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
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await toggleDictation() }
                }

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
        .overlay(alignment: .top) {
            if let toast = lastCopiedToast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.85))
                    .cornerRadius(20)
                    .padding(.top, 80)
                    .transition(.opacity)
            }
        }
        .onAppear {
            mlxEngine.loadModel()
            Task { _ = await audioCapture.requestPermission() }
        }
    }

    // MARK: - Dictation flow

    private func toggleDictation() async {
        if audioCapture.isRecording {
            // Stop recording → pass audio to Gemma 4 → copy result to clipboard.
            let samples = audioCapture.stopRecording()
            guard !samples.isEmpty else { return }
            let cleaned = await mlxEngine.processAudio(samples)
            if let cleaned, !cleaned.isEmpty {
                UIPasteboard.general.string = cleaned
                showToast("Copied to clipboard")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } else {
            // Start recording.
            guard await audioCapture.requestPermission() else { return }
            do {
                try audioCapture.startRecording()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } catch {
                mlxEngine.transcribedText = "Mic error: \(error.localizedDescription)"
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation { lastCopiedToast = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { lastCopiedToast = nil }
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
