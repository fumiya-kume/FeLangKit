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

    /// Get text at a specific position.
    public mutating func textAt(line: Int, character: Int) -> Character? {
        let allLines = lines
        guard line >= 0, line < allLines.count else { return nil }
        let lineText = allLines[line]
        let index = lineText.index(lineText.startIndex, offsetBy: character, limitedBy: lineText.endIndex)
        guard let idx = index, idx < lineText.endIndex else { return nil }
        return lineText[idx]
    }

    /// Get text in a range.
    public mutating func textInRange(_ range: Range) -> String? {
        let allLines = lines
        guard range.start.line >= 0, range.start.line < allLines.count else { return nil }
        guard range.end.line >= 0, range.end.line < allLines.count else { return nil }

        if range.start.line == range.end.line {
            let line = allLines[range.start.line]
            let startIndex = line.index(line.startIndex, offsetBy: range.start.character, limitedBy: line.endIndex)
            let endIndex = line.index(line.startIndex, offsetBy: range.end.character, limitedBy: line.endIndex)
            guard let start = startIndex, let end = endIndex else { return nil }
            return String(line[start..<end])
        }

        var result = ""
        for lineNum in range.start.line...range.end.line {
            let line = allLines[lineNum]
            if lineNum == range.start.line {
                let startIndex = line.index(line.startIndex, offsetBy: range.start.character, limitedBy: line.endIndex)
                if let start = startIndex {
                    result += line[start...]
                    result += "\n"
                }
            } else if lineNum == range.end.line {
                let endIndex = line.index(line.startIndex, offsetBy: range.end.character, limitedBy: line.endIndex)
                if let end = endIndex {
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
        guard character >= 0 else { return nil }
        guard let utf16Index = lineText.utf16.index(lineText.utf16.startIndex, offsetBy: character, limitedBy: lineText.utf16.endIndex),
              let startIdx = utf16Index.samePosition(in: lineText) else {
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
        let startChar = lineText.distance(from: lineText.startIndex, to: wordStart)
        let endChar = lineText.distance(from: lineText.startIndex, to: wordEnd)

        return (word, Range(startLine: line, startCharacter: startChar, endLine: line, endCharacter: endChar))
    }

    /// Convert an offset to a position.
    public mutating func positionFromOffset(_ offset: Int) -> Position? {
        var currentOffset = 0
        for (lineNum, line) in lines.enumerated() {
            let lineLength = line.count + 1 // +1 for newline
            if currentOffset + lineLength > offset {
                return Position(line: lineNum, character: offset - currentOffset)
            }
            currentOffset += lineLength
        }
        return nil
    }

    /// Convert a position to an offset.
    public mutating func offsetFromPosition(_ position: Position) -> Int? {
        let allLines = lines
        guard position.line >= 0, position.line < allLines.count else { return nil }

        var offset = 0
        for lineNum in 0..<position.line {
            offset += allLines[lineNum].count + 1 // +1 for newline
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
