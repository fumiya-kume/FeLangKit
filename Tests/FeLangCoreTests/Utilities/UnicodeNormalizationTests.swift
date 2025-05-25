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
    }

    @Test("Instance Statistics Tracking - Japanese Characters")
    func testInstanceStatisticsTrackingJapanese() throws {
        var normalizer = UnicodeNormalizer()
        let testText = "こんにちは〜世界！−ゔ"
        
        let normalized = normalizer.normalize(testText)
        let stats = normalizer.getStats()
        
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

        let startTime = CFAbsoluteTimeGetCurrent()
        let normalized = UnicodeNormalizer.normalizeForFE(longText)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime

        #expect(!normalized.isEmpty, "Should handle long text")
        #expect(processingTime < 1.0, "Should process long text reasonably quickly")

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

    // MARK: - Performance Tests

    @Test("Normalization Performance")
    func testNormalizationPerformance() throws {
        let sampleTexts = [
            "変数 name = \"hello\"",
            "ＶＡＲ　ｎａｍｅ　＝　\"ｈｅｌｌｏ\"",
            "か\u{3099}き\u{3099}く\u{3099}け\u{3099}こ\u{3099}",
            String(repeating: "テストＴＥＳＴ", count: 100)
        ]

        for text in sampleTexts {
            let iterations = 1000
            let startTime = CFAbsoluteTimeGetCurrent()

            for _ in 0..<iterations {
                _ = UnicodeNormalizer.normalizeForFE(text)
            }

            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            let avgTime = totalTime / Double(iterations)

            #expect(avgTime < 0.001, "Normalization should be fast (< 1ms per operation)")
        }
    }
}
