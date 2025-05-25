import Foundation

// MARK: - Incremental Tokenizer

/// A tokenizer that supports incremental updates for efficient real-time editing
public struct IncrementalTokenizer: Sendable {
    private let baseTokenizer: ParsingTokenizer
    private let chunkProcessor: ChunkProcessor
    
    public init(baseTokenizer: ParsingTokenizer = ParsingTokenizer()) {
        self.baseTokenizer = baseTokenizer
        self.chunkProcessor = ChunkProcessor()
    }
    
    /// Updates tokens in a specific range with new text
    public func updateTokens(
        in range: Range<String.Index>,
        with newText: String,
        previousTokens: [Token],
        originalText: String
    ) throws -> TokenizeResult {
        // Construct new text with the replacement
        let newFullText = originalText.replacingCharacters(in: range, with: newText)
        
        // Find affected token range
        let affectedRange = findAffectedTokenRange(
            range: range,
            in: previousTokens,
            originalText: originalText
        )
        
        // Determine minimal reparse region
        let reparseRegion = calculateReparseRegion(
            affectedRange: affectedRange,
            newText: newText,
            originalText: originalText,
            range: range
        )
        
        // Extract text to reparse
        let textToReparse = String(newFullText[reparseRegion.textRange])
        
        // Tokenize only the affected region
        let newTokens = try baseTokenizer.tokenize(textToReparse)
        
        // Adjust positions of new tokens
        let adjustedTokens = adjustTokenPositions(
            tokens: newTokens,
            baseOffset: reparseRegion.baseOffset,
            baseLine: reparseRegion.baseLine,
            baseColumn: reparseRegion.baseColumn
        )
        
        // Merge with unchanged tokens
        let mergedTokens = mergeTokens(
            previousTokens: previousTokens,
            newTokens: adjustedTokens,
            affectedRange: affectedRange
        )
        
        return TokenizeResult(
            tokens: mergedTokens,
            affectedRange: affectedRange,
            reparseRegion: reparseRegion,
            metrics: createMetrics(
                originalCount: previousTokens.count,
                newCount: mergedTokens.count,
                reparsedLength: textToReparse.count
            )
        )
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
        let sampleSize = min(100, result.tokens.count)
        let sampledIndices = stride(from: 0, to: result.tokens.count, by: max(1, result.tokens.count / sampleSize))
        
        var typeMismatches = 0
        var positionMismatches = 0
        
        for index in sampledIndices {
            if index < fullTokens.count {
                if result.tokens[index].type != fullTokens[index].type {
                    typeMismatches += 1
                }
                if result.tokens[index].position != fullTokens[index].position {
                    positionMismatches += 1
                }
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
    
    private func findAffectedTokenRange(
        range: Range<String.Index>,
        in tokens: [Token],
        originalText: String
    ) -> AffectedRange {
        let startOffset = originalText.distance(from: originalText.startIndex, to: range.lowerBound)
        let endOffset = originalText.distance(from: originalText.startIndex, to: range.upperBound)
        
        var startTokenIndex: Int?
        var endTokenIndex: Int?
        
        // Find first token that starts at or after the change start
        for (index, token) in tokens.enumerated() {
            if token.position.offset >= startOffset && startTokenIndex == nil {
                startTokenIndex = index
            }
            if token.position.offset >= endOffset {
                endTokenIndex = index
                break
            }
        }
        
        // Extend range to include tokens that might be affected
        let safeStartIndex = max(0, (startTokenIndex ?? 0) - 2)
        let safeEndIndex = min(tokens.count, (endTokenIndex ?? tokens.count) + 2)
        
        return AffectedRange(
            startTokenIndex: safeStartIndex,
            endTokenIndex: safeEndIndex,
            startOffset: startOffset,
            endOffset: endOffset
        )
    }
    
    private func calculateReparseRegion(
        affectedRange: AffectedRange,
        newText: String,
        originalText: String,
        range: Range<String.Index>
    ) -> ReparseRegion {
        // Calculate how the text length changed
        let originalLength = originalText.distance(from: range.lowerBound, to: range.upperBound)
        let newLength = newText.count
        let lengthDelta = newLength - originalLength
        
        // Extend reparse region to safe boundaries (e.g., line boundaries)
        let startIndex = findSafeStart(from: range.lowerBound, in: originalText)
        let endIndex = findSafeEnd(from: range.upperBound, in: originalText)
        
        let startOffset = originalText.distance(from: originalText.startIndex, to: startIndex)
        let endOffset = originalText.distance(from: originalText.startIndex, to: endIndex)
        
        // Calculate position information
        let position = calculatePosition(at: startIndex, in: originalText)
        
        // Create the new text range after replacement
        let newText = originalText.replacingCharacters(in: range, with: newText)
        let newStartIndex = newText.index(newText.startIndex, offsetBy: startOffset)
        let newEndOffset = endOffset + lengthDelta
        let newEndIndex = newText.index(newText.startIndex, offsetBy: min(newEndOffset, newText.count))
        
        return ReparseRegion(
            textRange: newStartIndex..<newEndIndex,
            baseOffset: startOffset,
            baseLine: position.line,
            baseColumn: position.column
        )
    }
    
    private func findSafeStart(from index: String.Index, in text: String) -> String.Index {
        var current = index
        
        // Move back to the beginning of the current line
        while current > text.startIndex {
            let previous = text.index(before: current)
            if text[previous] == "\n" {
                break
            }
            current = previous
        }
        
        return current
    }
    
    private func findSafeEnd(from index: String.Index, in text: String) -> String.Index {
        var current = index
        
        // Move forward to the end of the current line or a safe boundary
        while current < text.endIndex {
            if text[current] == "\n" {
                current = text.index(after: current)
                break
            }
            current = text.index(after: current)
        }
        
        return current
    }
    
    private func calculatePosition(at index: String.Index, in text: String) -> SourcePosition {
        var line = 1
        var column = 1
        var offset = 0
        
        for char in text[..<index] {
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            offset += 1
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
    
    private func mergeTokens(
        previousTokens: [Token],
        newTokens: [Token],
        affectedRange: AffectedRange
    ) -> [Token] {
        var result: [Token] = []
        
        // Add tokens before the affected range
        if affectedRange.startTokenIndex > 0 {
            result.append(contentsOf: previousTokens[0..<affectedRange.startTokenIndex])
        }
        
        // Add new tokens
        result.append(contentsOf: newTokens)
        
        // Add tokens after the affected range
        if affectedRange.endTokenIndex < previousTokens.count {
            result.append(contentsOf: previousTokens[affectedRange.endTokenIndex...])
        }
        
        return result
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
        return 1.0 - (Double(reparsedCharacters) / Double(max(originalTokenCount, newTokenCount) * 10))
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