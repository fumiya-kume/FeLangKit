/// Groups the context needed for incremental token update operations.
struct IncrementalUpdateContext {
    let range: Range<String.Index>
    let newText: String
    let previousTokens: [Token]
    let originalText: String
    let newFullText: String
    let startOffset: Int
    let endOffset: Int
}
