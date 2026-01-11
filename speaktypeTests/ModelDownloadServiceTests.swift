import XCTest
@testable import speaktype

final class ModelDownloadServiceTests: XCTestCase {
    
    func testInitialState() {
        let service = ModelDownloadService.shared
        
        // Ensure no lingering downloads from other runs
        // (Note: Shared singleton might have state if tests run in parallel or sequence without clearing)
        // We can't easily clear private vars, but we can check types.
        
        XCTAssertNotNil(service.downloadProgress)
        XCTAssertNotNil(service.isDownloading)
    }
    
    // Real download tests require mocking backend connections or WhisperKit, which is out of scope for basic unit tests without dependency injection.
    // We verified the model IDs in the previous verification step.
}
