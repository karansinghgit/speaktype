#!/bin/bash
# Fix Python lzma module issue

echo "🔧 Fixing Python lzma module..."

# Check if xz is installed (required for lzma)
if ! brew list xz &>/dev/null; then
    echo "Installing xz library..."
    brew install xz
fi

# Check Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "Python version: $PYTHON_VERSION"

# If using pyenv, rebuild Python with lzma support
if command -v pyenv &> /dev/null; then
    echo "Detected pyenv. Rebuilding Python with lzma support..."
    
    # Set environment variables for pyenv build
    export PYTHON_CONFIGURE_OPTS="--enable-optimizations"
    export LDFLAGS="-L$(brew --prefix xz)/lib"
    export CPPFLAGS="-I$(brew --prefix xz)/include"
    
    # Reinstall current Python version
    pyenv install --force $PYTHON_VERSION
    
    echo "✅ Python rebuilt. Please recreate your virtual environment:"
    echo "   rm -rf ~/.nemo_env"
    echo "   python3 -m venv ~/.nemo_env"
    echo "   source ~/.nemo_env/bin/activate"
    echo "   pip install 'nemo_toolkit[asr]' coremltools torch onnx"
else
    echo "⚠️  Not using pyenv. You may need to:"
    echo "   1. Install xz: brew install xz"
    echo "   2. Rebuild Python with lzma support"
    echo "   3. Or use Homebrew Python: brew install python@3.10"
fi
