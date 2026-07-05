import AVFoundation
import XCTest
@testable import speaktype

/// Covers WaveformView.peakSamples, the real-audio downsampling that replaced
/// the previous random-noise placeholder. Verifies it reflects the actual
/// signal (bucket count, 0...1 normalization, real peak detection) rather than
/// decorative values.
final class WaveformViewTests: XCTestCase {

    /// Writes a 1s, 16 kHz mono WAV whose first half is quiet (amp 0.2) and
    /// second half is loud (amp 0.9), so peak detection is observable.
    private func makeTwoLevelWAV() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("waveform-test-\(UUID().uuidString).wav")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames: AVAudioFrameCount = 16000
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let channel = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let amp: Float = i < 8000 ? 0.2 : 0.9
            channel[i] = amp * sinf(2 * .pi * 440 * Float(i) / 16000)
        }
        try file.write(from: buffer)
        return url
    }

    func testDownsamplesToRequestedBucketCount() throws {
        let url = try makeTwoLevelWAV()
        defer { try? FileManager.default.removeItem(at: url) }

        let peaks = WaveformView.peakSamples(from: url, bucketCount: 100)
        XCTAssertEqual(peaks.count, 100)
    }

    func testAllPeaksNormalizedToUnitRange() throws {
        let url = try makeTwoLevelWAV()
        defer { try? FileManager.default.removeItem(at: url) }

        let peaks = WaveformView.peakSamples(from: url, bucketCount: 100)
        XCTAssertFalse(peaks.isEmpty)
        for value in peaks {
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
        // Normalization means the loudest bucket reaches (approximately) 1.0.
        XCTAssertEqual(peaks.max() ?? 0, 1.0, accuracy: 0.01)
    }

    func testPeaksReflectRealLoudness() throws {
        let url = try makeTwoLevelWAV()
        defer { try? FileManager.default.removeItem(at: url) }

        let peaks = WaveformView.peakSamples(from: url, bucketCount: 100)
        XCTAssertEqual(peaks.count, 100)
        // First half quiet (~0.2), second half loud (~0.9): a mid-quiet bucket
        // must be clearly lower than a mid-loud bucket. Random noise (the old
        // placeholder) could not satisfy this.
        let quiet = peaks[25]
        let loud = peaks[75]
        XCTAssertLessThan(quiet, loud * 0.5, "quiet-half peak should be far below the loud half")
    }

    func testMissingFileReturnsEmpty() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).wav")
        XCTAssertTrue(WaveformView.peakSamples(from: missing, bucketCount: 100).isEmpty)
    }
}
