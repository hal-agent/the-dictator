import Foundation
import MLX
import MLXLMCommon
import MLXVLM

@MainActor
class MLXEngine: ObservableObject {
    @Published var transcribedText: String = "Waiting for audio..."
    @Published var isProcessing: Bool = false

    private var container: ModelContainer?

    init() {
        MLX.GPU.set(cacheLimit: 256 * 1024 * 1024) // 256 MB cache limit — leaves headroom for model weights
    }

    func loadModel() {
        self.transcribedText = "Loading Gemma 4 E2B model..."
        Task {
            do {
                // Gemma 4 E2B 4-bit: Google's multimodal edge model with native audio tower (~2 GB)
                self.container = try await VLMModelFactory.shared.loadContainer(
                    configuration: VLMRegistry.gemma4_E2B_it_4bit
                )
                self.transcribedText = "Ready to dictate."
                print("Model loaded successfully!")
            } catch {
                self.transcribedText = "Load error: \(error.localizedDescription)"
                print("Error loading model: \(error)")
            }
        }
    }

    /// Runs Gemma 4's audio tower + language model end-to-end:
    /// raw PCM → speech recognition → cleanup → final text.
    /// - Parameter audioSamples: 16 kHz mono float32 PCM samples.
    /// - Returns: The cleaned text, or nil on failure.
    func processAudio(_ audioSamples: [Float]) async -> String? {
        guard let container = container else {
            self.transcribedText = "Model not loaded yet..."
            return nil
        }
        guard !audioSamples.isEmpty else {
            self.transcribedText = "Nothing was said."
            return nil
        }

        isProcessing = true
        self.transcribedText = "Thinking..."

        let systemPrompt = """
            You are an expert multilingual dictation assistant. The user speaks German, \
            English, French, or Dutch — detect the language from the audio and respond in \
            the same language. Transcribe what the user said, then clean it up: remove \
            filler words (um, uh, like, äh, alors, euh), fix mid-sentence corrections \
            (honor the user's latest intent), and fix obvious grammar. Preserve meaning, \
            names, and technical terms. Output ONLY the final cleaned text — no preamble, \
            no commentary, no quotation marks, no language label.
            """

        let userInput: UserInput = {
            var u = UserInput(chat: [
                .system(systemPrompt),
                .user("Transcribe and clean the following audio."),
            ])
            u.audios = [audioSamples]
            return u
        }()

        do {
            let finalString = try await container.perform { (context: ModelContext) -> String in
                let input = try await context.processor.prepare(input: userInput)
                let stream = try MLXLMCommon.generate(
                    input: input,
                    parameters: GenerateParameters(temperature: 0.1),
                    context: context
                )
                var output = ""
                for await event in stream {
                    if case .chunk(let text) = event {
                        output += text
                    }
                }
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            self.transcribedText = finalString
            self.isProcessing = false
            return finalString
        } catch {
            self.transcribedText = "Generation Error: \(error.localizedDescription)"
            self.isProcessing = false
            return nil
        }
    }
}
