import Foundation

// MARK: - TokenizerProtocol Conformance

extension Tokenizer: BenchmarkFramework.TokenizerProtocol {
    public var name: String { "Tokenizer" }
    
    public func tokenize(_ input: String) throws -> [Token] {
        let tokenizer = Tokenizer(input: input)
        return try tokenizer.tokenize()
    }
}

extension EnhancedParsingTokenizer: BenchmarkFramework.TokenizerProtocol {
    public var name: String { "EnhancedParsingTokenizer" }
    // Uses the legacy method for protocol conformance
}

extension FastParsingTokenizer: BenchmarkFramework.TokenizerProtocol {
    public var name: String { "FastParsingTokenizer" }
    // Protocol conformance (already has tokenize method)
}

extension ParsingTokenizer: BenchmarkFramework.TokenizerProtocol {
    public var name: String { "ParsingTokenizer" }
    // Protocol conformance (already has tokenize method)
} 