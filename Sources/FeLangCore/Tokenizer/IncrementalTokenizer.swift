import Foundation

// MARK: - Incremental Tokenizer State

/// Represents the parsing state for incremental tokenization.
/// Used to determine safe boundaries for incremental re-tokenization.
public struct IncrementalParsingState: Equatable, Sendable {
    /// Whether currently inside a string literal
    public let inString: Bool

    /// Whether currently inside a multi-line comment
    public let inMultiLineComment: Bool

    /// Current bracket nesting depth
    public let bracketDepth: Int

    /// Current parenthesis nesting depth
    public let parenDepth: Int

    /// The line number (1-indexed)
    public let lineNumber: Int

    public init(
        inString: Bool = false,
        inMultiLineComment: Bool = false,
        bracketDepth: Int = 0,
        parenDepth: Int = 0,
        lineNumber: Int = 1
    ) {
        self.inString = inString
        self.inMultiLineComment = inMultiLineComment
        self.bracketDepth = bracketDepth
        self.parenDepth = parenDepth
        self.lineNumber = lineNumber
    }

    /// Default state at the start of tokenization
    public static let initial = IncrementalParsingState()

    /// Whether this state represents a "safe" boundary for re-tokenization
    public var isSafeBoundary: Bool {
        return !inString && !inMultiLineComment && bracketDepth == 0 && parenDepth == 0
    }
}

// MARK: - Incremental Tokenizer

/// A tokenizer that supports incremental updates for efficient real-time editing
public struct IncrementalTokenizer: Sendable {
    private let baseTokenizer: ParsingTokenizer

    /// Threshold for using incremental vs full re-tokenization
    private let incrementalThreshold: Int

    /// Maximum characters to re-tokenize before falling back to full
    private let maxReparseLength: Int

    public init(
        baseTokenizer: ParsingTokenizer = ParsingTokenizer(),
        incrementalThreshold: Int = 100,
        maxReparseLength: Int = 10000
    ) {
        self.baseTokenizer = baseTokenizer
        self.incrementalThreshold = incrementalThreshold
        self.maxReparseLength = maxReparseLength
    }

    /// Updates tokens in a specific range with new text using incremental tokenization
    public func updateTokens(
        in range: Range<String.Index>,
        with newText: String,
        previousTokens: [Token],
        originalText: String
    ) throws -> TokenizeResult {
        let newFullText = originalText.replacingCharacters(in: range, with: newText)

        if previousTokens.count < incrementalThreshold {
            return try fullRetokenize(newFullText: newFullText, previousTokens: previousTokens, range: range)
        }

        let offsets = calculateChangeOffsets(originalText: originalText, range: range, newText: newText)

        let useIncremental = shouldUseIncremental(
            previousTokens: previousTokens,
            changeLength: offsets.changeLength,
            totalLength: newFullText.unicodeScalars.count
        )

        if useIncremental {
            let context = IncrementalUpdateContext(
                range: range, newText: newText, previousTokens: previousTokens,
                originalText: originalText, newFullText: newFullText,
                startOffset: offsets.startOffset, endOffset: offsets.endOffset
            )
            return try updateTokensIncrementally(context: context)
        } else {
            return try fullRetokenize(
                newFullText: newFullText, previousTokens: previousTokens,
                startOffset: offsets.startOffset, endOffset: offsets.endOffset, range: range
            )
        }
    }

    private func calculateChangeOffsets(
        originalText: String, range: Range<String.Index>, newText: String
    ) -> (startOffset: Int, endOffset: Int, changeLength: Int) {
        let startOffset = originalText.unicodeScalars.distance(from: originalText.unicodeScalars.startIndex, to: range.lowerBound)
        let endOffset = originalText.unicodeScalars.distance(from: originalText.unicodeScalars.startIndex, to: range.upperBound)
        let changeLength = max(newText.unicodeScalars.count, endOffset - startOffset)
        return (startOffset, endOffset, changeLength)
    }

    // MARK: - Incremental Update

    /// Performs true incremental tokenization
    private func updateTokensIncrementally(
        context: IncrementalUpdateContext
    ) throws -> TokenizeResult {
        let (safeStartIndex, safeStartOffset) = findSafeReparseStart(
            tokens: context.previousTokens, editStartOffset: context.startOffset
        )
        let (safeEndIndex, safeEndOffset) = findSafeReparseEnd(
            tokens: context.previousTokens, editEndOffset: context.endOffset,
            totalTokens: context.previousTokens.count
        )

        let offsetDelta = context.newText.unicodeScalars.count - (context.endOffset - context.startOffset)

        guard let reparseInfo = extractReparseRegion(
            context: context, safeStartOffset: safeStartOffset,
            safeEndOffset: safeEndOffset, offsetDelta: offsetDelta
        ) else {
            return try fullRetokenize(
                newFullText: context.newFullText, previousTokens: context.previousTokens,
                startOffset: context.startOffset, endOffset: context.endOffset, range: context.range
            )
        }

        let reparsedTokens = try baseTokenizer.tokenize(reparseInfo.textToReparse)
        let basePosition = calculatePosition(at: reparseInfo.reparseStartIndex, in: context.newFullText)

        let adjustedReparsedTokens = adjustTokenPositions(
            tokens: reparsedTokens, baseOffset: reparseInfo.newStartOffset,
            baseLine: basePosition.line, baseColumn: basePosition.column
        )

        let adjustedSuffixTokens = adjustSuffixTokenPositions(
            context: context, safeEndIndex: safeEndIndex, offsetDelta: offsetDelta
        )

        return buildIncrementalResult(
            context: context, safeStartIndex: safeStartIndex, safeEndIndex: safeEndIndex,
            adjustedReparsedTokens: adjustedReparsedTokens, adjustedSuffixTokens: adjustedSuffixTokens,
            reparseInfo: reparseInfo, basePosition: basePosition
        )
    }

    private struct ReparseInfo {
        let reparseStartIndex: String.Index
        let reparseEndIndex: String.Index
        let newStartOffset: Int
        let textToReparse: String
    }

    private func extractReparseRegion(
        context: IncrementalUpdateContext, safeStartOffset: Int,
        safeEndOffset: Int, offsetDelta: Int
    ) -> ReparseInfo? {
        let newStartOffset = safeStartOffset
        let newEndOffset = safeEndOffset + offsetDelta
        let scalarCount = context.newFullText.unicodeScalars.count

        guard newStartOffset >= 0 && newEndOffset >= 0 &&
              newStartOffset <= newEndOffset &&
              newStartOffset <= scalarCount && newEndOffset <= scalarCount else {
            return nil
        }

        let scalars = context.newFullText.unicodeScalars
        let startScalar = scalars.index(scalars.startIndex, offsetBy: newStartOffset)
        let endScalar = scalars.index(scalars.startIndex, offsetBy: min(newEndOffset, scalarCount))
        let reparseStart = startScalar.samePosition(in: context.newFullText) ?? context.newFullText.startIndex
        let reparseEnd = endScalar.samePosition(in: context.newFullText) ?? context.newFullText.endIndex

        return ReparseInfo(
            reparseStartIndex: reparseStart, reparseEndIndex: reparseEnd,
            newStartOffset: newStartOffset,
            textToReparse: String(context.newFullText[reparseStart..<reparseEnd])
        )
    }

    private func adjustSuffixTokenPositions(
        context: IncrementalUpdateContext, safeEndIndex: Int, offsetDelta: Int
    ) -> [Token] {
        let lineDelta = countNewlines(in: context.newText) - countNewlines(in: context.originalText[context.range])
        let editEndLine = calculatePosition(at: context.range.upperBound, in: context.originalText).line
        let columnDelta = lineDelta == 0 ? (context.newText.count - context.originalText[context.range].count) : 0
        return adjustTokenPositionsAfterEdit(
            tokens: Array(context.previousTokens[safeEndIndex...]),
            offsetDelta: offsetDelta, lineDelta: lineDelta,
            columnDelta: columnDelta, editEndLine: editEndLine
        )
    }

    private func buildIncrementalResult(
        context: IncrementalUpdateContext, safeStartIndex: Int, safeEndIndex: Int,
        adjustedReparsedTokens: [Token], adjustedSuffixTokens: [Token],
        reparseInfo: ReparseInfo, basePosition: SourcePosition
    ) -> TokenizeResult {
        let prefixTokens = safeStartIndex > 0 ? Array(context.previousTokens[..<safeStartIndex]) : []
        let mergedTokens = prefixTokens + adjustedReparsedTokens + adjustedSuffixTokens

        return TokenizeResult(
            tokens: mergedTokens,
            affectedRange: AffectedRange(
                startTokenIndex: safeStartIndex, endTokenIndex: safeEndIndex,
                startOffset: context.startOffset, endOffset: context.endOffset
            ),
            reparseRegion: ReparseRegion(
                textRange: reparseInfo.reparseStartIndex..<reparseInfo.reparseEndIndex,
                baseOffset: reparseInfo.newStartOffset,
                baseLine: basePosition.line, baseColumn: basePosition.column
            ),
            metrics: createMetrics(
                originalCount: context.previousTokens.count,
                newCount: mergedTokens.count,
                reparsedLength: reparseInfo.textToReparse.count
            )
        )
    }

    /// Full re-tokenization fallback (fast path for small files, skips offset calculation)
    private func fullRetokenize(
        newFullText: String,
        previousTokens: [Token],
        range: Range<String.Index>
    ) throws -> TokenizeResult {
        let allTokens = try baseTokenizer.tokenize(newFullText)

        let affectedRange = AffectedRange(
            startTokenIndex: 0,
            endTokenIndex: previousTokens.count,
            startOffset: 0,
            endOffset: 0
        )

        let reparseRegion = ReparseRegion(
            textRange: range,
            baseOffset: 0,
            baseLine: 1,
            baseColumn: 1
        )

        return TokenizeResult(
            tokens: allTokens,
            affectedRange: affectedRange,
            reparseRegion: reparseRegion,
            metrics: createMetrics(
                originalCount: previousTokens.count,
                newCount: allTokens.count,
                reparsedLength: newFullText.count
            )
        )
    }

    /// Full re-tokenization fallback
    private func fullRetokenize(
        newFullText: String,
        previousTokens: [Token],
        startOffset: Int,
        endOffset: Int,
        range: Range<String.Index>
    ) throws -> TokenizeResult {
        let allTokens = try baseTokenizer.tokenize(newFullText)

        let affectedRange = AffectedRange(
            startTokenIndex: 0,
            endTokenIndex: previousTokens.count,
            startOffset: startOffset,
            endOffset: endOffset
        )

        let reparseRegion = ReparseRegion(
            textRange: range,
            baseOffset: startOffset,
            baseLine: 1,
            baseColumn: 1
        )

        return TokenizeResult(
            tokens: allTokens,
            affectedRange: affectedRange,
            reparseRegion: reparseRegion,
            metrics: createMetrics(
                originalCount: previousTokens.count,
                newCount: allTokens.count,
                reparsedLength: newFullText.count
            )
        )
    }

    // MARK: - Safe Boundary Detection

    /// Determines whether to use incremental or full re-tokenization
    private func shouldUseIncremental(
        previousTokens: [Token],
        changeLength: Int,
        totalLength: Int
    ) -> Bool {
        // Use full re-tokenization for small files or large changes
        if previousTokens.count < incrementalThreshold {
            return false
        }

        if changeLength > maxReparseLength {
            return false
        }

        // Use incremental if the change is small relative to total
        let changeRatio = Double(changeLength) / Double(max(1, totalLength))
        return changeRatio < 0.5
    }

    /// Finds a safe start position for re-tokenization
    private func findSafeReparseStart(
        tokens: [Token],
        editStartOffset: Int
    ) -> (tokenIndex: Int, offset: Int) {
        // Find the first token that starts at or after the edit position
        var startIndex = tokens.count  // Default to end if edit is after all tokens

        for (index, token) in tokens.enumerated() where token.position.offset >= editStartOffset {
            startIndex = index
            break
        }

        // Move back to find a safe boundary (line start or start of file)
        var safeIndex = startIndex

        while safeIndex > 0 {
            let token = tokens[safeIndex - 1]

            // A newline token or start of a statement is a safe boundary
            if token.type == .newline {
                break
            }

            // Also break at the start of compound tokens
            if isStatementStartToken(token.type) {
                break
            }

            safeIndex -= 1
        }

        // Handle case where edit is after all tokens
        if safeIndex >= tokens.count {
            let endOffset = tokens.last.map { $0.position.offset + $0.lexeme.unicodeScalars.count } ?? 0
            return (tokens.count, endOffset)
        }
        let offset = safeIndex > 0 ? tokens[safeIndex].position.offset : 0
        return (safeIndex, offset)
    }

    /// Finds a safe end position for re-tokenization
    private func findSafeReparseEnd(
        tokens: [Token],
        editEndOffset: Int,
        totalTokens: Int
    ) -> (tokenIndex: Int, offset: Int) {
        // Find the first token that starts at or after the edit end
        var endIndex = totalTokens

        for (index, token) in tokens.enumerated() where token.position.offset > editEndOffset {
            endIndex = index
            break
        }

        // Move forward to find a safe boundary
        var safeIndex = endIndex

        while safeIndex < totalTokens {
            let token = tokens[safeIndex]

            if token.type == .newline {
                safeIndex += 1
                break
            }

            if isStatementEndToken(token.type) {
                safeIndex += 1
                break
            }

            safeIndex += 1
        }

        if safeIndex >= totalTokens {
            return (totalTokens, tokens.last.map { $0.position.offset + $0.lexeme.unicodeScalars.count } ?? 0)
        }

        let offset = tokens[safeIndex].position.offset
        return (safeIndex, offset)
    }

    /// Checks if a token type represents the start of a statement
    private func isStatementStartToken(_ type: TokenType) -> Bool {
        switch type {
        case .ifKeyword, .whileKeyword, .forKeyword,
             .functionKeyword, .procedureKeyword,
             .variableKeyword, .constantKeyword,
             .returnKeyword, .breakKeyword, .continueKeyword:
            return true
        default:
            return false
        }
    }

    /// Checks if a token type represents the end of a statement
    private func isStatementEndToken(_ type: TokenType) -> Bool {
        switch type {
        case .endifKeyword, .endwhileKeyword, .endforKeyword,
             .endfunctionKeyword, .endprocedureKeyword:
            return true
        default:
            return false
        }
    }

    // MARK: - Position Adjustment

    /// Adjusts token positions after an edit
    private func adjustTokenPositionsAfterEdit(
        tokens: [Token],
        offsetDelta: Int,
        lineDelta: Int,
        columnDelta: Int = 0,
        editEndLine: Int = -1
    ) -> [Token] {
        return tokens.map { token in
            // Apply column delta only to tokens on the same line as the edit end
            let shouldAdjustColumn = editEndLine >= 0 && token.position.line == editEndLine
            let adjustedColumn = shouldAdjustColumn ? token.position.column + columnDelta : token.position.column

            let adjustedPosition = SourcePosition(
                line: token.position.line + lineDelta,
                column: adjustedColumn,
                offset: token.position.offset + offsetDelta
            )

            return Token(
                type: token.type,
                lexeme: token.lexeme,
                position: adjustedPosition
            )
        }
    }

    /// Counts the number of newlines in a string or substring
    private func countNewlines<S: StringProtocol>(in text: S) -> Int {
        return text.filter { $0 == "\n" }.count
    }

    /// Performs a quick tokenization check to validate incremental results
    public func validateIncremental(
        result: TokenizeResult,
        fullText: String
    ) throws -> ValidationResult {
        // Perform full tokenization for comparison
        let fullTokens = try baseTokenizer.tokenize(fullText)

        // Compare token counts
        let countMatches = result.tokens.count == fullTokens.count

        // Compare token types and positions (sampling for performance)
        let sampleSize = min(100, max(1, result.tokens.count))
        let sampledIndices = stride(from: 0, to: result.tokens.count, by: max(1, result.tokens.count / sampleSize))

        var typeMismatches = 0
        var positionMismatches = 0

        for index in sampledIndices where index < fullTokens.count {
            if result.tokens[index].type != fullTokens[index].type {
                typeMismatches += 1
            }
            if result.tokens[index].position != fullTokens[index].position {
                positionMismatches += 1
            }
        }

        return ValidationResult(
            isValid: countMatches && typeMismatches == 0 && positionMismatches == 0,
            tokenCountMatch: countMatches,
            typeMismatches: typeMismatches,
            positionMismatches: positionMismatches,
            sampledCount: sampleSize
        )
    }

    // MARK: - Private Methods

    private func calculatePosition(at index: String.Index, in text: String) -> SourcePosition {
        var line = 1
        var column = 1
        // Calculate offset in Unicode scalars to match SourcePosition semantics
        let offset = text.unicodeScalars.distance(from: text.unicodeScalars.startIndex, to: index)

        for char in text[..<index] {
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        return SourcePosition(line: line, column: column, offset: offset)
    }

    private func adjustTokenPositions(
        tokens: [Token],
        baseOffset: Int,
        baseLine: Int,
        baseColumn: Int
    ) -> [Token] {
        return tokens.map { token in
            let adjustedPosition = SourcePosition(
                line: token.position.line + baseLine - 1,
                column: token.position.line == 1 ?
                    token.position.column + baseColumn - 1 :
                    token.position.column,
                offset: token.position.offset + baseOffset
            )

            return Token(
                type: token.type,
                lexeme: token.lexeme,
                position: adjustedPosition
            )
        }
    }

    private func createMetrics(
        originalCount: Int,
        newCount: Int,
        reparsedLength: Int
    ) -> IncrementalMetrics {
        return IncrementalMetrics(
            originalTokenCount: originalCount,
            newTokenCount: newCount,
            reparsedCharacters: reparsedLength,
            tokensAdded: max(0, newCount - originalCount),
            tokensRemoved: max(0, originalCount - newCount)
        )
    }
}

// MARK: - Supporting Types

/// Result of an incremental tokenization operation
public struct TokenizeResult: Sendable {
    /// The updated token array
    public let tokens: [Token]

    /// Information about which tokens were affected
    public let affectedRange: AffectedRange

    /// Information about the region that was reparsed
    public let reparseRegion: ReparseRegion

    /// Performance metrics for the operation
    public let metrics: IncrementalMetrics

    public init(
        tokens: [Token],
        affectedRange: AffectedRange,
        reparseRegion: ReparseRegion,
        metrics: IncrementalMetrics
    ) {
        self.tokens = tokens
        self.affectedRange = affectedRange
        self.reparseRegion = reparseRegion
        self.metrics = metrics
    }
}

/// Information about tokens affected by an incremental update
public struct AffectedRange: Sendable {
    /// Index of the first affected token
    public let startTokenIndex: Int

    /// Index after the last affected token
    public let endTokenIndex: Int

    /// Character offset where the change started
    public let startOffset: Int

    /// Character offset where the change ended
    public let endOffset: Int

    public init(startTokenIndex: Int, endTokenIndex: Int, startOffset: Int, endOffset: Int) {
        self.startTokenIndex = startTokenIndex
        self.endTokenIndex = endTokenIndex
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

/// Information about the region that needs to be reparsed
public struct ReparseRegion: Sendable {
    /// Text range that was reparsed
    public let textRange: Range<String.Index>

    /// Base offset for position adjustment
    public let baseOffset: Int

    /// Base line for position adjustment
    public let baseLine: Int

    /// Base column for position adjustment
    public let baseColumn: Int

    public init(
        textRange: Range<String.Index>,
        baseOffset: Int,
        baseLine: Int,
        baseColumn: Int
    ) {
        self.textRange = textRange
        self.baseOffset = baseOffset
        self.baseLine = baseLine
        self.baseColumn = baseColumn
    }
}

/// Metrics for incremental tokenization performance
public struct IncrementalMetrics: Sendable {
    /// Number of tokens before the update
    public let originalTokenCount: Int

    /// Number of tokens after the update
    public let newTokenCount: Int

    /// Number of characters that were reparsed
    public let reparsedCharacters: Int

    /// Number of tokens added
    public let tokensAdded: Int

    /// Number of tokens removed
    public let tokensRemoved: Int

    /// Efficiency ratio (0.0 to 1.0, higher is better)
    public var efficiency: Double {
        guard reparsedCharacters > 0 else { return 1.0 }
        let ratio = 1.0 - (Double(reparsedCharacters) / Double(max(originalTokenCount, newTokenCount) * 10))
        return max(0.0, min(1.0, ratio))
    }

    public init(
        originalTokenCount: Int,
        newTokenCount: Int,
        reparsedCharacters: Int,
        tokensAdded: Int,
        tokensRemoved: Int
    ) {
        self.originalTokenCount = originalTokenCount
        self.newTokenCount = newTokenCount
        self.reparsedCharacters = reparsedCharacters
        self.tokensAdded = tokensAdded
        self.tokensRemoved = tokensRemoved
    }
}

/// Result of validating incremental tokenization
public struct ValidationResult: Sendable {
    /// Whether the incremental result matches full tokenization
    public let isValid: Bool

    /// Whether token counts match
    public let tokenCountMatch: Bool

    /// Number of type mismatches found
    public let typeMismatches: Int

    /// Number of position mismatches found
    public let positionMismatches: Int

    /// Number of tokens sampled for validation
    public let sampledCount: Int

    public init(
        isValid: Bool,
        tokenCountMatch: Bool,
        typeMismatches: Int,
        positionMismatches: Int,
        sampledCount: Int
    ) {
        self.isValid = isValid
        self.tokenCountMatch = tokenCountMatch
        self.typeMismatches = typeMismatches
        self.positionMismatches = positionMismatches
        self.sampledCount = sampledCount
    }
}
