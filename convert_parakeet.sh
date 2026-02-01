#!/bin/bash
set -e

# Activate Python environment
if [ -f ~/.nemo_env/bin/activate ]; then
    source ~/.nemo_env/bin/activate
    echo "✅ Activated Python environment"
else
    echo "❌ Python environment not found at ~/.nemo_env"
    echo "Please create it first: python3 -m venv ~/.nemo_env"
    exit 1
fi

# Create models directory
mkdir -p models

echo "🚀 Starting Parakeet model conversion..."
echo ""

# Step 1: Convert NeMo to ONNX
echo "Step 1: Converting NeMo models to ONNX..."
echo "=========================================="
python convert_nemo_to_onnx.py

echo ""
echo "Step 2: Converting ONNX models to CoreML..."
echo "=========================================="

# Step 2: Convert each ONNX file to CoreML
for onnx_file in models/*.onnx; do
    if [ -f "$onnx_file" ]; then
        echo ""
        echo "Converting: $onnx_file"
        python convert_onnx_to_coreml.py "$onnx_file"
    fi
done

echo ""
echo "✅ Conversion complete!"
echo ""
echo "CoreML models are in: ./models/"
echo ""
echo "Next steps:"
echo "1. Copy .mlpackage files to your Xcode project"
echo "2. Or place them in ~/Library/Application Support/SpeakType/CoreMLModels/"
echo "3. Update ParakeetService.swift with correct input/output shapes"
