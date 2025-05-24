/// Represents a token in FE pseudo-language source code.
public struct Token: Equatable, Codable, Sendable {
    /// The type of this token
    public let type: TokenType
    
    /// The original text that produced this token
    public let lexeme: String
    
    /// The position of this token in the source code
    public let position: SourcePosition
    
    /// Creates a new token.
    /// - Parameters:
    ///   - type: The type of the token
    ///   - lexeme: The original text that produced this token
    ///   - position: The position in the source code
    public init(type: TokenType, lexeme: String, position: SourcePosition) {
        self.type = type
        self.lexeme = lexeme
        self.position = position
    }
}

extension Token: CustomStringConvertible {
    public var description: String {
        return "\(type)('\(lexeme)') at \(position)"
    }
}

extension Token: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Token(type: .\(type), lexeme: \"\(lexeme)\", position: \(position))"
    }
} 