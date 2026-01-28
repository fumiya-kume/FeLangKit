import Testing
@testable import FeLangCore

@Suite("ASCII Fast Path Tests")
struct ASCIIFastPathTests {

    // MARK: - Helper

    private func scalar(_ value: UInt32) -> UnicodeScalar {
        guard let scalar = UnicodeScalar(value) else {
            preconditionFailure("Invalid UnicodeScalar value: \(value)")
        }
        return scalar
    }

    // MARK: - isIdentifierStart Boundary Tests

    @Test func testIdentifierStartASCIILetterBoundaries() throws {
        // Upper boundary: A(0x41) to Z(0x5A)
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x40)) == false) // '@'
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x41)) == true)  // 'A'
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x5A)) == true)  // 'Z'
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x5B)) == false) // '['

        // Lower boundary: a(0x61) to z(0x7A)
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x60)) == false) // '`'
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x61)) == true)  // 'a'
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x7A)) == true)  // 'z'
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x7B)) == false) // '{'
    }

    @Test func testIdentifierStartUnderscore() throws {
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x5F)) == true) // '_'
    }

    @Test func testIdentifierStartASCIIDigitsRejected() throws {
        for value: UInt32 in 0x30...0x39 { // '0' to '9'
            #expect(
                TokenizerUtilities.isIdentifierStart(scalar(value)) == false,
                "Digit U+\(String(value, radix: 16)) should not start identifier"
            )
        }
    }

    @Test func testIdentifierStartASCIISymbolsRejected() throws {
        let symbols: [UnicodeScalar] = ["+", "-", "=", "@", "#", "$", "^", "&", " "]
        for symbol in symbols {
            #expect(
                TokenizerUtilities.isIdentifierStart(symbol) == false,
                "Symbol '\(symbol)' should not start identifier"
            )
        }
    }

    // MARK: - isIdentifierContinue Boundary Tests

    @Test func testIdentifierContinueASCIIDigitBoundaries() throws {
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x2F)) == false) // '/'
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x30)) == true)  // '0'
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x39)) == true)  // '9'
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x3A)) == false) // ':'
    }

    @Test func testIdentifierContinueIncludesLettersAndUnderscore() throws {
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x41)) == true) // 'A'
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x5A)) == true) // 'Z'
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x61)) == true) // 'a'
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x7A)) == true) // 'z'
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x5F)) == true) // '_'
    }

    // MARK: - Non-ASCII Fallthrough Tests

    @Test func testIdentifierStartNonASCIIFallthrough() throws {
        // Hiragana "あ" (U+3042) should be valid via Unicode classification
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x3042)) == true)
        // Katakana "ア" (U+30A2)
        #expect(TokenizerUtilities.isIdentifierStart(scalar(0x30A2)) == true)
    }

    @Test func testIdentifierContinueNonASCIICombiningMark() throws {
        // Combining grave accent (U+0300) should be valid as identifier continue
        // via mark(subcategory: .nonspacingMark)
        #expect(TokenizerUtilities.isIdentifierContinue(scalar(0x0300)) == true)
    }
}
