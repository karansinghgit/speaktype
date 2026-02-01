# Parakeet Models Setup - Quick Start

## ✅ Prerequisites Completed

You've already installed:
- ✅ Python 3.8+
- ✅ NeMo toolkit (`nemo_toolkit[asr]`)

## 📦 Additional Package Needed

To download Parakeet models from Hugging Face, install `huggingface_hub`:

```bash
source ~/.nemo_env/bin/activate
pip install huggingface_hub
```

## 🚀 How It Works

The app now supports both Whisper and Parakeet models:

1. **Whisper Models** (existing):
   - Uses WhisperKit (native Swift)
   - Models: `openai_whisper-*`

2. **Parakeet Models** (new):
   - Uses NeMo via Python
   - Models: `nvidia/parakeet-*`
   - Automatically detected and routed to NeMoService

## 🎯 Using Parakeet Models

1. **Open the app** and go to **AI Models** section
2. **Select a Parakeet model** (e.g., "Parakeet TDT 0.6B V2")
3. **Click Download** - The model will be downloaded from Hugging Face
4. **Click Use** - The model will be loaded via NeMo
5. **Start transcribing** - Audio will be processed using the Parakeet model

## 🔧 Troubleshooting

### "Python not found"
- Ensure your virtual environment is at `~/.nemo_env`
- Or install Python 3.8+ system-wide

### "huggingface_hub not installed"
```bash
source ~/.nemo_env/bin/activate
pip install huggingface_hub
```

### "NeMo import error"
```bash
source ~/.nemo_env/bin/activate
pip install 'nemo_toolkit[asr]'
```

### Model download fails
- Check internet connection
- Some models may require Hugging Face authentication
- Check console logs for detailed error messages

## 📝 Model Information

### Available Parakeet Models

1. **Parakeet TDT 0.6B V3**
   - Multilingual (25 European languages)
   - Size: ~600 MB
   - Best for: Multilingual transcription

2. **Parakeet TDT 0.6B V2**
   - English-only
   - Size: ~600 MB
   - Features: Timestamps, punctuation, capitalization
   - Best for: English transcription with formatting

## 🔍 How to Add More Parakeet Models

Edit `speaktype/Models/AIModel.swift` and add to `availableModels`:

```swift
AIModel(
    name: "Parakeet Model Name",
    variant: "nvidia/model-name",
    details: "Description",
    rating: "Rating",
    size: "Size",
    speed: 8.0,
    accuracy: 9.0
)
```

The `variant` should match the Hugging Face model ID.

## ⚡ Performance Notes

- Parakeet models use Python/NeMo, which may be slower than native WhisperKit
- First transcription may take longer (model loading)
- Subsequent transcriptions will be faster (model stays in memory)

## 🐛 Known Limitations

- Model download progress is not as detailed as WhisperKit (shows 0% then 100%)
- Requires Python environment to be set up correctly
- Larger app size due to Python dependency

For more details, see `NEMO_INTEGRATION_GUIDE.md`.
