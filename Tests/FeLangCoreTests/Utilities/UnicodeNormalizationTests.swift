import Foundation
import Testing
@testable import FeLangCore

/// Comprehensive tests for Unicode normalization functionality
/// Tests Japanese character handling, full-width conversion, and combining characters
@Suite("Unicode Normalization Tests")
struct UnicodeNormalizationTests {

    private let normalizer = UnicodeNormalizer()

    // MARK: - Basic Normalization Tests

    @Test("Basic NFC Normalization")
    func testBasicNFCNormalization() throws {
        // Test combining character normalization (dakuten)
        let decomposed = "が" // が as separate characters (か + combining dakuten)
        let composed = "が"   // が as single composed character

        let normalizedDecomposed = UnicodeNormalizer.normalizeForFE(decomposed)
        let normalizedComposed = UnicodeNormalizer.normalizeForFE(composed)

        #expect(normalizedDecomposed == normalizedComposed, "NFC normalization should produce identical results")
        #expect(normalizer.areEquivalent(decomposed, composed), "Should recognize equivalent characters")
    }

    @Test("Full-width to Half-width Conversion")
    func testFullwidthToHalfwidthConversion() throws {
        let fullwidthText = "ＡＢＣ１２３！？"
        let expectedHalfwidth = "ABC123!?"

        let normalized = UnicodeNormalizer.normalizeForFE(fullwidthText)

        #expect(normalized == expectedHalfwidth, "Full-width ASCII should convert to half-width")
    }

    @Test("Mixed Full-width and Half-width Text")
    func testMixedFullwidthHalfwidthText() throws {
        let mixedText = "変数ＶＡＲ＝１２３"
        let expectedResult = "変数VAR=123"

        let normalized = UnicodeNormalizer.normalizeForFE(mixedText)

        #expect(normalized == expectedResult, "Should normalize only ASCII full-width characters")
    }

    // MARK: - Japanese Character Specific Tests

    @Test("Dakuten and Handakuten Normalization")
    func testDakutenHandakutenNormalization() throws {
        let testCases = [
            ("か\u{3099}", "が"), // か + combining dakuten → が
            ("は\u{309A}", "ぱ"), // は + combining handakuten → ぱ
            ("さ\u{3099}", "ざ"), // さ + combining dakuten → ざ
            ("う\u{3099}", "ヴ") // う + combining dakuten → ヴ
        ]

        for (decomposed, expectedComposed) in testCases {
            let normalized = UnicodeNormalizer.normalizeForFE(decomposed)
            #expect(normalized == expectedComposed, "Combining marks should be normalized to composed characters")
        }
    }

    @Test("Katakana vs Hiragana Consistency")
    func testKatakanaHiraganaConsistency() throws {
        let hiraganaText = "へろー"
        let katakanaText = "ヘロー"

        // Both should remain as-is (no automatic conversion)
        let normalizedHiragana = UnicodeNormalizer.normalizeForFE(hiraganaText)
        let normalizedKatakana = UnicodeNormalizer.normalizeForFE(katakanaText)

        #expect(normalizedHiragana == hiraganaText, "Hiragana should remain unchanged")
        #expect(normalizedKatakana == katakanaText, "Katakana should remain unchanged")
        #expect(normalizedHiragana != normalizedKatakana, "Hiragana and Katakana should remain distinct")
    }

    @Test("Japanese Punctuation Normalization")
    func testJapanesePunctuationNormalization() throws {
        let testCases = [
            ("～", "~"),   // Wave dash
            ("−", "-"),   // Minus sign
            ("―", "—")   // EM dash
        ]

        for (original, expected) in testCases {
            let normalized = UnicodeNormalizer.normalizeForFE(original)
            #expect(normalized == expected, "Japanese punctuation should be normalized")
        }
    }

    // MARK: - Complex Text Tests

    @Test("Complex Mixed Text Normalization")
    func testComplexMixedTextNormalization() throws {
        let complexText = "変数　ＶＡＲ＿１　＝　「こんにちは世界」＋１２３"
        let expectedResult = "変数　VAR_1　=　「こんにちは世界」+123"

        let normalized = UnicodeNormalizer.normalizeForFE(complexText)

        #expect(normalized == expectedResult, "Complex mixed text should be properly normalized")
    }

    @Test("Programming Keywords with Full-width Characters")
    func testProgrammingKeywordsNormalization() throws {
        let fullwidthKeywords = "ｉｆ　ｔｈｅｎ　ｅｌｓｅ　ｅｎｄｉｆ"
        let expectedResult = "if　then　else　endif"

        let normalized = UnicodeNormalizer.normalizeForFE(fullwidthKeywords)

        #expect(normalized == expectedResult, "Programming keywords should be normalized")
    }

    // MARK: - Statistics and Analysis Tests

    @Test("Normalization Statistics")
    func testNormalizationStatistics() throws {
        let testText = "ＶＡＲ＿１２３　か\u{3099}"
        let stats = normalizer.analyzeNormalization(testText)

        #expect(stats.hasChanges, "Should detect changes in the text")
        #expect(stats.fullwidthCharactersConverted > 0, "Should count full-width characters")
        #expect(stats.combiningCharactersNormalized > 0, "Should count combining characters")
        #expect(stats.originalLength >= stats.normalizedLength, "Normalized text should not be longer")
    }

    @Test("No Changes Statistics")
    func testNoChangesStatistics() throws {
        let plainText = "hello world 123"
        let stats = normalizer.analyzeNormalization(plainText)

        #expect(!stats.hasChanges, "Plain ASCII text should not require changes")
        #expect(stats.fullwidthCharactersConverted == 0, "No full-width characters to convert")
        #expect(stats.combiningCharactersNormalized == 0, "No combining characters to normalize")
        #expect(stats.originalLength == stats.normalizedLength, "Lengths should be equal")
    }

    // MARK: - Instance-based Statistics Tracking Tests

    @Test("Instance Statistics Tracking - Full-width Characters")
    func testInstanceStatisticsTrackingFullwidth() throws {
        var normalizer = UnicodeNormalizer()
        let testText = "ＡＢＣＤ１２３４"

        let normalized = normalizer.normalize(testText)
        let stats = normalizer.getStats()

        #expect(normalized == "ABCD1234", "Should normalize full-width characters")
        #expect(stats.originalLength == 8, "Should track original length")
        #expect(stats.normalizedLength == 8, "Should track normalized length")
        #expect(stats.fullwidthConversions == 8, "Should count 8 full-width conversions")
        #expect(stats.nfcNormalizations == 0, "Should count 0 NFC changes for this input")
        #expect(stats.japaneseNormalizations == 0, "Should count 0 Japanese normalizations")
        #expect(stats.emojiNormalizations == 0, "Should count 0 emoji normalizations")
        #expect(stats.mathSymbolNormalizations == 0, "Should count 0 math symbol normalizations")
        #expect(!stats.hasSecurityConcerns, "Should not have security concerns")
    }

    @Test("Instance Statistics Tracking - Japanese Characters")
    func testInstanceStatisticsTrackingJapanese() throws {
        var normalizer = UnicodeNormalizer()
        let testText = "こんにちは〜世界！−ゔ"

        let normalized = normalizer.normalize(testText)
        let stats = normalizer.getStats()

        #expect(normalized.contains("~"), "Should normalize wave dash")
        #expect(normalized.contains("-"), "Should normalize minus sign")
        #expect(normalized.contains("ヴ"), "Should normalize ゔ to ヴ")
        #expect(stats.japaneseNormalizations == 3, "Should count 3 Japanese normalizations: 〜, −, ゔ")
        #expect(stats.fullwidthConversions == 1, "Should count 1 full-width conversion: ！")
        #expect(stats.originalLength > 0, "Should track original length")
        #expect(stats.normalizedLength > 0, "Should track normalized length")
    }

    @Test("Instance Statistics Tracking - Mixed Content")
    func testInstanceStatisticsTrackingMixed() throws {
        var normalizer = UnicodeNormalizer()
        let testText = "ＮＡＭＥが〜１２３"

        let normalized = normalizer.normalize(testText)
        let stats = normalizer.getStats()

        #expect(normalized == "NAMEが~123", "Should properly normalize mixed content")
        #expect(stats.fullwidthConversions == 7, "Should count NAME123 conversions")
        #expect(stats.japaneseNormalizations == 1, "Should count wave dash normalization")
        #expect(stats.compressionRatio == 1.0, "Length should remain the same")
    }

    @Test("Statistics Reset Functionality")
    func testStatisticsResetFunctionality() throws {
        var normalizer = UnicodeNormalizer()

        // First normalization
        _ = normalizer.normalize("ＡＢＣＤ")
        let firstStats = normalizer.getStats()
        #expect(firstStats.fullwidthConversions == 4, "Should track first normalization")

        // Reset and normalize again
        normalizer.resetStats()
        _ = normalizer.normalize("１２３")
        let secondStats = normalizer.getStats()

        #expect(secondStats.fullwidthConversions == 3, "Should track only second normalization after reset")
        #expect(secondStats.originalLength == 3, "Should reset original length")
    }

    @Test("String Extension with Statistics")
    func testStringExtensionWithStatistics() throws {
        let testText = "ＨＥＬＬＯが〜"
        let (normalized, stats) = testText.normalizedForFEWithStats()

        #expect(normalized == "HELLOが~", "Should normalize correctly")
        #expect(stats.fullwidthConversions == 5, "Should count HELLO conversions")
        #expect(stats.japaneseNormalizations == 1, "Should count wave dash")
        #expect(stats.originalLength == 7, "Should track original length")
        #expect(stats.normalizedLength == 7, "Should track normalized length")
    }

    @Test("Statistics Accuracy - Complex Example")
    func testStatisticsAccuracyComplexExample() throws {
        var normalizer = UnicodeNormalizer()
        let complexText = "変数　ＮＡＭＥが　＝　\"ＨＥＬＬＯ〜！\"−１２３"

        let normalized = normalizer.normalize(complexText)
        let stats = normalizer.getStats()

        // Count expected changes:
        // Full-width: NAME + = + HELLO + ! + 123 = 4 + 1 + 5 + 1 + 3 = 14
        // Japanese: 〜 + − = 2
        #expect(stats.fullwidthConversions == 14, "Should count all full-width conversions accurately")
        #expect(stats.japaneseNormalizations == 2, "Should count Japanese normalizations accurately")

        // Verify the actual result
        #expect(normalized.contains("NAME"), "Should convert NAME")
        #expect(normalized.contains("HELLO"), "Should convert HELLO")
        #expect(normalized.contains("~"), "Should convert wave dash")
        #expect(normalized.contains("-"), "Should convert minus")
    }

    // MARK: - Edge Cases and Error Handling

    @Test("Empty String Normalization")
    func testEmptyStringNormalization() throws {
        let empty = ""
        let normalized = UnicodeNormalizer.normalizeForFE(empty)

        #expect(normalized == empty, "Empty string should remain empty")
        #expect(normalizer.areEquivalent(empty, normalized), "Empty strings should be equivalent")
    }

    @Test("Single Character Normalization")
    func testSingleCharacterNormalization() throws {
        let singleChar = "A"
        let fullwidthSingle = "Ａ"

        let normalizedRegular = UnicodeNormalizer.normalizeForFE(singleChar)
        let normalizedFullwidth = UnicodeNormalizer.normalizeForFE(fullwidthSingle)

        #expect(normalizedRegular == singleChar, "Regular character should remain unchanged")
        #expect(normalizedFullwidth == "A", "Full-width character should be converted")
        #expect(normalizer.areEquivalent(singleChar, fullwidthSingle), "Should recognize equivalence")
    }

    @Test("Very Long Text Normalization")
    func testVeryLongTextNormalization() throws {
        let longText = String(repeating: "変数　ＶＡＲ＿１２３　か\u{3099}　", count: 1000)

        let normalized = UnicodeNormalizer.normalizeForFE(longText)

        #expect(!normalized.isEmpty, "Should handle long text")

        let stats = normalizer.analyzeNormalization(longText)
        #expect(stats.hasChanges, "Should detect changes in repeated text")
    }

    // MARK: - Convenience Extension Tests

    @Test("String Extension Convenience Method")
    func testStringExtensionConvenience() throws {
        let testText = "ＨＥＬＬＯか\u{3099}"
        let normalizedDirect = UnicodeNormalizer.normalizeForFE(testText)
        let normalizedExtension = testText.normalizedForFE

        #expect(normalizedDirect == normalizedExtension, "Extension method should produce same result")
    }

    // MARK: - Real-world FE Language Examples

    @Test("FE Language Variable Declaration")
    func testFELanguageVariableDeclaration() throws {
        let feCode = "変数　ＮＡＭＥか\u{3099}　＝　\"ＨＥＬＬＯか\u{3099}\";"
        let expectedNormalized = "変数　NAMEが　=　\"HELLOが\";"

        let normalized = UnicodeNormalizer.normalizeForFE(feCode)

        #expect(normalized == expectedNormalized, "FE language code should be properly normalized")
    }

    @Test("FE Language Control Flow")
    func testFELanguageControlFlow() throws {
        let feCode = """
        ｉｆ　ｘ　＞　０　ｔｈｅｎ
            変数　ｒｅｓｕｌｔ　＝　\"成功か\u{3099}\"
        ｅｎｄｉｆ
        """

        let normalized = UnicodeNormalizer.normalizeForFE(feCode)

        #expect(normalized.contains("if"), "Keywords should be normalized")
        #expect(normalized.contains("then"), "Keywords should be normalized")
        #expect(normalized.contains("endif"), "Keywords should be normalized")
        #expect(normalized.contains("成功が"), "Japanese text should be normalized")
    }

    // MARK: - Enhanced Features Tests

    @Test("Normalization Forms - NFD Testing")
    func testNormalizationFormsNFD() throws {
        var normalizer = UnicodeNormalizer()

        // Test NFD (decomposition) - use explicit composed character
        let composedText = "caf\u{00E9}"  // é as single composed character (U+00E9)
        let result = normalizer.normalize(composedText, form: .nfd)

        // NFD should decompose é into e + combining acute
        // Note: grapheme cluster count stays the same, but Unicode scalar count increases
        let combiningAcute: UnicodeScalar = "\u{0301}"
        #expect(result.unicodeScalars.count > composedText.unicodeScalars.count, "NFD should decompose characters")
        #expect(result.unicodeScalars.contains(combiningAcute), "Should contain combining acute accent")
    }

    @Test("Normalization Forms - NFKC Testing")
    func testNormalizationFormsNFKC() throws {
        var normalizer = UnicodeNormalizer()

        // Test NFKC with compatibility characters
        let compatText = "ﬁle"  // fi ligature
        let result = normalizer.normalize(compatText, form: .nfkc)

        #expect(result == "file", "NFKC should decompose compatibility characters")
    }

    @Test("Normalization Forms - NFKD Testing")
    func testNormalizationFormsNFKD() throws {
        var normalizer = UnicodeNormalizer()

        // Test NFKD with compatibility and decomposition
        let compatText = "café" // with compatibility characters
        let result = normalizer.normalize(compatText, form: .nfkd)

        // Should apply both compatibility and canonical decomposition
        #expect(result.count >= compatText.count, "NFKD should decompose compatibility and canonical")
    }

    @Test("Character Classification System")
    func testCharacterClassificationSystem() throws {
        // Test letter classification
        let letterA: UnicodeScalar = "A"
        let classA = UnicodeNormalizer.classifyCharacter(letterA)
        if case .letter(let subcategory) = classA {
            #expect(subcategory == .uppercaseLetter, "A should be classified as uppercase letter")
        } else {
            #expect(Bool(false), "A should be classified as letter")
        }

        // Test number classification
        let digit5: UnicodeScalar = "5"
        let class5 = UnicodeNormalizer.classifyCharacter(digit5)
        if case .number(let subcategory) = class5 {
            #expect(subcategory == .decimalDigitNumber, "5 should be classified as decimal digit")
        } else {
            #expect(Bool(false), "5 should be classified as number")
        }

        // Test mathematical symbol
        let piSymbol: UnicodeScalar = "π"
        let classPi = UnicodeNormalizer.classifyCharacter(piSymbol)
        if case .symbol(let subcategory) = classPi {
            #expect(subcategory == .mathSymbol, "π should be classified as math symbol")
        } else {
            #expect(Bool(false), "π should be classified as symbol")
        }

        // Test punctuation
        let openParen: UnicodeScalar = "("
        let classParen = UnicodeNormalizer.classifyCharacter(openParen)
        if case .punctuation(let subcategory) = classParen {
            #expect(subcategory == .openPunctuation, "( should be classified as open punctuation")
        } else {
            #expect(Bool(false), "( should be classified as punctuation")
        }
    }

    @Test("Mathematical Symbol Normalization")
    func testMathematicalSymbolNormalization() throws {
        var normalizer = UnicodeNormalizer()

        let mathText = "π × α ÷ β ≈ ∞"
        let result = normalizer.normalize(mathText)
        let stats = normalizer.getStats()

        #expect(result.contains("pi"), "π should be normalized to pi")
        #expect(result.contains("*"), "× should be normalized to *")
        #expect(result.contains("alpha"), "α should be normalized to alpha")
        #expect(result.contains("÷"), "÷ should be preserved as a valid division operator")
        #expect(result.contains("beta"), "β should be normalized to beta")
        #expect(result.contains("~="), "≈ should be normalized to ~=")
        #expect(result.contains("infinity"), "∞ should be normalized to infinity")
        #expect(stats.mathSymbolNormalizations > 0, "Should count math symbol normalizations")
    }

    @Test("Emoji Normalization")
    func testEmojiNormalization() throws {
        var normalizer = UnicodeNormalizer()

        // Test emoji with variation selectors
        let emojiText = "😀\u{FE0F}👋\u{FE0E}"
        let result = normalizer.normalize(emojiText)
        let stats = normalizer.getStats()

        #expect(!result.contains("\u{FE0F}"), "Should remove emoji variation selector")
        #expect(!result.contains("\u{FE0E}"), "Should remove text variation selector")
        #expect(stats.emojiNormalizations > 0, "Should count emoji normalizations")
    }

    @Test("Security - Homoglyph Detection")
    func testSecurityHomoglyphDetection() throws {
        var normalizer = UnicodeNormalizer()

        // Test Cyrillic homoglyphs
        let homoglyphText = "асе"  // Cyrillic a, c, e that look like Latin
        let result = normalizer.normalize(homoglyphText)
        let stats = normalizer.getStats()

        #expect(result == "ace", "Should convert Cyrillic homoglyphs to Latin")
        #expect(stats.homoglyphsDetected > 0, "Should detect homoglyphs")
        #expect(stats.hasSecurityConcerns, "Should flag security concerns")
    }

    @Test("Security - Bidirectional Text Protection")
    func testSecurityBidirectionalTextProtection() throws {
        var normalizer = UnicodeNormalizer()

        // Test bidirectional override characters
        let bidiText = "normal\u{202E}dangerous\u{202C}text"
        let result = normalizer.normalize(bidiText)
        let stats = normalizer.getStats()

        #expect(!result.contains("\u{202E}"), "Should remove RLO override")
        #expect(!result.contains("\u{202C}"), "Should remove PDF character")
        #expect(result == "normaldangeroustext", "Should remove all bidi formatting")
        #expect(stats.bidiReorderings > 0, "Should count bidi issues")
        #expect(stats.hasSecurityConcerns, "Should flag security concerns")
    }

    @Test("Security Configuration")
    func testSecurityConfiguration() throws {
        // Test with strict security configuration
        let strictConfig = UnicodeNormalizer.SecurityConfig(
            enableHomoglyphDetection: true,
            preventNormalizationAttacks: true,
            maxNormalizedLength: 10,
            detectBidiReordering: true
        )

        var normalizer = UnicodeNormalizer(securityConfig: strictConfig)

        // Test length limit protection
        let longText = String(repeating: "a", count: 20)
        let result = normalizer.normalize(longText)
        let stats = normalizer.getStats()

        #expect(result == longText, "Should return original when over length limit")
        #expect(stats.securityIssuesFound > 0, "Should flag security issue")

        // Test with disabled features
        let lenientConfig = UnicodeNormalizer.SecurityConfig(
            enableHomoglyphDetection: false,
            preventNormalizationAttacks: false,
            maxNormalizedLength: 100000,
            detectBidiReordering: false
        )

        var lenientNormalizer = UnicodeNormalizer(securityConfig: lenientConfig)
        let homoglyphText = "асе"  // Cyrillic homoglyphs
        let lenientResult = lenientNormalizer.normalize(homoglyphText)
        let lenientStats = lenientNormalizer.getStats()

        #expect(lenientResult == homoglyphText, "Should not convert homoglyphs when detection is disabled")
        #expect(lenientStats.homoglyphsDetected == 0, "Should not detect homoglyphs when disabled")
        #expect(!lenientStats.hasSecurityConcerns, "Should not flag security concerns when disabled")
    }

    @Test("Extended Character Support - CJK Extension")
    func testExtendedCharacterSupportCJK() throws {
        // Test with CJK Extension B characters
        let cjkText = "𠀀𠀁𠀂"  // CJK Extension B characters
        let normalized = UnicodeNormalizer.normalizeForFE(cjkText)

        #expect(normalized == cjkText, "CJK Extension B characters should be preserved")
    }

    @Test("Extended Character Support - Private Use Area")
    func testExtendedCharacterSupportPrivateUse() throws {
        // Test with Private Use Area characters
        let privateUseText = "\u{E000}\u{E001}\u{E002}"
        let normalized = UnicodeNormalizer.normalizeForFE(privateUseText)

        #expect(normalized == privateUseText, "Private Use Area characters should be preserved")
    }

    @Test("Comprehensive Mixed Content Analysis")
    func testComprehensiveMixedContentAnalysis() throws {
        var normalizer = UnicodeNormalizer()

        // Complex text with multiple types of normalization needed
        let complexText = "Ｈｅｌｌｏ　π×α＝β！😀\u{FE0F}асе\u{202E}test"
        let result = normalizer.normalize(complexText)
        let stats = normalizer.getStats()

        // Verify all types of normalization occurred
        #expect(stats.fullwidthConversions > 0, "Should have full-width conversions")
        #expect(stats.mathSymbolNormalizations > 0, "Should have math symbol normalizations")
        #expect(stats.emojiNormalizations > 0, "Should have emoji normalizations")
        #expect(stats.homoglyphsDetected > 0, "Should detect homoglyphs")
        #expect(stats.bidiReorderings > 0, "Should detect bidi issues")
        #expect(stats.hasSecurityConcerns, "Should flag multiple security concerns")

        // Verify the result contains expected normalizations
        #expect(result.contains("Hello"), "Should normalize full-width characters")
        #expect(result.contains("pi"), "Should normalize π")
        #expect(result.contains("*"), "Should normalize ×")
        #expect(result.contains("alpha"), "Should normalize α")
        #expect(result.contains("ace"), "Should normalize Cyrillic homoglyphs")
        #expect(!result.contains("\u{202E}"), "Should remove bidi override")
    }

    @Test("Normalization Analysis Enhanced")
    func testNormalizationAnalysisEnhanced() throws {
        let normalizer = UnicodeNormalizer()

        let testText = "Ａπ😀\u{FE0F}асе\u{202E}"
        let analysis = normalizer.analyzeNormalization(testText)

        #expect(analysis.hasChanges, "Should detect changes")
        #expect(analysis.fullwidthCharactersConverted > 0, "Should count full-width characters")
        #expect(analysis.mathSymbolsNormalized > 0, "Should count math symbols")
        #expect(analysis.emojiCharactersNormalized > 0, "Should count emoji")
        #expect(analysis.homoglyphsDetected > 0, "Should count homoglyphs")
        #expect(analysis.bidiIssuesFound > 0, "Should count bidi issues")
        #expect(analysis.hasSecurityConcerns, "Should flag security concerns")

        let summary = analysis.summary
        #expect(summary.contains("full-width"), "Summary should mention full-width conversions")
        #expect(summary.contains("math symbol"), "Summary should mention math symbols")
        #expect(summary.contains("emoji"), "Summary should mention emoji")
        #expect(summary.contains("homoglyphs"), "Summary should mention homoglyphs")
        #expect(summary.contains("bidi"), "Summary should mention bidi issues")
    }

    @Test("String Extension Methods Enhanced")
    func testStringExtensionMethodsEnhanced() throws {
        // Use text with decomposable characters for NFC/NFD comparison
        let testTextWithAccent = "caf\u{00E9}"  // é as composed character

        // Test individual normalization methods - compare at Unicode scalar level
        let combiningAcute: UnicodeScalar = "\u{0301}"
        #expect(testTextWithAccent.normalizedNFC.unicodeScalars.count != testTextWithAccent.normalizedNFD.unicodeScalars.count, "NFC and NFD should have different scalar counts")
        #expect(testTextWithAccent.normalizedNFD.unicodeScalars.contains(combiningAcute), "NFD should contain combining marks")

        let testText = "Ｈｅｌｌｏ π"
        #expect(testText.normalizedNFKC.contains("Hello"), "NFKC should normalize full-width")
        #expect(testText.normalizedNFKD.contains("Hello"), "NFKD should normalize full-width")
        #expect(testText.normalizedFullwidth.contains("Hello"), "Should normalize full-width only")
        #expect(testText.normalizedMathSymbols.contains("pi"), "Should normalize math symbols")

        // Test with different forms and security configs
        let (normalized, stats) = testText.normalizedForFEWithStats(
            form: .nfkc,
            securityConfig: UnicodeNormalizer.SecurityConfig()
        )

        #expect(normalized.contains("Hello"), "Should normalize with specified form")
        #expect(stats.fullwidthConversions > 0, "Should track statistics")
    }

}
