#!/usr/bin/env python3
"""
Convert ONNX model to CoreML format
"""
import coremltools as ct
import os
import sys

def convert_onnx_to_coreml(onnx_path: str, output_dir: str = "./models"):
    """Convert ONNX model to CoreML"""
    
    if not os.path.exists(onnx_path):
        raise FileNotFoundError(f"ONNX file not found: {onnx_path}")
    
    model_name = os.path.basename(onnx_path).replace('.onnx', '')
    coreml_path = os.path.join(output_dir, f"{model_name}.mlpackage")
    
    print(f"Converting {onnx_path} to CoreML...")
    print(f"Output: {coreml_path}")
    
    try:
        # Load and convert ONNX model
        # Note: You may need to adjust input/output shapes based on your model
        print("Loading ONNX model...")
        
        # Try to infer shapes from ONNX model
        import onnx
        onnx_model = onnx.load(onnx_path)
        
        # Get input/output info
        input_info = {}
        output_info = {}
        
        for input_tensor in onnx_model.graph.input:
            shape = [dim.dim_value if dim.dim_value > 0 else -1 for dim in input_tensor.type.tensor_type.shape.dim]
            input_info[input_tensor.name] = shape
            print(f"Input: {input_tensor.name}, shape: {shape}")
        
        for output_tensor in onnx_model.graph.output:
            shape = [dim.dim_value if dim.dim_value > 0 else -1 for dim in output_tensor.type.tensor_type.shape.dim]
            output_info[output_tensor.name] = shape
            print(f"Output: {output_tensor.name}, shape: {shape}")
        
        # Convert to CoreML
        print("Converting to CoreML...")
        
        # Create input specification
        # Adjust based on your model's actual input
        inputs = []
        for name, shape in input_info.items():
            # Handle dynamic dimensions
            if -1 in shape:
                # Use range dimensions for dynamic axes
                if len(shape) == 3:  # (batch, time, features)
                    inputs.append(
                        ct.TensorType(
                            name=name,
                            shape=(1, ct.RangeDim(lower_bound=1, upper_bound=3000), shape[2] if shape[2] > 0 else 80)
                        )
                    )
                else:
                    inputs.append(ct.TensorType(name=name, shape=tuple(s if s > 0 else 1 for s in shape)))
            else:
                inputs.append(ct.TensorType(name=name, shape=tuple(shape)))
        
        # Convert
        model = ct.convert(
            onnx_path,
            inputs=inputs if inputs else None,  # Let CoreML infer if empty
            minimum_deployment_target=ct.target.macOS13,
            compute_units=ct.ComputeUnit.ALL  # Use CPU, GPU, and Neural Engine
        )
        
        # Add metadata
        model.author = "SpeakType"
        model.short_description = f"Parakeet ASR Model: {model_name}"
        model.version = "1.0"
        
        # Save CoreML model
        print(f"Saving CoreML model to {coreml_path}...")
        model.save(coreml_path)
        
        print(f"✅ CoreML conversion complete: {coreml_path}")
        return coreml_path
        
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        import traceback
        traceback.print_exc()
        raise

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_onnx_to_coreml.py <onnx_file> [output_dir]")
        print("\nExample:")
        print("  python convert_onnx_to_coreml.py models/nvidia_parakeet_tdt_0_6b_v2.onnx")
        sys.exit(1)
    
    onnx_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "./models"
    
    os.makedirs(output_dir, exist_ok=True)
    
    try:
        convert_onnx_to_coreml(onnx_path, output_dir)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
