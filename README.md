# NeuralFlow 🎙️🧠

Zero-latency, on-device Wispr Flow clone for iOS using Gemma 4 E2B and MLX Swift. 
Designed to be triggered entirely offline via the iPhone 17 Pro Action Button.

## Setup Instructions

1. Clone this repository to your Mac.
2. Install XcodeGen if you haven't already: `brew install xcodegen`
3. Generate the Xcode project:
   ```bash
   xcodegen
   ```
4. Open `NeuralFlow.xcodeproj`.
5. Select your iPhone as the build target.
6. Let Xcode fetch the `mlx-swift` package dependencies.
7. Build and run!

## Architecture
- **MLX Swift**: Handles the local 4-bit quantized Gemma 4 model execution.
- **AVFoundation**: Captures 16kHz audio directly from the device microphone.
- **AppIntents**: Exposes the logic to iOS Shortcuts so you can bind it to the Action Button for zero-latency execution outside of the app.
