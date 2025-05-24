import Foundation
import Testing
@testable import FeLangCore

/// Performance tests for keyword search optimization
/// Validates that the O(1) hash map lookup provides significant performance improvements
/// over linear search approaches, especially for large source files.
@Suite("Keyword Performance Tests")
struct KeywordPerformanceTests {

    // MARK: - Keyword Lookup Performance Tests

    @Test("Hash Map Keyword Lookup Performance")
    func testKeywordMapPerformance() throws {
        // Prepare test data with all keywords
        let allKeywords = TokenizerUtilities.keywords.map { $0.0 }
        let keywordMap = TokenizerUtilities.keywordMap
        let iterations = 10_000

        // Measure hash map lookup performance (O(1) expected)
        let hashMapStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            for keyword in allKeywords {
                _ = keywordMap[keyword] // O(1) lookup
            }
        }
        let hashMapTime = CFAbsoluteTimeGetCurrent() - hashMapStart

        // Simulate linear search performance (O(n) baseline)
        let linearStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            for keyword in allKeywords {
                // Simulate linear search through keywords array
                _ = TokenizerUtilities.keywords.first { $0.0 == keyword }?.1
            }
        }
        let linearTime = CFAbsoluteTimeGetCurrent() - linearStart

        // Hash map should be significantly faster
        let performanceRatio = linearTime / hashMapTime
        
        print("=== Keyword Lookup Performance Results ===")
        print("Hash Map Time: \(String(format: "%.6f", hashMapTime)) seconds")
        print("Linear Search Time: \(String(format: "%.6f", linearTime)) seconds")
        print("Performance Improvement: \(String(format: "%.1f", performanceRatio))x faster")
        print("Keywords tested: \(allKeywords.count)")
        print("Total lookups: \(allKeywords.count * iterations)")

        // Verify hash map is at least 2x faster (conservative expectation)
        #expect(performanceRatio >= 2.0, "Hash map should be at least 2x faster than linear search")

        // Verify hash map provides correct results
        for keyword in allKeywords {
            let hashMapResult = keywordMap[keyword]
            let linearResult = TokenizerUtilities.keywords.first { $0.0 == keyword }?.1
            #expect(hashMapResult == linearResult, "Hash map and linear search should return same results")
        }
    }

    // MARK: - Large Source File Performance Tests

    @Test("Large Source File Tokenization Performance")
    func testLargeFileTokenizationPerformance() throws {
        // Generate a large source file with many keywords
        let sourceLines = generateLargeSourceFile(lineCount: 1000)
        let largeSource = sourceLines.joined(separator: "\n")
        
        // Count expected keyword occurrences
        let expectedKeywordCount = countKeywordOccurrences(in: largeSource)
        
        print("=== Large File Tokenization Performance ===")
        print("Source file size: \(largeSource.count) characters")
        print("Lines: \(sourceLines.count)")
        print("Expected keyword tokens: \(expectedKeywordCount)")

        // Test Tokenizer performance
        let tokenizerStart = CFAbsoluteTimeGetCurrent()
        let tokenizer = Tokenizer(input: largeSource)
        let tokenizerTokens = try tokenizer.tokenize()
        let tokenizerTime = CFAbsoluteTimeGetCurrent() - tokenizerStart

        // Test ParsingTokenizer performance
        let parsingStart = CFAbsoluteTimeGetCurrent()
        let parsingTokens = try ParsingTokenizer.tokenize(largeSource)
        let parsingTime = CFAbsoluteTimeGetCurrent() - parsingStart

        print("Tokenizer time: \(String(format: "%.6f", tokenizerTime)) seconds")
        print("ParsingTokenizer time: \(String(format: "%.6f", parsingTime)) seconds")
        print("Tokenizer tokens: \(tokenizerTokens.count)")
        print("ParsingTokenizer tokens: \(parsingTokens.count)")

        // Note: Token counts may differ due to different whitespace/newline handling
        // This is expected behavior - focus on keyword performance verification
        
        // Verify keyword detection is working
        let tokenizerKeywords = tokenizerTokens.filter { $0.type.isKeyword }
        let parsingKeywords = parsingTokens.filter { $0.type.isKeyword }
        
        print("Tokenizer keywords found: \(tokenizerKeywords.count)")
        print("ParsingTokenizer keywords found: \(parsingKeywords.count)")
        
        #expect(tokenizerKeywords.count == parsingKeywords.count, "Both tokenizers should find same keyword count")
        #expect(tokenizerKeywords.count >= expectedKeywordCount, "Should find at least expected keyword count")

        // Performance should be reasonable for Tokenizer (optimized for speed)
        #expect(tokenizerTime < 1.0, "Tokenizer should process large file in reasonable time")
        
        // ParsingTokenizer may be slower due to different architecture (comment-based design)
        // Focus on keyword detection accuracy rather than absolute speed
        #expect(parsingTime < 10.0, "ParsingTokenizer should complete within reasonable time")
    }

    @Test("Keyword Boundary Performance")
    func testKeywordBoundaryPerformance() throws {
        // Test performance with keywords that have many potential partial matches
        let problematicInput = generateProblematicKeywordInput()
        
        print("=== Keyword Boundary Performance ===")
        print("Input size: \(problematicInput.count) characters")

        let start = CFAbsoluteTimeGetCurrent()
        let tokenizer = Tokenizer(input: problematicInput)
        let tokens = try tokenizer.tokenize()
        let time = CFAbsoluteTimeGetCurrent() - start

        print("Processing time: \(String(format: "%.6f", time)) seconds")
        print("Tokens produced: \(tokens.count)")

        // Should handle boundary cases efficiently
        #expect(time < 0.1, "Should handle keyword boundary cases efficiently")
        
        // Verify correct tokenization of boundary cases
        let keywords = tokens.filter { $0.type.isKeyword }
        let identifiers = tokens.filter { $0.type == .identifier }
        
        print("Keywords found: \(keywords.count)")
        print("Identifiers found: \(identifiers.count)")
        
        #expect(keywords.count > 0, "Should find some keywords")
        #expect(identifiers.count > 0, "Should find some identifiers with keyword prefixes/suffixes")
    }

    // MARK: - Memory Performance Tests

    @Test("Memory Usage Efficiency")
    func testMemoryUsageEfficiency() throws {
        // Test that the keyword map doesn't consume excessive memory
        let keywordMap = TokenizerUtilities.keywordMap
        let keywordArray = TokenizerUtilities.keywords
        
        print("=== Memory Usage Analysis ===")
        print("Keyword map entries: \(keywordMap.count)")
        print("Keyword array entries: \(keywordArray.count)")
        
        // Both should have same number of entries
        #expect(keywordMap.count == keywordArray.count, "Map and array should have same keyword count")
        
        // All keywords should be in the map
        for (keyword, expectedType) in keywordArray {
            #expect(keywordMap[keyword] == expectedType, "Map should contain all keywords from array")
        }
        
        // Map should not contain extra entries
        for (keyword, _) in keywordMap {
            let arrayContains = keywordArray.contains { $0.0 == keyword }
            #expect(arrayContains, "Map should not contain keywords not in array")
        }
    }

    // MARK: - Helper Methods

    /// Generates a large source file with realistic keyword distribution
    private func generateLargeSourceFile(lineCount: Int) -> [String] {
        let keywords = ["if", "while", "for", "整数型", "実数型", "return", "break", "true", "false"]
        let identifiers = ["variable", "counter", "result", "data", "value", "index", "temp"]
        let operators = ["←", "+", "-", "*", "/", "=", ">", "<"]
        let delimiters = ["(", ")", "[", "]", "{", "}", ",", ".", ":", ";"]
        
        var lines: [String] = []
        
        for lineNum in 0..<lineCount {
            var line = ""
            let tokensPerLine = Int.random(in: 3...10)
            
            for _ in 0..<tokensPerLine {
                let tokenType = Int.random(in: 0...3)
                switch tokenType {
                case 0: // Keyword
                    line += keywords.randomElement() ?? "if"
                case 1: // Identifier
                    line += "\(identifiers.randomElement() ?? "var")\(lineNum % 100)"
                case 2: // Operator
                    line += operators.randomElement() ?? "+"
                case 3: // Delimiter
                    line += delimiters.randomElement() ?? ","
                default:
                    line += "token"
                }
                line += " "
            }
            
            lines.append(line.trimmingCharacters(in: .whitespaces))
        }
        
        return lines
    }

    /// Counts expected keyword occurrences in source text
    private func countKeywordOccurrences(in source: String) -> Int {
        let keywordStrings = TokenizerUtilities.keywords.map { $0.0 }
        var count = 0
        
        // Simple approximation - count occurrences as separate words
        let words = source.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            if keywordStrings.contains(word) {
                count += 1
            }
        }
        
        return count
    }

    /// Generates input with many keyword-like identifiers to test boundary detection
    private func generateProblematicKeywordInput() -> String {
        let keywords = ["if", "while", "for", "return"]
        var problematicTokens: [String] = []
        
        // Add exact keywords
        problematicTokens.append(contentsOf: keywords)
        
        // Add identifiers with keyword prefixes
        for keyword in keywords {
            problematicTokens.append("\(keyword)Variable")
            problematicTokens.append("\(keyword)_test")
            problematicTokens.append("\(keyword)123")
        }
        
        // Add identifiers with keyword suffixes  
        for keyword in keywords {
            problematicTokens.append("my\(keyword.capitalized)")
            problematicTokens.append("test_\(keyword)")
        }
        
        // Add identifiers containing keywords
        for keyword in keywords {
            problematicTokens.append("pre\(keyword)post")
        }
        
        return problematicTokens.joined(separator: " ")
    }
} 