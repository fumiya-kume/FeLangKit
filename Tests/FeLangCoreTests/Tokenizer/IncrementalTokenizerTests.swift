import Testing
@testable import FeLangCore
import Foundation

@Suite("Incremental Tokenizer Tests")
struct IncrementalTokenizerTests {

    @Test("Basic incremental update")
    func testBasicIncrementalUpdate() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "変数 x: 整数型\nx ← 42"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Insert text at the beginning
        let insertionRange = originalText.startIndex..<originalText.startIndex
        let newText = "// コメント\n"

        let result = try incrementalTokenizer.updateTokens(
            in: insertionRange,
            with: newText,
            previousTokens: originalTokens,
            originalText: originalText
        )

        #expect(result.tokens.count > originalTokens.count, "Should have more tokens after insertion")
        #expect(result.metrics.tokensAdded > 0, "Should track added tokens")
        #expect(result.metrics.reparsedCharacters > 0, "Should track reparsed characters")
    }

    @Test("Text replacement")
    func testTextReplacement() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "変数 oldName: 整数型"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Replace "oldName" with "newName"
        let startIndex = originalText.range(of: "oldName")!.lowerBound
        let endIndex = originalText.range(of: "oldName")!.upperBound
        let replacementRange = startIndex..<endIndex

        let result = try incrementalTokenizer.updateTokens(
            in: replacementRange,
            with: "newName",
            previousTokens: originalTokens,
            originalText: originalText
        )

        #expect(result.tokens.count == originalTokens.count, "Should have same number of tokens")

        // Check that the identifier was updated
        let identifiers = result.tokens.filter { $0.type == .identifier }
        #expect(identifiers.contains { $0.lexeme == "newName" }, "Should contain new identifier")
        #expect(!identifiers.contains { $0.lexeme == "oldName" }, "Should not contain old identifier")
    }

    @Test("Text deletion")
    func testTextDeletion() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "変数 x: 整数型\n変数 y: 整数型"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Delete the second line
        let deletionStart = originalText.range(of: "\n変数 y: 整数型")!.lowerBound
        let deletionEnd = originalText.endIndex
        let deletionRange = deletionStart..<deletionEnd

        let result = try incrementalTokenizer.updateTokens(
            in: deletionRange,
            with: "",
            previousTokens: originalTokens,
            originalText: originalText
        )

        #expect(result.tokens.count < originalTokens.count, "Should have fewer tokens after deletion")
        #expect(result.metrics.tokensRemoved > 0, "Should track removed tokens")

        // Verify that tokens related to 'y' are gone
        let identifiers = result.tokens.filter { $0.type == .identifier }
        #expect(!identifiers.contains { $0.lexeme == "y" }, "Should not contain deleted identifier")
    }

    @Test("Position adjustment after insertion")
    func testPositionAdjustmentAfterInsertion() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "x ← 42\ny ← 24"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Insert text at the beginning
        let insertionRange = originalText.startIndex..<originalText.startIndex
        let insertedText = "// Comment\n"

        let result = try incrementalTokenizer.updateTokens(
            in: insertionRange,
            with: insertedText,
            previousTokens: originalTokens,
            originalText: originalText
        )

        // Find tokens that should have moved down
        let yTokens = result.tokens.filter { $0.lexeme == "y" }
        #expect(!yTokens.isEmpty, "Should find y tokens")

        // The y token should be on line 3 now (original line 2 + 1 inserted line)
        if let yToken = yTokens.first {
            #expect(yToken.position.line >= 3, "Token position should be adjusted")
        }
    }

    @Test("Incremental validation")
    func testIncrementalValidation() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "変数 x: 整数型 ← 100"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Replace the number
        let numberRange = originalText.range(of: "100")!
        let result = try incrementalTokenizer.updateTokens(
            in: numberRange,
            with: "200",
            previousTokens: originalTokens,
            originalText: originalText
        )

        let newFullText = originalText.replacingCharacters(in: numberRange, with: "200")
        let validation = try incrementalTokenizer.validateIncremental(
            result: result,
            fullText: newFullText
        )

        #expect(validation.isValid, "Incremental result should be valid")
        #expect(validation.tokenCountMatch, "Token counts should match")
        #expect(validation.typeMismatches == 0, "Should have no type mismatches")
        #expect(validation.positionMismatches == 0, "Should have no position mismatches")
    }

    @Test("Complex multi-line edit")
    func testComplexMultiLineEdit() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = """
        変数 x: 整数型
        if x > 0 then
            print(x)
        endif
        """

        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Insert a new variable declaration in the middle
        let insertionPoint = originalText.range(of: "if x > 0 then")!.lowerBound
        let insertionRange = insertionPoint..<insertionPoint
        let newCode = "変数 y: 整数型 ← x * 2\n"

        let result = try incrementalTokenizer.updateTokens(
            in: insertionRange,
            with: newCode,
            previousTokens: originalTokens,
            originalText: originalText
        )

        #expect(result.tokens.count > originalTokens.count, "Should have more tokens")

        // Verify that new tokens are present
        let identifiers = result.tokens.filter { $0.type == .identifier }
        #expect(identifiers.contains { $0.lexeme == "y" }, "Should contain new variable")

        // Verify that the if statement tokens are still present and properly positioned
        let ifTokens = result.tokens.filter { $0.type == .ifKeyword }
        #expect(!ifTokens.isEmpty, "Should still contain if tokens")
    }

    @Test("Efficiency metrics")
    func testEfficiencyMetrics() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        // Create a large document
        var largeText = ""
        for index in 0..<100 {
            largeText += "変数 var\(index): 整数型 ← \(index)\n"
        }

        let originalTokens = try baseTokenizer.tokenize(largeText)

        // Make a small change at the end
        let insertionRange = largeText.endIndex..<largeText.endIndex
        let newText = "変数 newVar: 整数型 ← 999\n"

        let result = try incrementalTokenizer.updateTokens(
            in: insertionRange,
            with: newText,
            previousTokens: originalTokens,
            originalText: largeText
        )

        // Efficiency should be high because we only changed a small part
        #expect(result.metrics.efficiency > 0.5, "Should be reasonably efficient")
        #expect(result.metrics.reparsedCharacters < largeText.count / 2, "Should not reparse too much")
    }

    @Test("Boundary detection")
    func testBoundaryDetection() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "first line\nsecond line\nthird line"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Modify the middle line
        let secondLineRange = originalText.range(of: "second line")!
        let result = try incrementalTokenizer.updateTokens(
            in: secondLineRange,
            with: "modified line",
            previousTokens: originalTokens,
            originalText: originalText
        )

        // The reparse region should extend to safe boundaries (line boundaries)
        #expect(result.reparseRegion.baseLine >= 1, "Should start at reasonable line")
        #expect(result.affectedRange.startTokenIndex >= 0, "Should have valid affected range")
        #expect(result.affectedRange.endTokenIndex <= originalTokens.count, "Should have valid affected range")
    }

    @Test("Token type preservation")
    func testTokenTypePreservation() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "変数 x: 整数型 ← 42 + 10"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Change just the first number
        let firstNumberRange = originalText.range(of: "42")!
        let result = try incrementalTokenizer.updateTokens(
            in: firstNumberRange,
            with: "100",
            previousTokens: originalTokens,
            originalText: originalText
        )

        // Token types should be preserved
        let originalTypes = originalTokens.map(\.type)
        let newTypes = result.tokens.map(\.type)

        #expect(originalTypes.count == newTypes.count, "Should have same number of token types")

        // All non-number tokens should be the same
        for index in 0..<min(originalTypes.count, newTypes.count) {
            if originalTokens[index].lexeme != "42" {
                #expect(originalTypes[index] == newTypes[index], "Non-modified tokens should preserve type")
            }
        }
    }

    @Test("Large insertion efficiency")
    func testLargeInsertionEfficiency() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "start\nend"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Insert a large block of code in the middle
        let insertionPoint = originalText.range(of: "\n")!.upperBound
        let insertionRange = insertionPoint..<insertionPoint

        var largeInsertion = ""
        for index in 0..<50 {
            largeInsertion += "変数 inserted\(index): 整数型 ← \(index)\n"
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try incrementalTokenizer.updateTokens(
            in: insertionRange,
            with: largeInsertion,
            previousTokens: originalTokens,
            originalText: originalText
        )
        let incrementalDuration = CFAbsoluteTimeGetCurrent() - startTime

        // Compare with full tokenization
        let newFullText = originalText.replacingCharacters(in: insertionRange, with: largeInsertion)
        let fullStartTime = CFAbsoluteTimeGetCurrent()
        let fullTokens = try baseTokenizer.tokenize(newFullText)
        let fullDuration = CFAbsoluteTimeGetCurrent() - fullStartTime

        // Incremental should be faster for large insertions
        #expect(result.tokens.count == fullTokens.count, "Should produce same number of tokens")

        // Performance should be reasonable
        #expect(incrementalDuration < fullDuration * 2, "Incremental should not be much slower than full")
    }

    @Test("Comment insertion and removal")
    func testCommentInsertionAndRemoval() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        let originalText = "変数 x: 整数型\nx ← 42"
        let originalTokens = try baseTokenizer.tokenize(originalText)

        // Insert a comment at the beginning
        let insertionRange = originalText.startIndex..<originalText.startIndex
        let comment = "// これはコメントです\n"

        let resultWithComment = try incrementalTokenizer.updateTokens(
            in: insertionRange,
            with: comment,
            previousTokens: originalTokens,
            originalText: originalText
        )

        // Verify comment was added
        let commentTokens = resultWithComment.tokens.filter { $0.type == .comment }
        #expect(!commentTokens.isEmpty, "Should contain comment tokens")

        // Now remove the comment
        let textWithComment = originalText.replacingCharacters(in: insertionRange, with: comment)
        let commentRange = textWithComment.startIndex..<textWithComment.index(textWithComment.startIndex, offsetBy: comment.count)

        let resultWithoutComment = try incrementalTokenizer.updateTokens(
            in: commentRange,
            with: "",
            previousTokens: resultWithComment.tokens,
            originalText: textWithComment
        )

        // Should be back to original state
        #expect(resultWithoutComment.tokens.count == originalTokens.count, "Should have original token count")

        let finalCommentTokens = resultWithoutComment.tokens.filter { $0.type == .comment }
        #expect(finalCommentTokens.isEmpty, "Should not contain comment tokens")
    }

    @Test("Performance regression detection")
    func testPerformanceRegressionDetection() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        // Create a moderately sized document
        var document = ""
        for index in 0..<50 {
            document += "変数 variable\(index): 整数型 ← \(index * 2)\n"
        }

        let originalTokens = try baseTokenizer.tokenize(document)

        // Perform multiple small edits and measure cumulative performance
        var currentText = document
        var currentTokens = originalTokens
        let numberOfEdits = 20
        var totalIncrementalTime: TimeInterval = 0

        for index in 0..<numberOfEdits {
            // Insert a small change
            let insertionPoint = currentText.index(currentText.startIndex, offsetBy: min(index * 10, currentText.count))
            let insertionRange = insertionPoint..<insertionPoint
            let newText = " // edit \(index)"

            let startTime = CFAbsoluteTimeGetCurrent()
            let result = try incrementalTokenizer.updateTokens(
                in: insertionRange,
                with: newText,
                previousTokens: currentTokens,
                originalText: currentText
            )
            totalIncrementalTime += CFAbsoluteTimeGetCurrent() - startTime

            currentText = currentText.replacingCharacters(in: insertionRange, with: newText)
            currentTokens = result.tokens
        }

        // Compare with full tokenization
        let fullStartTime = CFAbsoluteTimeGetCurrent()
        let fullTokens = try baseTokenizer.tokenize(currentText)
        let fullTime = CFAbsoluteTimeGetCurrent() - fullStartTime

        #expect(currentTokens.count == fullTokens.count, "Should produce same number of tokens")

        // Total incremental time should be reasonable compared to one full tokenization
        let efficiencyRatio = totalIncrementalTime / fullTime
        #expect(efficiencyRatio < 5.0, "Cumulative incremental time should be reasonable")

        print("Efficiency ratio: \(efficiencyRatio) (lower is better)")
    }
}
