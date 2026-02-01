#!/bin/bash
set -e

echo "🔄 Recreating Python environment with fixed Python..."

# Find a working Python (preferably Homebrew or system Python with lzma)
PYTHON_BIN=""

# Try Homebrew Python first
if [ -f "/opt/homebrew/bin/python3.10" ]; then
    PYTHON_BIN="/opt/homebrew/bin/python3.10"
    echo "✅ Found Homebrew Python: $PYTHON_BIN"
elif [ -f "/usr/local/bin/python3.10" ]; then
    PYTHON_BIN="/usr/local/bin/python3.10"
    echo "✅ Found system Python: $PYTHON_BIN"
elif command -v python3.10 &> /dev/null; then
    PYTHON_BIN=$(which python3.10)
    echo "✅ Found Python 3.10: $PYTHON_BIN"
else
    echo "❌ Python 3.10 not found. Please install:"
    echo "   brew install python@3.10"
    exit 1
fi

# Test if this Python has lzma
echo "Testing lzma support..."
if $PYTHON_BIN -c "import lzma; print('✅ lzma OK')" 2>/dev/null; then
    echo "✅ Python has lzma support"
else
    echo "❌ This Python also lacks lzma. Installing Homebrew Python..."
    brew install python@3.10
    PYTHON_BIN="/opt/homebrew/bin/python3.10"
fi

# Remove old environment
echo "Removing old virtual environment..."
rm -rf ~/.nemo_env

# Create new environment with working Python
echo "Creating new virtual environment with: $PYTHON_BIN"
$PYTHON_BIN -m venv ~/.nemo_env

# Activate and upgrade pip
source ~/.nemo_env/bin/activate
pip install --upgrade pip setuptools wheel

# Install dependencies
echo "Installing dependencies..."
pip install 'nemo_toolkit[asr]' coremltools torch onnx onnxruntime

# Verify installation
echo "Verifying installation..."
python -c "import nemo.collections.asr; import lzma; print('✅ All dependencies OK')"

echo ""
echo "✅ Environment ready! Now running conversion..."
echo ""

# Run conversion
python convert_nemo_to_onnx.py
