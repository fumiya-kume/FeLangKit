import XCTest
@testable import FeLangCore

/// Debug test to help diagnose Japanese keyword tokenization issues
final class JapaneseKeywordDebugTests: XCTestCase {

    func testJapaneseKeywordTokenization() throws {
        print("\n=== FeLang Japanese Keyword Tokenization Debug ===")

        // Test input with Japanese keywords
        let testInput = "変数 x : 整数型 ← 'hello'"
        print("Input: \(testInput)")

        let tokenizer = Tokenizer(input: testInput)
        let tokens = try tokenizer.tokenize()

        print("\nTokens found (\(tokens.count) total):")
        print("======================================")
        for (index, token) in tokens.enumerated() {
            let tokenTypeStr = String(describing: token.type)
            print("\(String(format: "%2d", index + 1)). \(tokenTypeStr.padding(toLength: 20, withPad: " ", startingAt: 0)) | '\(token.lexeme)' | \(token.position)")
        }

        print("\nAnalysis:")
        print("=========")

        // Check for variableKeyword
        let variableTokens = tokens.filter { $0.type == .variableKeyword }
        if variableTokens.isEmpty {
            print("❌ ERROR: No .variableKeyword tokens found!")
            print("   Expected '変数' to be tokenized as .variableKeyword")

            // Check if it was tokenized as identifier instead
            let identifierTokens = tokens.filter { $0.type == .identifier && $0.lexeme == "変数" }
            if !identifierTokens.isEmpty {
                print("❌ '変数' was incorrectly tokenized as .identifier")
                print("   This suggests the keyword lookup is not working properly")
            } else {
                print("ℹ️  '変数' was not found as any token - check Unicode normalization")
            }
        } else {
            print("✅ Found \(variableTokens.count) .variableKeyword token(s):")
            for token in variableTokens {
                print("   \(token)")
            }
        }

        // Check for integerType  
        let integerTypeTokens = tokens.filter { $0.type == .integerType }
        if integerTypeTokens.isEmpty {
            print("❌ ERROR: No .integerType tokens found!")
            print("   Expected '整数型' to be tokenized as .integerType")
        } else {
            print("✅ Found \(integerTypeTokens.count) .integerType token(s):")
            for token in integerTypeTokens {
                print("   \(token)")
            }
        }

        // Check for assignment operator
        let assignTokens = tokens.filter { $0.type == .assign }
        if assignTokens.isEmpty {
            print("❌ ERROR: No .assign tokens found!")
            print("   Expected '←' to be tokenized as .assign")
        } else {
            print("✅ Found \(assignTokens.count) .assign token(s):")
            for token in assignTokens {
                print("   \(token)")
            }
        }

        // Check for string literal
        let stringTokens = tokens.filter { $0.type == .stringLiteral }
        if stringTokens.isEmpty {
            print("❌ ERROR: No .stringLiteral tokens found!")
            print("   Expected ''hello'' to be tokenized as .stringLiteral")
        } else {
            print("✅ Found \(stringTokens.count) .stringLiteral token(s):")
            for token in stringTokens {
                print("   \(token)")
            }
        }

        print("\nKeyword Mapping Test:")
        print("====================")

        // Test the keyword mapping directly
        let keywordMap = TokenizerUtilities.keywordMap
        if let tokenType = keywordMap["変数"] {
            print("✅ '変数' maps to .\(tokenType) in keyword map")
        } else {
            print("❌ '変数' not found in keyword map!")
            print("   Available Japanese keywords:")
            for (key, value) in keywordMap.sorted(by: { $0.key < $1.key }) {
                if key.unicodeScalars.contains(where: { TokenizerUtilities.isJapaneseCharacter($0) }) {
                    print("     '\(key)' -> .\(value)")
                }
            }
        }

        if let tokenType = keywordMap["整数型"] {
            print("✅ '整数型' maps to .\(tokenType) in keyword map")
        } else {
            print("❌ '整数型' not found in keyword map!")
        }

        print("\nUnicode Analysis:")
        print("================")

        // Analyze Unicode scalars in the input
        print("Unicode scalars in '変数':")
        for (index, scalar) in "変数".unicodeScalars.enumerated() {
            print("  [\(index)] U+\(String(scalar.value, radix: 16, uppercase: true).padding(toLength: 4, withPad: "0", startingAt: 0)) '\(scalar)' (\(scalar.properties.name ?? "unnamed"))")
        }

        // Check Unicode normalization
        let normalized = UnicodeNormalizer.normalizeForFE("変数")
        print("\nAfter Unicode normalization: '\(normalized)'")
        if normalized != "変数" {
            print("⚠️  Unicode normalization changed the input!")
            print("   Original Unicode scalars:")
            for scalar in "変数".unicodeScalars {
                print("     U+\(String(scalar.value, radix: 16, uppercase: true))")
            }
            print("   Normalized Unicode scalars:")
            for scalar in normalized.unicodeScalars {
                print("     U+\(String(scalar.value, radix: 16, uppercase: true))")
            }
        } else {
            print("✅ Unicode normalization preserved the input")
        }

        // Additional assertions for proper test failure if debugging is needed
        XCTAssertTrue(!variableTokens.isEmpty, "'変数' should be tokenized as .variableKeyword")
        XCTAssertTrue(!integerTypeTokens.isEmpty, "'整数型' should be tokenized as .integerType")
        XCTAssertTrue(!assignTokens.isEmpty, "'←' should be tokenized as .assign")
        XCTAssertTrue(!stringTokens.isEmpty, "''hello'' should be tokenized as .stringLiteral")
    }

    func testIndividualJapaneseKeywords() throws {
        print("\n=== Individual Japanese Keyword Tests ===")

        let japaneseKeywords = [
            "変数": TokenType.variableKeyword,
            "定数": TokenType.constantKeyword,
            "整数型": TokenType.integerType,
            "実数型": TokenType.realType,
            "文字型": TokenType.characterType,
            "文字列型": TokenType.stringType,
            "論理型": TokenType.booleanType,
            "配列": TokenType.arrayType,
            "レコード": TokenType.recordType
        ]

        for (keyword, expectedType) in japaneseKeywords {
            print("\nTesting keyword: '\(keyword)'")

            let tokenizer = Tokenizer(input: keyword)
            let tokens = try tokenizer.tokenize()

            // Filter out EOF token
            let meaningfulTokens = tokens.filter { $0.type != .eof }

            XCTAssertEqual(meaningfulTokens.count, 1, "Should have exactly one meaningful token for '\(keyword)'")

            guard let token = meaningfulTokens.first else {
                XCTFail("No token found for '\(keyword)'")
                continue
            }

            if token.type == expectedType {
                print("✅ '\(keyword)' correctly tokenized as .\(expectedType)")
            } else {
                print("❌ '\(keyword)' incorrectly tokenized as .\(token.type), expected .\(expectedType)")
                XCTFail("'\(keyword)' should be tokenized as .\(expectedType), but got .\(token.type)")
            }

            XCTAssertEqual(token.lexeme, keyword, "Token lexeme should match input")
        }
    }
}
