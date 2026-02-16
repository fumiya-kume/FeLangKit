/// A node in the concrete syntax tree (CST).
///
/// Every node records the token range it covers so that source positions
/// can be recovered without storing redundant copies of position data.
/// Leaf nodes wrap a single token; internal nodes contain ordered children.
public struct SyntaxNode: Equatable, Sendable {
    public let kind: SyntaxKind
    public let children: [SyntaxNode]
    public let tokenIndex: Int?
    public let startTokenIndex: Int
    public let endTokenIndex: Int

    /// Creates a leaf node that wraps a single token.
    public init(token index: Int) {
        self.kind = .token
        self.children = []
        self.tokenIndex = index
        self.startTokenIndex = index
        self.endTokenIndex = index + 1
    }

    /// Creates an internal node with the given kind and children.
    public init(kind: SyntaxKind, children: [SyntaxNode]) {
        self.kind = kind
        self.children = children
        self.tokenIndex = nil
        if let first = children.first, let last = children.last {
            self.startTokenIndex = first.startTokenIndex
            self.endTokenIndex = last.endTokenIndex
        } else {
            self.startTokenIndex = 0
            self.endTokenIndex = 0
        }
    }

    /// Creates an internal node with explicit token range (useful for empty nodes).
    public init(kind: SyntaxKind, children: [SyntaxNode], startTokenIndex: Int, endTokenIndex: Int) {
        self.kind = kind
        self.children = children
        self.tokenIndex = nil
        self.startTokenIndex = startTokenIndex
        self.endTokenIndex = endTokenIndex
    }
}

// MARK: - Child Access Helpers

extension SyntaxNode {
    /// Returns the first child matching the given kind, or `nil`.
    public func firstChild(ofKind kind: SyntaxKind) -> SyntaxNode? {
        children.first { $0.kind == kind }
    }

    /// Returns all children matching the given kind.
    public func children(ofKind kind: SyntaxKind) -> [SyntaxNode] {
        children.filter { $0.kind == kind }
    }

    /// Returns all direct children whose kind satisfies the predicate.
    public func children(where predicate: (SyntaxKind) -> Bool) -> [SyntaxNode] {
        children.filter { predicate($0.kind) }
    }

    /// Returns the token nodes among the direct children.
    public var tokens: [SyntaxNode] {
        children.filter { $0.kind == .token }
    }

    /// Whether this node is a leaf (wraps a single token).
    public var isToken: Bool {
        kind == .token
    }

    /// The number of tokens covered by this subtree.
    public var tokenCount: Int {
        endTokenIndex - startTokenIndex
    }
}

// MARK: - Debug Description

extension SyntaxNode: CustomDebugStringConvertible {
    public var debugDescription: String {
        buildDescription(indent: 0)
    }

    private func buildDescription(indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)
        if isToken {
            return "\(prefix)token[\(startTokenIndex)]"
        }
        var result = "\(prefix)\(kind.rawValue)"
        if !children.isEmpty {
            result += " {\n"
            for child in children {
                result += child.buildDescription(indent: indent + 1) + "\n"
            }
            result += "\(prefix)}"
        }
        return result
    }
}
