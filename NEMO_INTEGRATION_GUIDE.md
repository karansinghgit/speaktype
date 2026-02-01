# NeMo Integration Guide for SpeakType

This guide explains how to integrate NVIDIA NeMo Parakeet models into your Xcode project.

## ⚠️ Important Considerations

**NeMo is a Python-based framework**, which makes direct integration into Swift challenging. You have several options:

### Option 1: PythonKit (Recommended for Development)
- **Pros**: Direct access to NeMo, easier to implement
- **Cons**: Requires Python installation, larger app size, slower startup
- **Best for**: Development and testing

### Option 2: CoreML/ONNX Conversion (Recommended for Production)
- **Pros**: Native Swift, better performance, smaller app size
- **Cons**: Requires model conversion, may lose some features
- **Best for**: Production apps

### Option 3: Python Backend Service
- **Pros**: Keeps Python separate, easier to update models
- **Cons**: Requires separate service, more complex architecture
- **Best for**: Enterprise deployments

---

## Option 1: Using PythonKit (Step-by-Step)

### Step 1: Add PythonKit Dependency

1. **Open your Xcode project**
2. **File → Add Package Dependencies...**
3. **Enter URL**: `https://github.com/pvieito/PythonKit.git`
4. **Select version**: Latest release (0.4.0+)
5. **Add to target**: `speaktype`

### Step 2: Install Python and NeMo

You'll need Python 3.8+ with NeMo installed. Create a setup script:

```bash
# Create a Python virtual environment
python3 -m venv ~/.nemo_env

# Activate it
source ~/.nemo_env/bin/activate

# Install NeMo
pip install nemo_toolkit[asr]

# Or install specific version
pip install nemo_toolkit[asr]==2.2.0
```

### Step 3: Update NeMoService.swift

Replace the placeholder methods in `NeMoService.swift` with actual PythonKit code:

```swift
import Foundation
import PythonKit

@Observable
class NeMoService {
    private var python: PythonObject?
    private var model: PythonObject?
    
    private func checkPythonAvailability() -> Bool {
        do {
            let sys = try Python.attemptImport("sys")
            print("Python version: \(sys.version)")
            return true
        } catch {
            print("Python not available: \(error)")
            return false
        }
    }
    
    private func setupPythonEnvironment() async throws {
        // Set Python path to include NeMo
        let sys = try Python.attemptImport("sys")
        let path = sys.path
        
        // Add NeMo installation path
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let nemoPath = "\(homeDir)/.nemo_env/lib/python3.11/site-packages"
        path.insert(0, nemoPath)
        
        // Import NeMo
        let nemo_asr = try Python.attemptImport("nemo.collections.asr")
        self.python = nemo_asr
    }
    
    private func loadNeMoModel(variant: String) async throws {
        let nemo_asr = try Python.attemptImport("nemo.collections.asr")
        
        // Load model from Hugging Face
        let model = try nemo_asr.models.ASRModel.from_pretrained(
            model_name: variant
        )
        
        self.model = model
    }
    
    private func transcribeWithNeMo(audioFile: URL) async throws -> String {
        guard let model = model else {
            throw NeMoError.notInitialized
        }
        
        // Transcribe audio file
        let output = try model.transcribe([audioFile.path])
        let text = String(output[0].text) ?? ""
        
        return text
    }
}
```

### Step 4: Update WhisperService to Route Models

Modify `WhisperService.swift` to detect Parakeet models and route them:

```swift
@Observable
class TranscriptionService {
    private let whisperService = WhisperService()
    private let nemoService = NeMoService()
    
    func loadModel(variant: String) async throws {
        if NeMoService.isParakeetModel(variant) {
            try await nemoService.loadModel(variant: variant)
        } else {
            try await whisperService.loadModel(variant: variant)
        }
    }
    
    func transcribe(audioFile: URL) async throws -> String {
        if nemoService.isInitialized {
            return try await nemoService.transcribe(audioFile: audioFile)
        } else {
            return try await whisperService.transcribe(audioFile: audioFile)
        }
    }
}
```

### Step 5: Update ModelDownloadService

Update `ModelDownloadService.swift` to handle Hugging Face model downloads:

```swift
func downloadModel(variant: String) {
    // ... existing code ...
    
    // Check if it's a Parakeet model
    if NeMoService.isParakeetModel(variant) {
        // For NeMo models, we need to download from Hugging Face
        downloadHuggingFaceModel(variant: variant)
    } else {
        // Use existing WhisperKit download
        downloadWhisperKitModel(variant: variant)
    }
}

private func downloadHuggingFaceModel(variant: String) {
    // Use Hugging Face Hub to download
    // This can be done via Python or direct HTTP download
    // Example using Python:
    // from huggingface_hub import snapshot_download
    // snapshot_download(repo_id=variant, local_dir=cache_dir)
}
```

---

## Option 2: CoreML Conversion (Production Approach)

### Step 1: Convert Parakeet Model to CoreML

Create a Python script to convert the model:

```python
# convert_parakeet_to_coreml.py
import nemo.collections.asr as nemo_asr
import coremltools as ct

# Load NeMo model
model = nemo_asr.models.ASRModel.from_pretrained(
    model_name="nvidia/parakeet-tdt-0.6b-v2"
)

# Export to ONNX first (NeMo supports ONNX export)
model.export("parakeet_model.onnx")

# Convert ONNX to CoreML
# (This step requires additional conversion tools)
```

### Step 2: Use CoreML in Swift

```swift
import CoreML

class NeMoCoreMLService {
    private var model: MLModel?
    
    func loadModel() throws {
        let modelURL = Bundle.main.url(
            forResource: "parakeet_model",
            withExtension: "mlmodelc"
        )!
        model = try MLModel(contentsOf: modelURL)
    }
    
    func transcribe(audioFile: URL) throws -> String {
        // Use CoreML model for inference
        // Process audio, run inference, return text
    }
}
```

---

## Option 3: Python Backend Service

Create a separate Python service that runs locally:

1. **Create Python service** (`nemo_service.py`):
```python
from flask import Flask, request, jsonify
import nemo.collections.asr as nemo_asr

app = Flask(__name__)
model = None

@app.route('/load_model', methods=['POST'])
def load_model():
    variant = request.json['variant']
    model = nemo_asr.models.ASRModel.from_pretrained(model_name=variant)
    return jsonify({"status": "loaded"})

@app.route('/transcribe', methods=['POST'])
def transcribe():
    audio_path = request.json['audio_path']
    output = model.transcribe([audio_path])
    return jsonify({"text": output[0].text})
```

2. **Call from Swift**:
```swift
func transcribeWithNeMo(audioFile: URL) async throws -> String {
    let url = URL(string: "http://localhost:5000/transcribe")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = ["audio_path": audioFile.path]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
    
    return response.text
}
```

---

## Recommended Approach

For **development**: Use **Option 1 (PythonKit)** - it's the fastest to implement.

For **production**: Use **Option 2 (CoreML)** - better performance and user experience.

---

## Troubleshooting

### Python Not Found
- Ensure Python 3.8+ is installed: `python3 --version`
- Add Python to PATH in Xcode scheme environment variables

### NeMo Import Errors
- Verify NeMo is installed: `pip show nemo_toolkit`
- Check Python path includes NeMo installation

### Model Download Issues
- Hugging Face models require authentication for some models
- Set `HF_TOKEN` environment variable if needed

---

## Next Steps

1. Choose your integration approach
2. Implement the chosen option
3. Test with a small Parakeet model first
4. Update UI to show model type (Whisper vs Parakeet)
5. Add error handling for unsupported models

For questions or issues, refer to:
- [NeMo Documentation](https://docs.nvidia.com/deeplearning/nemo/user-guide/docs/en/stable/)
- [PythonKit GitHub](https://github.com/pvieito/PythonKit)
- [Hugging Face NeMo Models](https://huggingface.co/models?library=nemo)
