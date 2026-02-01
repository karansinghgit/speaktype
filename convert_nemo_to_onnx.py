#!/usr/bin/env python3
"""
Convert NeMo Parakeet model to ONNX format
"""
import nemo.collections.asr as nemo_asr
import torch
import os
import sys

def convert_to_onnx(model_name: str, output_dir: str = "./models"):
    """Convert NeMo model to ONNX"""
    
    print(f"Loading NeMo model: {model_name}")
    try:
        model = nemo_asr.models.ASRModel.from_pretrained(model_name=model_name)
        print(f"✅ Model loaded successfully")
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        raise
    
    # Set model to evaluation mode
    model.eval()
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # For Parakeet models, we need to export the encoder/decoder separately
    # or use NeMo's export functionality if available
    print("Attempting to export model to ONNX...")
    
    # Try NeMo's built-in export if available
    try:
        if hasattr(model, 'export'):
            onnx_path = os.path.join(output_dir, f"{model_name.replace('/', '_').replace('-', '_')}.onnx")
            print(f"Using NeMo's export method...")
            model.export(onnx_path)
            print(f"✅ ONNX export complete: {onnx_path}")
            return onnx_path
    except Exception as e:
        print(f"NeMo export not available or failed: {e}")
        print("Trying manual PyTorch export...")
    
    # Try exporting just the encoder (simpler, more likely to work)
    try:
        print("Attempting to export encoder only...")
        if hasattr(model, 'encoder'):
            encoder = model.encoder
            encoder.eval()
            
            # Create dummy input for encoder
            # Parakeet models typically use mel spectrogram features
            dummy_input = torch.randn(1, 1000, 80)  # (batch, time, features)
            
            onnx_path = os.path.join(output_dir, f"{model_name.replace('/', '_').replace('-', '_')}_encoder.onnx")
            
            print(f"Exporting encoder to: {onnx_path}")
            torch.onnx.export(
                encoder,
                dummy_input,
                onnx_path,
                input_names=['audio_features'],
                output_names=['encoder_output'],
                dynamic_axes={
                    'audio_features': {1: 'time'},
                    'encoder_output': {1: 'time'}
                },
                opset_version=18  # Use newer opset
            )
            print(f"✅ Encoder ONNX export complete: {onnx_path}")
            return onnx_path
    except Exception as e:
        print(f"Encoder export failed: {e}")
        print("Trying full model export...")
    
    # Manual export: Get the underlying PyTorch model
    try:
        # Parakeet models typically have an encoder-decoder architecture
        # We'll need to export the forward pass
        print("Preparing model for ONNX export...")
        
        # Create dummy input - adjust based on actual model input
        # Parakeet models typically expect mel spectrogram features
        # Shape: (batch, time, features) or (batch, features, time)
        batch_size = 1
        time_steps = 1000  # Adjust based on model
        n_mels = 80  # Typical mel spectrogram features
        
        # Try different input shapes
        dummy_inputs = [
            torch.randn(batch_size, time_steps, n_mels),  # (B, T, F)
            torch.randn(batch_size, n_mels, time_steps),  # (B, F, T)
        ]
        
        onnx_path = os.path.join(output_dir, f"{model_name.replace('/', '_').replace('-', '_')}.onnx")
        
        for i, dummy_input in enumerate(dummy_inputs):
            try:
                print(f"Trying input shape: {dummy_input.shape}")
                
                # Export to ONNX
                torch.onnx.export(
                    model,
                    dummy_input,
                    onnx_path,
                    input_names=['audio_features'],
                    output_names=['logits', 'text'],
                    dynamic_axes={
                        'audio_features': {0: 'batch', 1: 'time' if i == 0 else None},
                        'logits': {0: 'batch', 1: 'time'},
                        'text': {0: 'batch'}
                    },
                    opset_version=18,  # Use newer opset for better compatibility
                    do_constant_folding=True,
                    verbose=True
                )
                
                print(f"✅ ONNX export complete: {onnx_path}")
                return onnx_path
                
            except Exception as e:
                print(f"Failed with shape {dummy_input.shape}: {e}")
                if i < len(dummy_inputs) - 1:
                    print("Trying next input shape...")
                    continue
                else:
                    raise
        
    except Exception as e:
        print(f"❌ Manual export failed: {e}")
        print("\n⚠️  Note: Parakeet models may require custom export logic.")
        print("You may need to:")
        print("1. Export encoder and decoder separately")
        print("2. Use NeMo's specific export methods")
        print("3. Check NeMo documentation for model-specific export")
        raise

if __name__ == "__main__":
    # Convert Parakeet models
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
            convert_to_onnx(model_name, output_dir)
        except Exception as e:
            print(f"\n❌ Failed to convert {model_name}: {e}")
            import traceback
            traceback.print_exc()
            print(f"\nContinuing with next model...\n")
