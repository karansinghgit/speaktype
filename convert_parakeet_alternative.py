#!/usr/bin/env python3
"""
Alternative conversion approach using Hugging Face transformers
This bypasses some NeMo dependencies that might have issues
"""
import sys
import os

# Try to use Hugging Face transformers directly if NeMo has issues
try:
    from transformers import AutoProcessor, AutoModelForSpeechSeq2Seq
    import torch
    print("✅ Using Hugging Face transformers approach")
    USE_HF = True
except ImportError:
    print("⚠️  Hugging Face transformers not available, trying NeMo...")
    USE_HF = False

def convert_with_huggingface(model_name: str, output_dir: str = "./models"):
    """Convert using Hugging Face transformers (simpler approach)"""
    print(f"Loading model from Hugging Face: {model_name}")
    
    try:
        # Load model and processor
        processor = AutoProcessor.from_pretrained(model_name)
        model = AutoModelForSpeechSeq2Seq.from_pretrained(model_name)
        model.eval()
        
        print("✅ Model loaded successfully")
        
        # Export to ONNX
        import torch.onnx
        
        # Create dummy input (audio features)
        # Adjust based on actual model input
        dummy_input = torch.randn(1, 80, 3000)  # (batch, features, time)
        
        onnx_path = os.path.join(output_dir, f"{model_name.replace('/', '_').replace('-', '_')}.onnx")
        
        print(f"Exporting to ONNX: {onnx_path}")
        torch.onnx.export(
            model,
            dummy_input,
            onnx_path,
            input_names=['input_features'],
            output_names=['logits'],
            dynamic_axes={
                'input_features': {2: 'sequence_length'},
                'logits': {1: 'sequence_length'}
            },
            opset_version=13
        )
        
        print(f"✅ ONNX export complete: {onnx_path}")
        return onnx_path
        
    except Exception as e:
        print(f"❌ Hugging Face conversion failed: {e}")
        import traceback
        traceback.print_exc()
        raise

def convert_with_nemo(model_name: str, output_dir: str = "./models"):
    """Convert using NeMo (original approach)"""
    import nemo.collections.asr as nemo_asr
    import torch
    
    print(f"Loading NeMo model: {model_name}")
    model = nemo_asr.models.ASRModel.from_pretrained(model_name=model_name)
    model.eval()
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Export logic here (same as convert_nemo_to_onnx.py)
    # ...
    
    raise NotImplementedError("NeMo conversion - see convert_nemo_to_onnx.py")

if __name__ == "__main__":
    models = [
        "nvidia/parakeet-tdt-0.6b-v2",
        "nvidia/parakeet-tdt-0.6b-v3"
    ]
    
    output_dir = "./models"
    os.makedirs(output_dir, exist_ok=True)
    
    for model_name in models:
        try:
            print(f"\n{'='*60}")
            print(f"Converting: {model_name}")
            print(f"{'='*60}\n")
            
            if USE_HF:
                convert_with_huggingface(model_name, output_dir)
            else:
                convert_with_nemo(model_name, output_dir)
                
        except Exception as e:
            print(f"\n❌ Failed to convert {model_name}: {e}")
            print(f"\nContinuing with next model...\n")
