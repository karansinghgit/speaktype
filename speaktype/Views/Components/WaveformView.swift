import AVFoundation
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
        .onChange(of: audioURL) {
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

    /// Downsample the actual audio into per-bucket peaks. Recordings are
    /// 16 kHz mono WAVs, so even a minutes-long file reads in a few ms; done
    /// off-main regardless. (This used to render random noise re-rolled on
    /// every appearance, which implied the bars meant something they didn't.)
    private func generateSamples() {
        guard let audioURL else {
            samples = []
            return
        }

        let bucketCount = 100
        DispatchQueue.global(qos: .userInitiated).async {
            let peaks = Self.peakSamples(from: audioURL, bucketCount: bucketCount)
            DispatchQueue.main.async {
                self.samples = peaks
            }
        }
    }

    private static func peakSamples(from url: URL, bucketCount: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                          frameCapacity: frameCount),
            (try? file.read(into: buffer)) != nil,
            let channel = buffer.floatChannelData?[0]
        else { return [] }

        let total = Int(buffer.frameLength)
        guard total > 0 else { return [] }

        let bucketSize = max(1, total / bucketCount)
        var peaks: [Float] = []
        peaks.reserveCapacity(bucketCount)

        var index = 0
        while index < total && peaks.count < bucketCount {
            var peak: Float = 0
            let end = min(index + bucketSize, total)
            while index < end {
                peak = max(peak, abs(channel[index]))
                index += 1
            }
            peaks.append(peak)
        }

        // Normalize so quiet recordings still draw a visible shape.
        if let maxPeak = peaks.max(), maxPeak > 0 {
            peaks = peaks.map { min(1.0, $0 / maxPeak) }
        }
        return peaks
    }
}
