import Foundation

// MARK: - Document

/// Represents an open text document.
public struct Document: Sendable {
    /// The document URI
    public let uri: String
    /// The language identifier
    public let languageId: String
    /// The document version
    public var version: Int
    /// The document content
    public var content: String
    /// Lines cache for quick access
    private var linesCache: [Substring]?

    public init(uri: String, languageId: String, version: Int, content: String) {
        self.uri = uri
        self.languageId = languageId
        self.version = version
        self.content = content
        self.linesCache = nil
    }

    /// Get all lines in the document.
    public var lines: [Substring] {
        mutating get {
            if let cached = linesCache {
                return cached
            }
            let computed = content.split(separator: "\n", omittingEmptySubsequences: false)
            linesCache = computed
            return computed
        }
    }

    /// Get the line count.
    public var lineCount: Int {
        mutating get {
            return lines.count
        }
    }

    /// Update the content and invalidate cache.
    public mutating func updateContent(_ newContent: String, version: Int) {
        self.content = newContent
        self.version = version
        self.linesCache = nil
    }

    /// Convert UTF-16 offset (LSP standard) to Swift String.Index
    private func utf16ToStringIndex(_ text: String, utf16Offset: Int) -> String.Index? {
        guard utf16Offset >= 0 else { return nil }
        guard let utf16Index = text.utf16.index(text.utf16.startIndex, offsetBy: utf16Offset, limitedBy: text.utf16.endIndex) else {
            return nil
        }
        return utf16Index.samePosition(in: text)
    }

    /// Convert Swift String.Index to UTF-16 offset (LSP standard)
    private func stringIndexToUtf16(_ text: String, index: String.Index) -> Int {
        return text.utf16.distance(from: text.utf16.startIndex, to: index)
    }

    /// Get text at a specific position.
    public mutating func textAt(line: Int, character: Int) -> Character? {
        let allLines = lines
        guard line >= 0, line < allLines.count else { return nil }
        let lineText = String(allLines[line])
        // Convert UTF-16 offset (LSP standard) to Swift String.Index
        guard let idx = utf16ToStringIndex(lineText, utf16Offset: character),
              idx < lineText.endIndex else { return nil }
        return lineText[idx]
    }

    /// Get text in a range.
    public mutating func textInRange(_ range: Range) -> String? {
        let allLines = lines
        guard range.start.line >= 0, range.start.line < allLines.count else { return nil }
        guard range.end.line >= 0, range.end.line < allLines.count else { return nil }

        if range.start.line == range.end.line {
            let line = String(allLines[range.start.line])
            // Convert UTF-16 offsets to Swift String.Index
            guard let start = utf16ToStringIndex(line, utf16Offset: range.start.character),
                  let end = utf16ToStringIndex(line, utf16Offset: range.end.character) else { return nil }
            return String(line[start..<end])
        }

        var result = ""
        for lineNum in range.start.line...range.end.line {
            let line = String(allLines[lineNum])
            if lineNum == range.start.line {
                if let start = utf16ToStringIndex(line, utf16Offset: range.start.character) {
                    result += line[start...]
                    result += "\n"
                }
            } else if lineNum == range.end.line {
                if let end = utf16ToStringIndex(line, utf16Offset: range.end.character) {
                    result += line[..<end]
                }
            } else {
                result += line
                result += "\n"
            }
        }
        return result
    }

    /// Get the word at a position.
    public mutating func wordAt(line: Int, character: Int) -> (word: String, range: Range)? {
        let allLines = lines
        guard line >= 0, line < allLines.count else { return nil }
        let lineText = String(allLines[line])

        // Convert UTF-16 offset (LSP standard) to Swift String.Index
        guard let startIdx = utf16ToStringIndex(lineText, utf16Offset: character) else {
            return nil
        }

        // Find word boundaries
        var wordStart = startIdx
        var wordEnd = startIdx

        // Find start of word
        while wordStart > lineText.startIndex {
            let prevIdx = lineText.index(before: wordStart)
            let char = lineText[prevIdx]
            if !char.isLetter && !char.isNumber && char != "_" {
                break
            }
            wordStart = prevIdx
        }

        // Find end of word
        while wordEnd < lineText.endIndex {
            let char = lineText[wordEnd]
            if !char.isLetter && !char.isNumber && char != "_" {
                break
            }
            wordEnd = lineText.index(after: wordEnd)
        }

        guard wordStart < wordEnd else { return nil }

        let word = String(lineText[wordStart..<wordEnd])
        // Convert String.Index to UTF-16 offset for LSP compliance
        let startChar = stringIndexToUtf16(lineText, index: wordStart)
        let endChar = stringIndexToUtf16(lineText, index: wordEnd)

        return (word, Range(startLine: line, startCharacter: startChar, endLine: line, endCharacter: endChar))
    }

    /// Convert an offset to a position (using UTF-16 semantics for LSP compliance).
    public mutating func positionFromOffset(_ offset: Int) -> Position? {
        var currentOffset = 0
        for (lineNum, line) in lines.enumerated() {
            let lineLength = line.utf16.count + 1 // +1 for newline
            if currentOffset + lineLength > offset {
                return Position(line: lineNum, character: offset - currentOffset)
            }
            currentOffset += lineLength
        }
        return nil
    }

    /// Convert a position to an offset (using UTF-16 semantics for LSP compliance).
    public mutating func offsetFromPosition(_ position: Position) -> Int? {
        let allLines = lines
        guard position.line >= 0, position.line < allLines.count else { return nil }

        var offset = 0
        for lineNum in 0..<position.line {
            offset += allLines[lineNum].utf16.count + 1 // +1 for newline
        }
        offset += position.character
        return offset
    }
}

// MARK: - Document Store

/// Thread-safe storage for open documents.
public actor DocumentStore {
    /// Storage for open documents
    private var documents: [String: Document] = [:]

    public init() {}

    /// Open a new document.
    public func open(uri: String, languageId: String, version: Int, content: String) {
        documents[uri] = Document(uri: uri, languageId: languageId, version: version, content: content)
    }

    /// Update an existing document.
    public func update(uri: String, version: Int, content: String) {
        guard var document = documents[uri] else { return }
        document.updateContent(content, version: version)
        documents[uri] = document
    }

    /// Close a document.
    public func close(uri: String) {
        documents.removeValue(forKey: uri)
    }

    /// Get a document by URI.
    public func get(uri: String) -> Document? {
        return documents[uri]
    }

    /// Get all open document URIs.
    public func allUris() -> [String] {
        return Array(documents.keys)
    }

    /// Check if a document is open.
    public func isOpen(uri: String) -> Bool {
        return documents[uri] != nil
    }

    /// Get all documents.
    public func allDocuments() -> [Document] {
        return Array(documents.values)
    }
}
