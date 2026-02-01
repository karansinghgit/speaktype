import Foundation
import PythonKit

@Observable
class NeMoService {
    var isInitialized = false
    var currentModelName: String?
    
    private var python: PythonObject?
    private var model: PythonObject?
    private var asr_model_class: PythonObject?
    
    init() {
        Task {
            do {
                try await setupPythonEnvironment()
            } catch {
                print("NeMoService: Failed to setup Python environment: \(error)")
            }
        }
    }
    
    func checkPythonAvailability() -> Bool {
        do {
            let sys = try Python.attemptImport("sys")
            print("Python version: \(sys.version)")
            return true
        } catch {
            print("Python not available: \(error)")
            return false
        }
    }
    
    private func setupPythonEnvironment() async throws {
        print("NeMoService: Setting up Python environment...")
        
        // Fix for "Python library not found" on some macOS setups
        // We attempt to direct PythonKit to the venv python library if possible,
        // but traditionally PythonKit relies on system python or discovery.
        // Explicitly adding the site-packages from the venv is the key.
        
        let sys = try Python.attemptImport("sys")
        let _ = try Python.attemptImport("os")
        
        print("NeMoService: System Python: \(sys.executable)")
        
        // Add ~/.nemo_env/lib/python3.x/site-packages to path
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        
        // Try multiple python versions that might be in the venv
        let possibleVersions = ["python3.8", "python3.9", "python3.10", "python3.11", "python3.12"]
        var sitePackagesAdded = false
        
        for version in possibleVersions {
            let sitePackages = "\(homeDir)/.nemo_env/lib/\(version)/site-packages"
            if fileManager.fileExists(atPath: sitePackages) {
                print("NeMoService: Found site-packages at \(sitePackages)")
                sys.path.insert(0, sitePackages)
                sitePackagesAdded = true
                break // Found one, assume it's the right one
            }
        }
        
        if !sitePackagesAdded {
             print("NeMoService: ⚠️ Could not find .nemo_env site-packages. NeMo import might fail.")
        }
        
        // Try importing NeMo
        do {
            let nemo_asr = try Python.attemptImport("nemo.collections.asr")
            self.asr_model_class = nemo_asr.models.ASRModel
            self.python = nemo_asr
            print("NeMoService: NeMo module imported successfully")
        } catch {
            print("NeMoService: Failed to import nemo.collections.asr: \(error)")
            throw error
        }
    }
    
    func loadModel(variant: String) async throws {
        guard let asr_model_class = self.asr_model_class else {
            // Try setup again if not ready
            try await setupPythonEnvironment()
            if self.asr_model_class == nil {
                throw NSError(domain: "NeMoService", code: 1, userInfo: [NSLocalizedDescriptionKey: "NeMo toolkit not initialized"])
            }
            return
        }
        
        if isInitialized && variant == currentModelName && model != nil {
            return
        }
        
        print("NeMoService: Loading model \(variant)...")
        isInitialized = false
        
        // Loading can be slow, wrap in Task/Detached if blocking UI, 
        // but PythonKit calls are synchronous on the calling thread.
        // We really should offload this to a background thread if possible, 
        // but Python Global Interpreter Lock (GIL) and Thread State might make that tricky w/ PythonKit.
        // Usually, running on a Task { ... } works fine.
        
        do {
            // from_pretrained downloads or loads from cache
            let loadedModel = asr_model_class.from_pretrained(model_name: variant)
            
            // Move to CPU or MPS? NeMo defaults to CUDA if avail, or CPU.
            // On Mac, we might want map_location="cpu" or device handling.
            // loadedModel = loadedModel.to("cpu") // explicit cpu
            
            self.model = loadedModel
            self.currentModelName = variant
            self.isInitialized = true
            print("NeMoService: Model \(variant) loaded.")
    }
    }
    
    func transcribe(audioFile: URL) async throws -> String {
        guard let model = model, isInitialized else {
            throw NSError(domain: "NeMoService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Model not initialized"])
        }
        
        print("NeMoService: Transcribing \(audioFile.path)...")
        
            // NeMo transcribe expects a list of paths
            let paths = [audioFile.path]
            
            // transcribe() returns a list of strings
            // signature: model.transcribe(paths2audio_files=..., batch_size=..., ...)
            // PythonKit handles named args via string keys or dynamic lookup
            
            // Note: NeMo's transcribe method might differ by model type (EncDecRNNTModel vs EncDecCTCModel)
            // But most have transcribe(paths2audio_files=...)
            
            // Dynamic call:
            let results = model.transcribe(paths2audio_files: paths, batch_size: 1)
            
            // Results is a list of strings
            if let text = String(results[0]) {
                print("NeMoService: Transcription: \(text)")
                return text
            } else {
                 return ""
            }
    }
    
    static func isParakeetModel(_ variant: String) -> Bool {
        return variant.lowercased().contains("parakeet") || variant.lowercased().contains("nemo")
    }
}
