// The Swift Programming Language
// https://docs.swift.org/swift-book

/// FeLangCore provides the core functionality for the FE pseudo-language toolkit.
/// This includes tokenization, parsing, and AST representation.
///
/// # Usage Example
/// ```
/// import FeLangCore
///
/// let tokenizer = Tokenizer(input: "example code")
/// let tokens = tokenizer.tokenize()
/// let parser = Parser(tokens: tokens)
/// let ast = parser.parse()
/// print(ast)
/// ```
///
/// # Public API
/// - `Tokenizer`: Used for breaking input strings into tokens.
/// - `Parser`: Converts tokens into an abstract syntax tree (AST).
/// - `ASTNode`: Represents nodes in the abstract syntax tree.
/// - `PrettyPrinter`: Converts AST nodes back to canonical FE pseudo-language source code.
///
/// # PrettyPrinter Features
/// - Supports all AST node types (expressions, statements, literals)
/// - Generates properly formatted, syntactically correct code
/// - Enables round-trip validation (source → AST → source)
/// - Configurable formatting options (indentation, spaces/tabs)
/// - Japanese keywords and Unicode operators support
///
/// For more details, refer to the [API Documentation](https://example.com/api-docs).
