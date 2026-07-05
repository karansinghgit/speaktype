import XCTest
@testable import speaktype

/// Covers model→engine routing. The Parakeet cache-validation and
/// load-from-cache fixes this session depend on every catalog variant mapping
/// to the correct engine, and on the whisper/parakeet partition being total
/// and consistent.
final class AIModelEngineRoutingTests: XCTestCase {

    func testWhisperVariantsRouteToWhisper() {
        for variant in [
            "openai_whisper-large-v3_turbo", "openai_whisper-medium",
            "openai_whisper-small.en", "openai_whisper-base.en", "openai_whisper-tiny",
        ] {
            XCTAssertEqual(AIModel.engineKind(for: variant), .whisper, "\(variant) should be Whisper")
            XCTAssertEqual(AIModel.model(for: variant)?.engine, .whisper)
        }
    }

    func testParakeetCatalogVariantsRouteToParakeet() {
        for variant in ParakeetCatalog.variants {
            XCTAssertEqual(
                AIModel.engineKind(for: variant), .parakeet,
                "\(variant) should be Parakeet")
            XCTAssertEqual(AIModel.model(for: variant)?.engine, .parakeet)
        }
    }

    func testUnknownVariantHasNoEngineOrSize() {
        XCTAssertNil(AIModel.engineKind(for: "not-a-real-model"))
        XCTAssertNil(AIModel.model(for: "not-a-real-model"))
        XCTAssertNil(AIModel.expectedSize(for: "not-a-real-model"))
    }

    func testEveryAvailableModelIsSelfConsistent() {
        for model in AIModel.availableModels {
            XCTAssertEqual(
                AIModel.engineKind(for: model.variant), model.engine,
                "engineKind(for:) disagrees with the model's own engine for \(model.variant)")
            XCTAssertEqual(AIModel.model(for: model.variant)?.variant, model.variant)
            if let size = AIModel.expectedSize(for: model.variant) {
                XCTAssertGreaterThan(size, 0, "\(model.variant) expected size must be positive")
            }
        }
    }

    func testModelsForEnginePartitionIsTotalAndDisjoint() {
        let whisper = AIModel.models(for: .whisper)
        let parakeet = AIModel.models(for: .parakeet)
        XCTAssertFalse(whisper.isEmpty)
        XCTAssertFalse(parakeet.isEmpty)
        XCTAssertTrue(whisper.allSatisfy { $0.engine == .whisper })
        XCTAssertTrue(parakeet.allSatisfy { $0.engine == .parakeet })
        // The two engine buckets together account for every available model,
        // with no variant claimed by both.
        let whisperVariants = Set(whisper.map(\.variant))
        let parakeetVariants = Set(parakeet.map(\.variant))
        XCTAssertTrue(whisperVariants.isDisjoint(with: parakeetVariants))
        XCTAssertEqual(
            whisperVariants.union(parakeetVariants),
            Set(AIModel.availableModels.map(\.variant)))
    }
}
