# CoreML Conversion Guide for Parakeet Models

This guide explains how to convert NVIDIA Parakeet NeMo models to CoreML format for native Swift performance.

## 🎯 Why CoreML?

- ✅ **Native Performance**: Runs on Apple Silicon Neural Engine
- ✅ **No Python Dependency**: Pure Swift implementation
- ✅ **Smaller App Size**: No Python runtime needed
- ✅ **Better UX**: Faster startup and inference
- ✅ **Offline**: Works completely offline

## 📋 Prerequisites

1. **Python Environment** (for conversion only):
   ```bash
   python3 -m venv ~/.nemo_env
   source ~/.nemo_env/bin/activate
   pip install 'nemo_toolkit[asr]'
   pip install coremltools
   pip install torch
   pip install onnx
   pip install onnxruntime
   ```

2. **Xcode** with CoreML Tools
3. **macOS** (for conversion)

## 🔄 Conversion Process

### Step 1: Export NeMo Model to ONNX

Create a Python script `convert_nemo_to_onnx.py`:

```python
#!/usr/bin/env python3
"""
Convert NeMo Parakeet model to ONNX format
"""
import nemo.collections.asr as nemo_asr
import torch
import os

def convert_to_onnx(model_name: str, output_dir: str = "./models"):
    """Convert NeMo model to ONNX"""
    
    print(f"Loading NeMo model: {model_name}")
    model = nemo_asr.models.ASRModel.from_pretrained(model_name=model_name)
    
    # Set model to evaluation mode
    model.eval()
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Export to ONNX
    # Note: NeMo models may need custom export logic
    # This is a simplified example - adjust based on your model architecture
    
    # Create dummy input (adjust shape based on your model)
    # Typical ASR models expect: (batch, time, features)
    dummy_input = torch.randn(1, 1000, 80)  # Adjust dimensions
    
    onnx_path = os.path.join(output_dir, f"{model_name.replace('/', '_')}.onnx")
    
    print(f"Exporting to ONNX: {onnx_path}")
    torch.onnx.export(
        model,
        dummy_input,
        onnx_path,
        input_names=['audio_features'],
        output_names=['logits', 'text'],
        dynamic_axes={
            'audio_features': {0: 'batch', 1: 'time'},
            'logits': {0: 'batch', 1: 'time'},
            'text': {0: 'batch'}
        },
        opset_version=13
    )
    
    print(f"✅ ONNX export complete: {onnx_path}")
    return onnx_path

if __name__ == "__main__":
    # Convert Parakeet models
    models = [
        "nvidia/parakeet-tdt-0.6b-v2",
        "nvidia/parakeet-tdt-0.6b-v3"
    ]
    
    for model_name in models:
        try:
            convert_to_onnx(model_name)
        except Exception as e:
            print(f"❌ Failed to convert {model_name}: {e}")
```

Run the conversion:
```bash
source ~/.nemo_env/bin/activate
python convert_nemo_to_onnx.py
```

### Step 2: Convert ONNX to CoreML

Create `convert_onnx_to_coreml.py`:

```python
#!/usr/bin/env python3
"""
Convert ONNX model to CoreML format
"""
import coremltools as ct
import os

def convert_onnx_to_coreml(onnx_path: str, output_dir: str = "./models"):
    """Convert ONNX model to CoreML"""
    
    model_name = os.path.basename(onnx_path).replace('.onnx', '')
    coreml_path = os.path.join(output_dir, f"{model_name}.mlpackage")
    
    print(f"Converting {onnx_path} to CoreML...")
    
    # Load ONNX model
    model = ct.convert(
        onnx_path,
        inputs=[
            ct.TensorType(
                name="audio_features",
                shape=(1, ct.RangeDim(lower_bound=1, upper_bound=3000), 80)  # Adjust based on model
            )
        ],
        outputs=[
            ct.TensorType(name="logits"),
            ct.TensorType(name="text")
        ],
        minimum_deployment_target=ct.target.macOS13,  # Adjust for your target
        compute_units=ct.ComputeUnit.ALL  # Use CPU, GPU, and Neural Engine
    )
    
    # Add metadata
    model.author = "SpeakType"
    model.short_description = f"Parakeet ASR Model: {model_name}"
    model.version = "1.0"
    
    # Save CoreML model
    model.save(coreml_path)
    
    print(f"✅ CoreML conversion complete: {coreml_path}")
    return coreml_path

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python convert_onnx_to_coreml.py <onnx_file>")
        sys.exit(1)
    
    onnx_path = sys.argv[1]
    convert_onnx_to_coreml(onnx_path)
```

Run the conversion:
```bash
source ~/.nemo_env/bin/activate
python convert_onnx_to_coreml.py models/nvidia_parakeet-tdt-0.6b-v2.onnx
```

### Step 3: Optimize CoreML Model (Optional)

For better performance, optimize the model:

```python
import coremltools.optimize.coreml as cto

# Load model
model = ct.models.MLModel("model.mlpackage")

# Apply optimizations
config = cto.OptimizationConfig(
    global_config=cto.OpPaletteConfig(
        op_selector=cto.select_all_ops(),
        op_configs={
            "linear": cto.LinearQuantizationConfig(mode="linear_symmetric", weight_threshold=512)
        }
    )
)

optimized_model = cto.palette_optimize_weights(model, config=config)
optimized_model.save("model_optimized.mlpackage")
```

### Step 4: Add Model to Xcode Project

1. **Copy model to project**:
   ```bash
   cp models/nvidia_parakeet-tdt-0.6b-v2.mlpackage speaktype/Resources/CoreMLModels/
   ```

2. **Add to Xcode**:
   - Right-click `speaktype/Resources` folder
   - Select "Add Files to speaktype..."
   - Select the `.mlpackage` file
   - Ensure "Copy items if needed" is checked
   - Add to target: `speaktype`

3. **Or use Application Support** (for downloaded models):
   - Models will be downloaded to `~/Library/Application Support/SpeakType/CoreMLModels/`
   - The app will automatically find them there

## 🔧 Alternative: Use NeMo's Export Functionality

Some NeMo models support direct export. Check if your model supports:

```python
import nemo.collections.asr as nemo_asr

model = nemo_asr.models.ASRModel.from_pretrained("nvidia/parakeet-tdt-0.6b-v2")

# Try to export (if supported)
try:
    model.export("parakeet_model.onnx")
except AttributeError:
    print("Direct export not supported, use manual conversion")
```

## 📦 Model Download for CoreML

Update `ModelDownloadService` to download pre-converted CoreML models, or:

1. **Convert models once** and bundle with app
2. **Host converted models** on your server/CDN
3. **Provide conversion tool** for users (advanced)

## 🎯 Integration Steps

1. **Convert models** using scripts above
2. **Add models to Xcode** project
3. **Update ParakeetService** to match your model's input/output format
4. **Test inference** with sample audio
5. **Optimize** if needed

## ⚠️ Important Notes

### Model Input/Output Format

Parakeet models typically expect:
- **Input**: Audio features (mel spectrogram, MFCC, etc.)
  - Shape: `(batch, time, features)`
  - Example: `(1, 1000, 80)` for 1000 time steps, 80 features
- **Output**: 
  - Logits: `(batch, time, vocab_size)`
  - Text: Decoded transcription string

### Audio Preprocessing

You'll need to implement audio preprocessing in Swift:

```swift
import AVFoundation
import Accelerate

func preprocessAudio(audioFile: URL) throws -> MLMultiArray {
    // 1. Load audio file
    let audioFile = try AVAudioFile(forReading: audioFile)
    
    // 2. Convert to 16kHz mono if needed
    // 3. Extract mel spectrogram or MFCC features
    // 4. Normalize features
    // 5. Convert to MLMultiArray
    
    // See AVFoundation and Accelerate documentation
}
```

### Model Compatibility

- ✅ **macOS 13+**: Full CoreML support
- ✅ **Apple Silicon**: Neural Engine acceleration
- ⚠️ **Intel Macs**: CPU/GPU only (slower)
- ❌ **iOS**: Requires iOS 16+ for some features

## 🐛 Troubleshooting

### "Model not found"
- Check model path in `findCoreMLModel()`
- Ensure model is in bundle or Application Support
- Verify model name matches variant

### "Input shape mismatch"
- Check model's expected input shape
- Adjust `preprocessAudio()` output shape
- Verify ONNX→CoreML conversion preserved shapes

### "Inference fails"
- Check model output format
- Verify audio preprocessing matches training
- Test with known-good audio sample

### "Performance is slow"
- Use Neural Engine: `computeUnits = .cpuAndNeuralEngine`
- Optimize model (quantization)
- Batch process if possible

## 📚 Resources

- [CoreML Tools Documentation](https://coremltools.readme.io/)
- [NeMo Export Guide](https://docs.nvidia.com/deeplearning/nemo/user-guide/docs/en/stable/asr/asr_export.html)
- [ONNX to CoreML](https://coremltools.readme.io/docs/onnx-conversion)
- [CoreML Performance](https://developer.apple.com/documentation/coreml/optimizing_your_model_s_performance)

## 🚀 Quick Start Script

Save this as `convert_parakeet.sh`:

```bash
#!/bin/bash
set -e

source ~/.nemo_env/bin/activate

MODEL_NAME="nvidia/parakeet-tdt-0.6b-v2"
OUTPUT_DIR="./models"

echo "Converting $MODEL_NAME to CoreML..."

# Step 1: Export to ONNX
python convert_nemo_to_onnx.py

# Step 2: Convert to CoreML
ONNX_FILE="$OUTPUT_DIR/$(echo $MODEL_NAME | tr '/' '_').onnx"
python convert_onnx_to_coreml.py "$ONNX_FILE"

echo "✅ Conversion complete!"
echo "Model saved to: $OUTPUT_DIR"
```

Make it executable and run:
```bash
chmod +x convert_parakeet.sh
./convert_parakeet.sh
```

---

**Note**: Model conversion can be complex and may require adjustments based on the specific Parakeet model architecture. Test thoroughly with sample audio before deploying.
