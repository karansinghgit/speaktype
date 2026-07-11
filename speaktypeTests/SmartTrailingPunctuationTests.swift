import XCTest

@testable import speaktype

final class SmartTrailingPunctuationTests: XCTestCase {

    // MARK: - Shapes that lose the trailing period

    func testStripsPeriodAfterEmail() {
        XCTAssertEqual(
            SmartTrailingPunctuation.strip("roy.sanhik@gmail.com."),
            "roy.sanhik@gmail.com")
    }

    func testStripsPeriodAfterURLWithScheme() {
        XCTAssertEqual(
            SmartTrailingPunctuation.strip("https://example.com/pricing."),
            "https://example.com/pricing")
    }

    func testStripsPeriodAfterWWWURL() {
        XCTAssertEqual(
            SmartTrailingPunctuation.strip("www.example.com."), "www.example.com")
    }

    func testStripsPeriodAfterBareDomain() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("example.com."), "example.com")
    }

    func testStripsPeriodAfterDomainWithPath() {
        XCTAssertEqual(
            SmartTrailingPunctuation.strip("example.com/docs/setup."),
            "example.com/docs/setup")
    }

    func testStripsPeriodAfterDecimalNumber() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("3.14."), "3.14")
    }

    func testStripsPeriodAfterThousandsNumber() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("1,000."), "1,000")
    }

    func testStripsPeriodAfterVersionNumber() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("1.2.3."), "1.2.3")
    }

    func testStripsPeriodAfterPhoneNumberWithSpaces() {
        XCTAssertEqual(
            SmartTrailingPunctuation.strip("+49 170 1234567."), "+49 170 1234567")
    }

    func testStripsPeriodAfterFormattedPhoneNumber() {
        XCTAssertEqual(
            SmartTrailingPunctuation.strip("(555) 123-4567."), "(555) 123-4567")
    }

    func testStripsPeriodAfterSingleDigit() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("5."), "5")
    }

    func testStripsPeriodAfterSingleWord() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("Hello."), "Hello")
    }

    func testStripsPeriodAfterAlphanumericToken() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("ABC123."), "ABC123")
    }

    func testStripsPeriodAfterCurrencyToken() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("€1,000."), "€1,000")
    }

    func testStripsSurroundingWhitespaceWhenStripping() {
        XCTAssertEqual(
            SmartTrailingPunctuation.strip(" roy.sanhik@gmail.com. "),
            "roy.sanhik@gmail.com")
    }

    // MARK: - Shapes that keep their punctuation

    func testKeepsPeriodOnSentence() {
        let sentence = "This is a normal sentence."
        XCTAssertEqual(SmartTrailingPunctuation.strip(sentence), sentence)
    }

    func testKeepsPeriodOnSentenceEndingWithEmail() {
        let sentence = "Email me at roy@gmail.com."
        XCTAssertEqual(SmartTrailingPunctuation.strip(sentence), sentence)
    }

    func testKeepsEllipsis() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("Wait..."), "Wait...")
    }

    func testKeepsUnicodeEllipsis() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("Wait…"), "Wait…")
    }

    func testKeepsDottedAbbreviation() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("U.S."), "U.S.")
    }

    func testKeepsQuestionAndExclamation() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("Really?"), "Really?")
        XCTAssertEqual(SmartTrailingPunctuation.strip("Stop!"), "Stop!")
    }

    func testKeepsLonePeriod() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("."), ".")
    }

    func testKeepsEmptyString() {
        XCTAssertEqual(SmartTrailingPunctuation.strip(""), "")
    }

    func testKeepsTokenWithoutTrailingPeriod() {
        XCTAssertEqual(SmartTrailingPunctuation.strip("roy@gmail.com"), "roy@gmail.com")
    }

    // MARK: - Toggle behavior

    func testApplyDefaultsToEnabledWhenKeyIsAbsent() {
        withDefaultsValue(nil) {
            XCTAssertTrue(SmartTrailingPunctuation.isEnabled)
            XCTAssertEqual(SmartTrailingPunctuation.apply(to: "Hello."), "Hello")
        }
    }

    func testApplyIsANoOpWhenDisabled() {
        withDefaultsValue(false) {
            XCTAssertEqual(SmartTrailingPunctuation.apply(to: "Hello."), "Hello.")
        }
    }

    func testApplyStripsWhenExplicitlyEnabled() {
        withDefaultsValue(true) {
            XCTAssertEqual(
                SmartTrailingPunctuation.apply(to: "example.com."), "example.com")
        }
    }

    /// Run `body` with the toggle key set to `value` (nil removes it),
    /// restoring whatever was stored before.
    private func withDefaultsValue(_ value: Bool?, body: () -> Void) {
        let defaults = UserDefaults.standard
        let key = SmartTrailingPunctuation.defaultsKey
        let previous = defaults.object(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        body()
    }
}
