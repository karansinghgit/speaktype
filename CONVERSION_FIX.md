# Fixing Python lzma Module Issue

## Problem
You're getting: `ModuleNotFoundError: No module named '_lzma'`

This happens when Python was built without lzma support.

## Quick Fix Options

### Option 1: Fix Current Python (Recommended)

```bash
# 1. Install xz library (required for lzma)
brew install xz

# 2. If using pyenv, rebuild Python
export LDFLAGS="-L$(brew --prefix xz)/lib"
export CPPFLAGS="-I$(brew --prefix xz)/include"
pyenv install --force 3.10.13

# 3. Recreate virtual environment
rm -rf ~/.nemo_env
python3 -m venv ~/.nemo_env
source ~/.nemo_env/bin/activate

# 4. Reinstall dependencies
pip install 'nemo_toolkit[asr]' coremltools torch onnx onnxruntime
```

### Option 2: Use Homebrew Python

```bash
# Install Homebrew Python (has lzma support)
brew install python@3.10

# Create new virtual environment with Homebrew Python
/opt/homebrew/bin/python3.10 -m venv ~/.nemo_env
source ~/.nemo_env/bin/activate

# Install dependencies
pip install 'nemo_toolkit[asr]' coremltools torch onnx onnxruntime
```

### Option 3: Use Alternative Conversion (Bypass NeMo)

If NeMo continues to have issues, you can try using Hugging Face transformers directly:

```bash
source ~/.nemo_env/bin/activate
pip install transformers
python convert_parakeet_alternative.py
```

## After Fixing

Once Python is fixed, run:

```bash
./convert_parakeet.sh
```

Or manually:

```bash
source ~/.nemo_env/bin/activate
python convert_nemo_to_onnx.py
python convert_onnx_to_coreml.py models/nvidia_parakeet_tdt_0_6b_v2.onnx
```
