import Testing
@testable import FeLangCore

@Suite("LookupTable Tests")
struct LookupTableTests {

    // MARK: - Operator First Char Map Tests

    @Test func testOperatorMapContainsAllOperators() throws {
        for (opString, tokenType) in TokenizerUtilities.operators {
            guard let firstChar = opString.first else { continue }
            let candidates = TokenizerUtilities.operatorFirstCharMap[firstChar]
            #expect(candidates != nil, "Missing key '\(firstChar)' for operator '\(opString)'")
            let found = candidates?.contains { $0.0 == opString && $0.1 == tokenType } ?? false
            #expect(found, "Operator '\(opString)' not found in map for key '\(firstChar)'")
        }
    }

    @Test func testOperatorMapSortedLongestFirst() throws {
        for (_, candidates) in TokenizerUtilities.operatorFirstCharMap {
            for idx in 0..<(candidates.count - 1) {
                #expect(
                    candidates[idx].0.count >= candidates[idx + 1].0.count,
                    "'\(candidates[idx].0)' (len \(candidates[idx].0.count)) should not be before '\(candidates[idx + 1].0)' (len \(candidates[idx + 1].0.count))"
                )
            }
        }
    }

    @Test func testOperatorMapLongestMatchOrder() throws {
        // "!" key should have "!=" before "!"
        if let bangCandidates = TokenizerUtilities.operatorFirstCharMap["!"] {
            let notEqualIdx = bangCandidates.firstIndex { $0.0 == "!=" }
            let notIdx = bangCandidates.firstIndex { $0.0 == "!" }
            if let neIdx = notEqualIdx, let nIdx = notIdx {
                #expect(neIdx < nIdx, "'!=' should appear before '!' in candidates")
            }
        }

        // "<" key should have multi-char operators before "<"
        if let lessCandidates = TokenizerUtilities.operatorFirstCharMap["<"] {
            let singleIdx = lessCandidates.firstIndex { $0.0 == "<" }
            if let sIdx = singleIdx {
                // All multi-char operators should appear before single "<"
                for idx in 0..<sIdx {
                    #expect(lessCandidates[idx].0.count > 1)
                }
            }
        }
    }

    @Test func testOperatorMapUnknownCharReturnsNil() throws {
        #expect(TokenizerUtilities.operatorFirstCharMap["@"] == nil)
        #expect(TokenizerUtilities.operatorFirstCharMap["#"] == nil)
        #expect(TokenizerUtilities.operatorFirstCharMap["$"] == nil)
    }

    @Test func testOperatorMapUnicodeOperators() throws {
        // ← (assign)
        let assignCandidates = TokenizerUtilities.operatorFirstCharMap["←"]
        #expect(assignCandidates != nil)
        #expect(assignCandidates?.contains { $0.0 == "←" && $0.1 == .assign } == true)

        // ≠ (notEqual)
        let neqCandidates = TokenizerUtilities.operatorFirstCharMap["≠"]
        #expect(neqCandidates != nil)
        #expect(neqCandidates?.contains { $0.0 == "≠" && $0.1 == .notEqual } == true)

        // ÷ (divide)
        let divCandidates = TokenizerUtilities.operatorFirstCharMap["÷"]
        #expect(divCandidates != nil)
        #expect(divCandidates?.contains { $0.0 == "÷" && $0.1 == .divide } == true)
    }

    // MARK: - Delimiter Map Tests

    @Test func testDelimiterMapContainsAllDelimiters() throws {
        for (delimiter, tokenType) in TokenizerUtilities.delimiters {
            guard let firstChar = delimiter.first else { continue }
            #expect(
                TokenizerUtilities.delimiterMap[firstChar] == tokenType,
                "Delimiter '\(delimiter)' not correctly mapped"
            )
        }
    }

    @Test func testDelimiterMapDirectLookup() throws {
        #expect(TokenizerUtilities.delimiterMap["("] == .leftParen)
        #expect(TokenizerUtilities.delimiterMap[")"] == .rightParen)
        #expect(TokenizerUtilities.delimiterMap["["] == .leftBracket)
        #expect(TokenizerUtilities.delimiterMap["]"] == .rightBracket)
        #expect(TokenizerUtilities.delimiterMap["{"] == .leftBrace)
        #expect(TokenizerUtilities.delimiterMap["}"] == .rightBrace)
        #expect(TokenizerUtilities.delimiterMap[","] == .comma)
        #expect(TokenizerUtilities.delimiterMap["."] == .dot)
        #expect(TokenizerUtilities.delimiterMap[";"] == .semicolon)
        #expect(TokenizerUtilities.delimiterMap[":"] == .colon)
    }

    @Test func testDelimiterMapUnknownCharReturnsNil() throws {
        #expect(TokenizerUtilities.delimiterMap["@"] == nil)
        #expect(TokenizerUtilities.delimiterMap["a"] == nil)
        #expect(TokenizerUtilities.delimiterMap["1"] == nil)
        #expect(TokenizerUtilities.delimiterMap["+"] == nil)
    }

    @Test func testDelimiterMapCount() throws {
        #expect(TokenizerUtilities.delimiterMap.count == TokenizerUtilities.delimiters.count)
    }

    @Test func testOperatorMapNoMissingEntries() throws {
        // Reverse check: all entries in the map exist in the operators array
        for (_, candidates) in TokenizerUtilities.operatorFirstCharMap {
            for (opString, tokenType) in candidates {
                let found = TokenizerUtilities.operators.contains { $0.0 == opString && $0.1 == tokenType }
                #expect(found, "Map entry '\(opString)' not found in operators array")
            }
        }
    }
}
