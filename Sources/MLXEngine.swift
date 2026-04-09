import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Hub
import Tokenizers

@MainActor
class MLXEngine: ObservableObject {
    @Published var transcribedText: String = "Waiting for audio..."
    @Published var isProcessing: Bool = false
    
    private var container: ModelContainer?
    
    init() {
        // Initialize MLX device if needed
        MLX.GPU.set(cacheLimit: 1024 * 1024 * 1024) // 1GB cache limit
    }
    
    func loadModel() {
        self.transcribedText = "Loading Gemma model..."
        Task {
            do {
                // Using the 2B model as a local placeholder until E2B is available on the Hub
                let config = ModelConfiguration(id: "mlx-community/gemma-2-2b-it-4bit")
                self.container = try await #huggingFaceLoadModelContainer(configuration: config)
                self.transcribedText = "Ready to dictate."
                print("Model loaded successfully!")
            } catch {
                self.transcribedText = "Failed to load model."
                print("Error loading model: \(error)")
            }
        }
    }
    
    func processAudio(url: URL) {
        guard let container = container else {
            self.transcribedText = "Model not loaded yet..."
            return
        }
        
        isProcessing = true
        self.transcribedText = "Thinking..."
        
        Task {
            // Note: Once the multimodal MLX E2B model is pushed, the audio buffer goes directly 
            // to context.processor.prepare(input: UserInput(audio: ...)). 
            // For now, to test the loop, we simulate audio-to-text text reasoning.
            let simulateDictation = "I need you to, um, send the email to Noah, no wait, send it to Tolu instead."
            
            let systemPrompt = "You are an expert dictation cleaner. Output ONLY the cleaned intent of the provided text. Remove filler words and correct mid-sentence changes."
            
            let prompt = UserInput.Prompt.messages([
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": simulateDictation]
            ])
            
            let userInput = UserInput(prompt: prompt)
            
            do {
                let finalString = try await container.perform { context in
                    let input = try await context.processor.prepare(input: userInput)
                    let result = try MLXLMCommon.generate(
                        input: input,
                        parameters: GenerateParameters(temperature: 0.1),
                        context: context
                    ) { tokens in
                        return .more
                    }
                    return result.text
                }
                self.transcribedText = finalString
            } catch {
                self.transcribedText = "Generation Error: \(error.localizedDescription)"
            }
            self.isProcessing = false
        }
    }
}
