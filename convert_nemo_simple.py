#!/usr/bin/env python3
"""
Simplified conversion using older PyTorch ONNX export API
This may work better for complex models
"""
import nemo.collections.asr as nemo_asr
import torch
import os
import sys

def convert_simple(model_name: str, output_dir: str = "./models"):
    """Convert using simpler ONNX export"""
    
    print(f"Loading NeMo model: {model_name}")
    model = nemo_asr.models.ASRModel.from_pretrained(model_name=model_name)
    model.eval()
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Try using the transcribe method's internal forward
    # Parakeet models have a transcribe method we can potentially trace
    print("Attempting simplified export...")
    
    # Create a wrapper that uses the model's transcribe path
    class ModelWrapper(torch.nn.Module):
        def __init__(self, nemo_model):
            super().__init__()
            self.model = nemo_model
            
        def forward(self, audio_features):
            # Try to use the encoder directly
            if hasattr(self.model, 'encoder'):
                return self.model.encoder(audio_features)
            return self.model(audio_features)
    
    wrapper = ModelWrapper(model)
    wrapper.eval()
    
    # Try different input shapes
    dummy_inputs = [
        torch.randn(1, 1000, 80),  # (batch, time, features)
    ]
    
    onnx_path = os.path.join(output_dir, f"{model_name.replace('/', '_').replace('-', '_')}.onnx")
    
    for dummy_input in dummy_inputs:
        try:
            print(f"Trying input shape: {dummy_input.shape}")
            
            # Use older export API with training=False
            torch.onnx.export(
                wrapper,
                dummy_input,
                onnx_path,
                input_names=['audio_features'],
                output_names=['output'],
                export_params=True,
                opset_version=11,  # Older opset for better compatibility
                do_constant_folding=True,
                input_names=['audio_features'],
                output_names=['output'],
                dynamic_axes={'audio_features': {1: 'time'}, 'output': {1: 'time'}},
                verbose=False
            )
            
            print(f"✅ ONNX export complete: {onnx_path}")
            return onnx_path
            
        except Exception as e:
            print(f"Failed: {e}")
            import traceback
            traceback.print_exc()
            continue
    
    raise Exception("All export attempts failed")

if __name__ == "__main__":
    models = ["nvidia/parakeet-tdt-0.6b-v2"]
    
    output_dir = "./models"
    os.makedirs(output_dir, exist_ok=True)
    
    for model_name in models:
        try:
            print(f"\n{'='*60}")
            print(f"Converting: {model_name}")
            print(f"{'='*60}\n")
            convert_simple(model_name, output_dir)
        except Exception as e:
            print(f"\n❌ Failed: {e}\n")
