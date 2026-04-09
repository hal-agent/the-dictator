import AppIntents
import UIKit

struct DictationIntent: AppIntent {
    static var title: LocalizedStringResource = "Dictate with NeuralFlow"
    static var description = IntentDescription("Records audio and processes it using local Gemma 4.")
    
    // This intent runs in the background
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // In a full implementation, you would:
        // 1. Trigger audio capture
        // 2. Wait for silence (VAD) or a set duration
        // 3. Process via MLXEngine
        // 4. Return the cleaned string to the Shortcuts app.
        
        let resultString = "This text was processed silently in the background."
        
        // Haptic feedback to let the user know dictation is complete
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        return .result(value: resultString)
    }
}
