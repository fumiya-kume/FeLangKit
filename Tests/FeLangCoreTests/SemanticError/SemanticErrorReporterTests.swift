import Testing
import Foundation
@testable import FeLangCore

/// Comprehensive tests for SemanticErrorReporter functionality.
/// This test suite validates error collection, deduplication, thread safety,
/// and integration with the broader semantic analysis infrastructure.
@Suite("SemanticErrorReporter Tests")
struct SemanticErrorReporterTests {

    // MARK: - Basic Error Reporting Tests

    @Test("Error Reporting - Basic functionality")
    func testBasicErrorReporting() async throws {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 5)
        
        // Test initial state
        #expect(!reporter.hasErrors)
        #expect(reporter.errorCount == 0)
        
        // Report an error
        let error = SemanticError.undeclaredVariable("x", at: position)
        let added = reporter.report(error)
        
        #expect(added)
        #expect(reporter.hasErrors)
        #expect(reporter.errorCount == 1)
        
        let errors = reporter.getErrorsSorted()
        #expect(errors.count == 1)
        #expect(errors[0] == error)
    }

    @Test("Warning Reporting - Basic functionality")
    func testBasicWarningReporting() async throws {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 5)
        
        // Test initial state
        #expect(!reporter.hasWarnings)
        #expect(reporter.warningCount == 0)
        
        // Report a warning
        let warning = SemanticWarning.unusedVariable("y", at: position)
        let added = reporter.reportWarning(warning)
        
        #expect(added)
        #expect(reporter.hasWarnings)
        #expect(reporter.warningCount == 1)
        
        let warnings = reporter.getWarningsSorted()
        #expect(warnings.count == 1)
        #expect(warnings[0] == warning)
    }

    // MARK: - Deduplication Tests

    @Test("Error Deduplication - Same position")
    func testErrorDeduplicationSamePosition() async throws {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 5)
        
        // Report multiple errors at the same position
        let error1 = SemanticError.undeclaredVariable("x", at: position)
        let error2 = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)
        
        let added1 = reporter.report(error1)
        let added2 = reporter.report(error2)
        
        #expect(added1)
        #expect(!added2) // Second error should be deduplicated
        #expect(reporter.errorCount == 1)
    }

    @Test("Error Deduplication - Different positions")
    func testErrorDeduplicationDifferentPositions() async throws {
        let reporter = SemanticErrorReporter()
        let position1 = SourcePosition(line: 1, column: 5)
        let position2 = SourcePosition(line: 2, column: 10)
        
        // Report errors at different positions
        let error1 = SemanticError.undeclaredVariable("x", at: position1)
        let error2 = SemanticError.undeclaredVariable("y", at: position2)
        
        let added1 = reporter.report(error1)
        let added2 = reporter.report(error2)
        
        #expect(added1)
        #expect(added2)
        #expect(reporter.errorCount == 2)
    }

    @Test("Warning Deduplication - Identical warnings")
    func testWarningDeduplication() async throws {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 5)
        
        // Report identical warnings
        let warning = SemanticWarning.unusedVariable("x", at: position)
        
        let added1 = reporter.reportWarning(warning)
        let added2 = reporter.reportWarning(warning)
        
        #expect(added1)
        #expect(!added2) // Second warning should be deduplicated
        #expect(reporter.warningCount == 1)
    }

    // MARK: - Error Limit Tests

    @Test("Error Limit - Enforcement")
    func testErrorLimitEnforcement() async throws {
        let maxErrors = 5
        let reporter = SemanticErrorReporter(maxErrors: maxErrors)
        
        // Report errors up to the limit
        for i in 1...maxErrors {
            let position = SourcePosition(line: i, column: 1)
            let error = SemanticError.undeclaredVariable("var\(i)", at: position)
            let added = reporter.report(error)
            #expect(added)
        }
        
        #expect(reporter.errorCount == maxErrors)
        #expect(!reporter.isStopped)
        
        // Report one more error - should trigger the limit
        let extraPosition = SourcePosition(line: maxErrors + 1, column: 1)
        let extraError = SemanticError.undeclaredVariable("extraVar", at: extraPosition)
        let added = reporter.report(extraError)
        
        #expect(!added)
        #expect(reporter.isStopped)
        #expect(reporter.errorCount == maxErrors + 1) // Includes tooManyErrors
        
        // Check that the last error is tooManyErrors
        let errors = reporter.getErrorsSorted()
        let lastError = errors.last
        if case .tooManyErrors(let count) = lastError {
            #expect(count == maxErrors)
        } else {
            Issue.record("Expected tooManyErrors as last error")
        }
    }

    @Test("Warning Limit - Enforcement")
    func testWarningLimitEnforcement() async throws {
        let maxWarnings = 3
        let reporter = SemanticErrorReporter(maxWarnings: maxWarnings)
        
        // Report warnings up to the limit
        for i in 1...maxWarnings {
            let position = SourcePosition(line: i, column: 1)
            let warning = SemanticWarning.unusedVariable("var\(i)", at: position)
            let added = reporter.reportWarning(warning)
            #expect(added)
        }
        
        #expect(reporter.warningCount == maxWarnings)
        
        // Report one more warning - should be rejected
        let extraPosition = SourcePosition(line: maxWarnings + 1, column: 1)
        let extraWarning = SemanticWarning.unusedVariable("extraVar", at: extraPosition)
        let added = reporter.reportWarning(extraWarning)
        
        #expect(!added)
        #expect(reporter.warningCount == maxWarnings)
    }

    // MARK: - Batch Operations Tests

    @Test("Batch Error Reporting")
    func testBatchErrorReporting() async throws {
        let reporter = SemanticErrorReporter()
        
        let errors = [
            SemanticError.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1)),
            SemanticError.undeclaredVariable("y", at: SourcePosition(line: 2, column: 1)),
            SemanticError.typeMismatch(expected: .integer, actual: .string, at: SourcePosition(line: 3, column: 1))
        ]
        
        let addedCount = reporter.reportBatch(errors)
        
        #expect(addedCount == 3)
        #expect(reporter.errorCount == 3)
        
        let reportedErrors = reporter.getErrorsSorted()
        #expect(reportedErrors.count == 3)
    }

    @Test("Batch Error Reporting - With limit")
    func testBatchErrorReportingWithLimit() async throws {
        let maxErrors = 2
        let reporter = SemanticErrorReporter(maxErrors: maxErrors)
        
        let errors = [
            SemanticError.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1)),
            SemanticError.undeclaredVariable("y", at: SourcePosition(line: 2, column: 1)),
            SemanticError.undeclaredVariable("z", at: SourcePosition(line: 3, column: 1))
        ]
        
        let addedCount = reporter.reportBatch(errors)
        
        #expect(addedCount == 2) // Only first 2 should be added
        #expect(reporter.isStopped)
        #expect(reporter.errorCount == 3) // Includes tooManyErrors
    }

    // MARK: - Sorting Tests

    @Test("Error Sorting - By position")
    func testErrorSortingByPosition() async throws {
        let reporter = SemanticErrorReporter()
        
        // Add errors in reverse order
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
        
        // Verify they are sorted by line number
        if case .undeclaredVariable("a", _) = sortedErrors[0] {} else {
            Issue.record("Expected first error to be 'a'")
        }
        if case .undeclaredVariable("b", _) = sortedErrors[1] {} else {
            Issue.record("Expected second error to be 'b'")
        }
        if case .undeclaredVariable("c", _) = sortedErrors[2] {} else {
            Issue.record("Expected third error to be 'c'")
        }
    }

    @Test("Warning Sorting - By position")
    func testWarningSortingByPosition() async throws {
        let reporter = SemanticErrorReporter()
        
        // Add warnings in reverse order
        let warnings = [
            SemanticWarning.unusedVariable("c", at: SourcePosition(line: 3, column: 1)),
            SemanticWarning.unusedVariable("a", at: SourcePosition(line: 1, column: 5)),
            SemanticWarning.unusedVariable("b", at: SourcePosition(line: 2, column: 3))
        ]
        
        for warning in warnings {
            reporter.reportWarning(warning)
        }
        
        let sortedWarnings = reporter.getWarningsSorted()
        #expect(sortedWarnings.count == 3)
        
        // Verify they are sorted by line number
        if case .unusedVariable("a", _) = sortedWarnings[0] {} else {
            Issue.record("Expected first warning to be 'a'")
        }
        if case .unusedVariable("b", _) = sortedWarnings[1] {} else {
            Issue.record("Expected second warning to be 'b'")
        }
        if case .unusedVariable("c", _) = sortedWarnings[2] {} else {
            Issue.record("Expected third warning to be 'c'")
        }
    }

    // MARK: - Filtering Tests

    @Test("Error Filtering - By category")
    func testErrorFiltering() async throws {
        let reporter = SemanticErrorReporter()
        
        // Add various types of errors
        reporter.report(.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1)))
        reporter.report(.typeMismatch(expected: .integer, actual: .string, at: SourcePosition(line: 2, column: 1)))
        reporter.report(.undeclaredFunction("foo", at: SourcePosition(line: 3, column: 1)))
        
        // Test category filters
        let typeErrors = reporter.typeErrors
        let scopeErrors = reporter.scopeErrors
        let functionErrors = reporter.functionErrors
        
        #expect(typeErrors.count == 1)
        #expect(scopeErrors.count == 1)
        #expect(functionErrors.count == 1)
        
        // Test custom filter
        let undeclaredErrors = reporter.getErrors { error in
            switch error {
            case .undeclaredVariable, .undeclaredFunction:
                return true
            default:
                return false
            }
        }
        
        #expect(undeclaredErrors.count == 2)
    }

    // MARK: - Analysis Result Tests

    @Test("Analysis Result Creation")
    func testAnalysisResultCreation() async throws {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Add some errors and warnings
        reporter.report(.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1)))
        reporter.reportWarning(.unusedVariable("y", at: SourcePosition(line: 2, column: 1)))
        
        let result = reporter.createAnalysisResult(symbolTable: symbolTable)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        #expect(result.hasWarnings)
        #expect(result.errors.count == 1)
        #expect(result.warnings.count == 1)
        #expect(result.issueCount == 2)
    }

    @Test("Analysis Result - Success case")
    func testAnalysisResultSuccess() async throws {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Add only warnings
        reporter.reportWarning(.unusedVariable("y", at: SourcePosition(line: 1, column: 1)))
        
        let result = reporter.createAnalysisResult(symbolTable: symbolTable)
        
        #expect(result.isSuccessful) // Success if no errors, even with warnings
        #expect(!result.hasErrors)
        #expect(result.hasWarnings)
        #expect(result.errors.count == 0)
        #expect(result.warnings.count == 1)
    }

    // MARK: - Utility Tests

    @Test("Reporter Reset")
    func testReporterReset() async throws {
        let reporter = SemanticErrorReporter()
        
        // Add some errors and warnings
        reporter.report(.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1)))
        reporter.reportWarning(.unusedVariable("y", at: SourcePosition(line: 2, column: 1)))
        
        #expect(reporter.hasErrors)
        #expect(reporter.hasWarnings)
        
        // Reset the reporter
        reporter.reset()
        
        #expect(!reporter.hasErrors)
        #expect(!reporter.hasWarnings)
        #expect(reporter.errorCount == 0)
        #expect(reporter.warningCount == 0)
        #expect(!reporter.isStopped)
    }

    @Test("Summary Generation")
    func testSummaryGeneration() async throws {
        let reporter = SemanticErrorReporter()
        
        // Test empty state
        var summary = reporter.createSummary()
        #expect(summary == "No semantic issues found")
        
        // Add errors only
        reporter.report(.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1)))
        summary = reporter.createSummary()
        #expect(summary.contains("1 error"))
        
        // Add warnings
        reporter.reportWarning(.unusedVariable("y", at: SourcePosition(line: 2, column: 1)))
        summary = reporter.createSummary()
        #expect(summary.contains("1 error"))
        #expect(summary.contains("1 warning"))
        
        // Add more errors
        reporter.report(.undeclaredFunction("foo", at: SourcePosition(line: 3, column: 1)))
        summary = reporter.createSummary()
        #expect(summary.contains("2 errors"))
        #expect(summary.contains("1 warning"))
    }

    // MARK: - Thread Safety Tests

    @Test("Thread Safety - Concurrent error reporting")
    func testThreadSafetyConcurrentReporting() async throws {
        let reporter = SemanticErrorReporter(maxErrors: 1000, maxWarnings: 1000)
        let group = DispatchGroup()
        let iterations = 100
        
        // Concurrently report errors from multiple threads
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let position = SourcePosition(line: i + 1, column: 1)
                let error = SemanticError.undeclaredVariable("var\(i)", at: position)
                reporter.report(error)
                
                let warning = SemanticWarning.unusedVariable("unused\(i)", at: position)
                reporter.reportWarning(warning)
                
                group.leave()
            }
        }
        
        group.wait()
        
        // Verify all errors and warnings were reported
        #expect(reporter.errorCount == iterations)
        #expect(reporter.warningCount == iterations)
        
        let errors = reporter.getErrorsSorted()
        let warnings = reporter.getWarningsSorted()
        
        #expect(errors.count == iterations)
        #expect(warnings.count == iterations)
    }
}