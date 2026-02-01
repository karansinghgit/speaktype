#!/usr/bin/env python3
"""
Robust Converter for NeMo Parakeet to ONNX
"""
import nemo.collections.asr as nemo_asr
import torch
import os
import sys

class ModelWrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
        
    def forward(self, audio_signal):
        # Parakeet/TDT models often expect specific kwargs or lengths
        # We wrap it to simplify the interface for ONNX export
        length = torch.tensor([audio_signal.shape[1]], device=audio_signal.device, dtype=torch.int32)
        # Some models expect audio_signal_length
        if hasattr(self.model, 'forward'):
            # Inspect signature? No, just try common patterns
            try:
                return self.model(audio_signal=audio_signal, audio_signal_length=length)
            except:
                pass
        return self.model(audio_signal)

def convert_to_onnx(model_name: str, output_dir: str = "./models"):
    print(f"Loading NeMo model: {model_name}")
    try:
        model = nemo_asr.models.ASRModel.from_pretrained(model_name=model_name)
        model.eval()
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return

    output_dir = os.path.abspath(output_dir)
    os.makedirs(output_dir, exist_ok=True)
    
    # Define simple filename
    safe_name = model_name.replace("/", "_").replace("-", "_")
    onnx_path = os.path.join(output_dir, f"{safe_name}.onnx")
    
    # Input params
    B, T, D = 1, 400, 80 # Batch, Time, Dim
    
    # 1. Try Encoder Export first (often safer for complex RNNT)
    # TDT models have 'encoder' and 'decoder'/'joint' usually
    if hasattr(model, 'encoder'):
        print("Attempting ENCODER export (safer)...")
        encoder = model.encoder
        encoder.eval()
        
        # Encoder input is usually audio_signal (B, D, T) or (B, T, D) depending on preprocessor
        # But wait, NeMo models usually take raw audio or features.
        # If we export 'model', it includes preprocessor.
        # If we export 'encoder', it expects processed attributes.
        
        # Let's keep it simple: Export the whole model but with correct args
        pass

    # 2. Export Full Model with safe wrapper
    print(f"Exporting full model to {onnx_path}...")
    
    # Wrap model to handle kwargs
    # wrapper = ModelWrapper(model)
    # wrapper.eval()
    
    # Create dummy input
    # Parakeet preprocessor usually takes (B, input_size) raw audio?
    # Or if we bypass preprocessor, it takes (B, D, T) features.
    
    # Let's check if the model has a preprocessor
    # If we want end-to-end, we should feed it features (CoreML handles audio buffer -> features usually? or we do it in Swift)
    # The user guide says: "Input: Audio features (mel spectrogram, MFCC, etc.)"
    # So we should be bypassing the preprocessor and feeding features into the encoder/model.
    
    device = next(model.parameters()).device
    dummy_input = torch.randn(1, 80, 200, device=device) # (B, D, T) - NeMo usually (B, D, T) for Conformer/FastConformer
    
    # However, Parakeet might be (B, T, D)
    # Let's verify input with a dry run
    print("Verifying input shape compatibility...")
    try:
        # Create a dummy inputs
        audio_signal = torch.randn(1, 80, 200, device=device)
        length = torch.tensor([200], device=device, dtype=torch.int32)
        
        # Try encoder forward
        if hasattr(model, 'encoder'):
            res = model.encoder(audio_signal=audio_signal, length=length)
            print("Encoder accepts (B, D, T)")
    except Exception as e:
        print(f"Encoder input test failed: {e}")
        # Try transpose
        try:
            audio_signal = torch.randn(1, 200, 80, device=device)
            # res = model.encoder(audio_signal=audio_signal, length=length)
            # print("Encoder accepts (B, T, D)")
            # Update dummy_input
            dummy_input = audio_signal
        except:
            pass

    # Torch ONNX Export
    try:
        # Use simpler opset
        opset = 14
        
        # Ensure we pass arguments as the forward method expects
        # We can use 'args' tuple
        
        # Most NeMo enc takes: audio_signal, length
        # length is important!
        
        audio_signal = torch.randn(1, 80, 200, device=device)
        length = torch.tensor([200], device=device, dtype=torch.int32)
        
        torch.onnx.export(
            model.encoder, # Exporting encoder is usually what we want for ASR unless it's E2E
            (audio_signal, length),
            onnx_path,
            input_names=['audio_signal', 'length'],
            output_names=['outputs', 'encoded_lengths'],
            dynamic_axes={
                'audio_signal': {0: 'batch', 2: 'time'},
                'length': {0: 'batch'},
                'outputs': {0: 'batch', 2: 'time_out'}
            },
            opset_version=opset
        )
        print(f"✅ Exported ENCODER to {onnx_path}")
        return
        
    except Exception as e:
        print(f"❌ Export failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        convert_to_onnx(sys.argv[1])
    else:
        convert_to_onnx("nvidia/parakeet-tdt-0.6b-v3")
