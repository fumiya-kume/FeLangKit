import Testing
import Foundation
@testable import FeLangCore

/// Tests for the SemanticErrorReporter class.
/// Verifies error collection, deduplication, thread safety, and integration with ErrorFormatter.
@Suite("SemanticErrorReporter Tests")
struct SemanticErrorReporterTests {
    
    // MARK: - Basic Error Reporting
    
    @Test("Basic error reporting")
    func testBasicErrorReporting() {
        let reporter = SemanticErrorReporter()
        let pos = SourcePosition(line: 1, column: 5)
        
        // Report a simple error
        let error = SemanticError.undeclaredVariable("x", at: pos)
        let success = reporter.report(error)
        
        #expect(success == true)
        #expect(reporter.hasErrors == true)
        #expect(reporter.errorCount == 1)
        
        let errors = reporter.getErrorsSorted()
        #expect(errors.count == 1)
        #expect(errors[0] == error)
    }
    
    @Test("Basic warning reporting")
    func testBasicWarningReporting() {
        let reporter = SemanticErrorReporter()
        let pos = SourcePosition(line: 2, column: 3)
        
        // Report a simple warning
        let warning = SemanticWarning.unusedVariable("y", at: pos)
        let success = reporter.reportWarning(warning)
        
        #expect(success == true)
        #expect(reporter.hasWarnings == true)
        #expect(reporter.warningCount == 1)
        
        let warnings = reporter.getWarningsSorted()
        #expect(warnings.count == 1)
        #expect(warnings[0] == warning)
    }
    
    // MARK: - Error Deduplication
    
    @Test("Error deduplication")
    func testErrorDeduplication() {
        let reporter = SemanticErrorReporter()
        let pos = SourcePosition(line: 1, column: 5)
        let error = SemanticError.undeclaredVariable("x", at: pos)
        
        // Report the same error twice
        let success1 = reporter.report(error)
        let success2 = reporter.report(error)
        
        #expect(success1 == true)
        #expect(success2 == false)  // Duplicate should be rejected
        #expect(reporter.errorCount == 1)
    }
    
    @Test("Warning deduplication")
    func testWarningDeduplication() {
        let reporter = SemanticErrorReporter()
        let pos = SourcePosition(line: 2, column: 3)
        let warning = SemanticWarning.unusedVariable("y", at: pos)
        
        // Report the same warning twice
        let success1 = reporter.reportWarning(warning)
        let success2 = reporter.reportWarning(warning)
        
        #expect(success1 == true)
        #expect(success2 == false)  // Duplicate should be rejected
        #expect(reporter.warningCount == 1)
    }
    
    // MARK: - Error Limit
    
    @Test("Error limit enforcement")
    func testErrorLimit() {
        let reporter = SemanticErrorReporter(errorLimit: 3)
        
        // Report errors up to the limit
        for i in 1...5 {
            let pos = SourcePosition(line: i, column: 1)
            let error = SemanticError.undeclaredVariable("var\(i)", at: pos)
            let success = reporter.report(error)
            
            if i <= 3 {
                #expect(success == true)
            } else {
                #expect(success == false)  // Should reject after limit
            }
        }
        
        #expect(reporter.hasReachedErrorLimit == true)
        
        // Should have limit + 1 errors (the "too many errors" error)
        let errors = reporter.getErrorsSorted()
        #expect(errors.count == 4)
        
        // Last error should be "too many errors"
        if case .tooManyErrors(let count) = errors.last {
            #expect(count == 3)
        } else {
            Issue.record("Expected tooManyErrors as last error")
        }
    }
    
    // MARK: - Error Sorting
    
    @Test("Error sorting by position")
    func testErrorSorting() {
        let reporter = SemanticErrorReporter()
        
        // Add errors in reverse line order
        let errors = [
            SemanticError.undeclaredVariable("c", at: SourcePosition(line: 3, column: 1)),
            SemanticError.undeclaredVariable("a", at: SourcePosition(line: 1, column: 5)),
            SemanticError.undeclaredVariable("b", at: SourcePosition(line: 2, column: 3))
        ]
        
        for error in errors {
            reporter.report(error)
        }
        
        let sortedErrors = reporter.getErrorsSorted()
        #expect(sortedErrors.count == 3)
        
        // Check they're sorted by line number
        if case .undeclaredVariable(let name1, let pos1) = sortedErrors[0] {
            #expect(name1 == "a")
            #expect(pos1.line == 1)
        }
        
        if case .undeclaredVariable(let name2, let pos2) = sortedErrors[1] {
            #expect(name2 == "b")
            #expect(pos2.line == 2)
        }
        
        if case .undeclaredVariable(let name3, let pos3) = sortedErrors[2] {
            #expect(name3 == "c")
            #expect(pos3.line == 3)
        }
    }
    
    // MARK: - Result Creation
    
    @Test("Semantic analysis result creation")
    func testResultCreation() {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Add some errors and warnings
        let error = SemanticError.undeclaredVariable("x", at: SourcePosition(line: 1, column: 5))
        let warning = SemanticWarning.unusedVariable("y", at: SourcePosition(line: 2, column: 3))
        
        reporter.report(error)
        reporter.reportWarning(warning)
        
        let result = reporter.createResult(symbolTable: symbolTable)
        
        #expect(result.isSuccessful == false)  // Has errors
        #expect(result.hasErrors == true)
        #expect(result.hasWarnings == true)
        #expect(result.errors.count == 1)
        #expect(result.warnings.count == 1)
        #expect(result.issueCount == 2)
    }
    
    @Test("Successful result creation")
    func testSuccessfulResultCreation() {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Add only warnings (no errors)
        let warning = SemanticWarning.unusedVariable("y", at: SourcePosition(line: 2, column: 3))
        reporter.reportWarning(warning)
        
        let result = reporter.createResult(symbolTable: symbolTable)
        
        #expect(result.isSuccessful == true)  // No errors
        #expect(result.hasErrors == false)
        #expect(result.hasWarnings == true)
        #expect(result.errors.count == 0)
        #expect(result.warnings.count == 1)
    }
    
    // MARK: - Clear and Reset
    
    @Test("Clear functionality")
    func testClear() {
        let reporter = SemanticErrorReporter()
        
        // Add some errors and warnings
        let error = SemanticError.undeclaredVariable("x", at: SourcePosition(line: 1, column: 5))
        let warning = SemanticWarning.unusedVariable("y", at: SourcePosition(line: 2, column: 3))
        
        reporter.report(error)
        reporter.reportWarning(warning)
        
        #expect(reporter.hasErrors == true)
        #expect(reporter.hasWarnings == true)
        
        // Clear and verify
        reporter.clear()
        
        #expect(reporter.hasErrors == false)
        #expect(reporter.hasWarnings == false)
        #expect(reporter.errorCount == 0)
        #expect(reporter.warningCount == 0)
    }
    
    // MARK: - Thread Safety
    
    @Test("Thread safety")
    func testThreadSafety() async {
        let reporter = SemanticErrorReporter()
        let errorCount = 50
        
        // Create multiple tasks that report errors concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<errorCount {
                group.addTask {
                    let pos = SourcePosition(line: i + 1, column: 1)
                    let error = SemanticError.undeclaredVariable("var\(i)", at: pos)
                    reporter.report(error)
                }
            }
        }
        
        // All errors should be reported (no race conditions)
        #expect(reporter.errorCount == errorCount)
        
        let errors = reporter.getErrorsSorted()
        #expect(errors.count == errorCount)
    }
}