import SwiftUI

/// Simple waveform visualization for audio playback
struct WaveformView: View {
    let audioURL: URL?
    @Binding var currentTime: TimeInterval
    @Binding var duration: TimeInterval
    
    @State private var samples: [Float] = []
    
    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background waveform (light blue)
                waveformPath(in: geometry.size, samples: samples)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                
                // Progress waveform (solid blue)
                waveformPath(in: geometry.size, samples: samples)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: geometry.size.width * progress)
                    .clipped()
            }
        }
        .frame(height: 60)
        .onAppear {
            generateSamples()
        }
        .onChange(of: audioURL) { _ in
            generateSamples()
        }
    }
    
    private func waveformPath(in size: CGSize, samples: [Float]) -> Path {
        guard !samples.isEmpty else { return Path() }
        
        var path = Path()
        let midY = size.height / 2
        let barWidth = size.width / CGFloat(samples.count)
        
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(sample) * midY
            
            // Draw vertical line from center
            path.move(to: CGPoint(x: x, y: midY - barHeight))
            path.addLine(to: CGPoint(x: x, y: midY + barHeight))
        }
        
        return path
    }
    
    private func generateSamples() {
        // Generate simple waveform samples
        // In production, this would analyze actual audio data
        // For now, generate random realistic-looking waveform
        let sampleCount = 100
        var newSamples: [Float] = []
        
        for i in 0..<sampleCount {
            // Create varied amplitude for realistic look
            let base = Float.random(in: 0.2...0.8)
            let variation = sin(Float(i) * 0.1) * 0.2
            newSamples.append(base + variation)
        }
        
        samples = newSamples
    }
}
