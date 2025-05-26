/// Represents a position in source code with line, column, and offset information.
public struct SourcePosition: Equatable, Hashable, Codable, Sendable {
    /// The line number (1-indexed)
    public let line: Int

    /// The column number (1-indexed)
    public let column: Int

    /// The scalar offset (count of Unicode scalars) from the start of the source (0-indexed)
    public let offset: Int

    /// Creates a new source position.
    /// - Parameters:
    ///   - line: The line number (1-indexed)
    ///   - column: The column number (1-indexed)
    ///   - offset: The scalar offset (count of Unicode scalars) from the start (0-indexed)
    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }
    
    /// Creates a new source position with line and column only (offset defaults to 0).
    /// - Parameters:
    ///   - line: The line number (1-indexed)
    ///   - column: The column number (1-indexed)
    public init(line: Int, column: Int) {
        self.init(line: line, column: column, offset: 0)
    }
}

extension SourcePosition: CustomStringConvertible {
    public var description: String {
        return "\(line):\(column)"
    }
}
