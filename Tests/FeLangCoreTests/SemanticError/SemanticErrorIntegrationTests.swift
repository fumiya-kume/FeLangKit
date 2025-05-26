import Testing
import Foundation
@testable import FeLangCore

/// Integration tests for the complete semantic error reporting system.
/// This test suite validates the end-to-end functionality of semantic error detection,
/// collection, formatting, and reporting within the broader FeLangCore ecosystem.
@Suite("SemanticError Integration Tests")
struct SemanticErrorIntegrationTests {

    // MARK: - Complete Workflow Tests

    @Test("Complete Semantic Analysis Workflow")
    func testCompleteSemanticAnalysisWorkflow() async throws {
        // Create components
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Simulate semantic analysis discovering errors
        
        // 1. Declare some variables
        symbolTable.declare(name: "x", type: .integer, kind: .variable, at: SourcePosition(line: 1, column: 1))
        symbolTable.declare(name: "y", type: .string, kind: .variable, at: SourcePosition(line: 2, column: 1))
        
        // 2. Report type mismatch error
        let typeMismatchError = SemanticError.typeMismatch(
            expected: .integer, 
            actual: .string, 
            at: SourcePosition(line: 3, column: 5)
        )
        reporter.report(typeMismatchError)
        
        // 3. Report undeclared variable
        let undeclaredError = SemanticError.undeclaredVariable("z", at: SourcePosition(line: 4, column: 10))
        reporter.report(undeclaredError)
        
        // 4. Report warning
        let unusedWarning = SemanticWarning.unusedVariable("temp", at: SourcePosition(line: 5, column: 1))
        reporter.reportWarning(unusedWarning)
        
        // 5. Create analysis result
        let result = reporter.createAnalysisResult(symbolTable: symbolTable)
        
        // Validate the complete workflow
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        #expect(result.hasWarnings)
        #expect(result.errors.count == 2)
        #expect(result.warnings.count == 1)
        
        // Test error formatting
        let formattedErrors = result.errors.map { ErrorFormatter.format($0) }
        #expect(formattedErrors.allSatisfy { $0.contains("SemanticError") })
        
        // Test summary generation
        let summary = reporter.createSummary()
        #expect(summary.contains("2 errors"))
        #expect(summary.contains("1 warning"))
    }

    @Test("Error Reporter with Symbol Table Context")
    func testErrorReporterWithSymbolTableContext() async throws {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Add variables with similar names
        symbolTable.declare(name: "userName", type: .string, kind: .variable, at: SourcePosition(line: 1, column: 1))
        symbolTable.declare(name: "userAge", type: .integer, kind: .variable, at: SourcePosition(line: 1, column: 15))
        symbolTable.declare(name: "userId", type: .integer, kind: .variable, at: SourcePosition(line: 1, column: 30))
        
        // Report error for similar variable name
        let error = SemanticError.undeclaredVariable("usrName", at: SourcePosition(line: 2, column: 5))
        reporter.report(error)
        
        // Test formatting with symbol table context
        let sourceCode = """
        var userName: string; var userAge: integer; var userId: integer;
        x = usrName;
        """
        
        let formatted = ErrorFormatter.formatWithContext(error, input: sourceCode, symbolTable: symbolTable)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Undeclared variable 'usrName'"))
        #expect(formatted.contains("Source context"))
        #expect(formatted.contains("x = usrName;"))
        
        // Check for similar name suggestions
        let similarNames = symbolTable.findSimilarNames(to: "usrName", type: .variable)
        #expect(!similarNames.isEmpty)
        #expect(similarNames.contains("userName"))
    }

    @Test("Type Conversion Suggestions Integration")
    func testTypeConversionSuggestionsIntegration() async throws {
        let symbolTable = SymbolTable()
        
        // Test various type conversion scenarios
        let testCases: [(FeType, FeType, String)] = [
            (.integer, .string, "string interpolation"),
            (.real, .integer, "explicit casting"),
            (.boolean, .string, "string interpolation"),
            (.character, .string, "automatically converted")
        ]
        
        for (fromType, toType, expectedSuggestion) in testCases {
            let suggestion = symbolTable.suggestTypeConversion(from: fromType, to: toType)
            #expect(suggestion?.contains(expectedSuggestion) == true, 
                   "Expected suggestion for \(fromType) to \(toType) to contain '\(expectedSuggestion)'")
        }
    }

    // MARK: - Error Limit and Recovery Tests

    @Test("Error Limit Handling in Analysis")
    func testErrorLimitHandlingInAnalysis() async throws {
        let maxErrors = 5
        let reporter = SemanticErrorReporter(maxErrors: maxErrors)
        
        // Simulate analysis that discovers many errors
        for i in 1...10 {
            let position = SourcePosition(line: i, column: 1)
            let error = SemanticError.undeclaredVariable("var\(i)", at: position)
            reporter.report(error)
            
            if reporter.isStopped {
                break
            }
        }
        
        #expect(reporter.isStopped)
        #expect(reporter.errorCount == maxErrors + 1) // +1 for tooManyErrors
        
        // Verify the last error is tooManyErrors
        let errors = reporter.getErrorsSorted()
        if case .tooManyErrors(let count) = errors.last {
            #expect(count == maxErrors)
        } else {
            Issue.record("Expected last error to be tooManyErrors")
        }
        
        // Test that analysis can still create a result
        let symbolTable = SymbolTable()
        let result = reporter.createAnalysisResult(symbolTable: symbolTable)
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
    }

    @Test("Error Deduplication in Real Analysis")
    func testErrorDeduplicationInRealAnalysis() async throws {
        let reporter = SemanticErrorReporter()
        
        // Simulate analysis that might discover the same error multiple times
        let position = SourcePosition(line: 5, column: 10)
        
        // Report the same logical error multiple times (same position)
        reporter.report(.undeclaredVariable("x", at: position))
        reporter.report(.typeMismatch(expected: .integer, actual: .string, at: position))
        reporter.report(.invalidAssignmentTarget(at: position))
        
        // Only the first error should be kept due to position-based deduplication
        #expect(reporter.errorCount == 1)
        
        // But errors at different positions should all be kept
        reporter.report(.undeclaredVariable("y", at: SourcePosition(line: 6, column: 5)))
        reporter.report(.undeclaredVariable("z", at: SourcePosition(line: 7, column: 8)))
        
        #expect(reporter.errorCount == 3)
    }

    // MARK: - Performance and Scalability Tests

    @Test("Large Scale Error Reporting Performance")
    func testLargeScaleErrorReportingPerformance() async throws {
        let reporter = SemanticErrorReporter(maxErrors: 10000, maxWarnings: 5000)
        let startTime = Date()
        
        // Report a large number of errors and warnings
        for i in 1...1000 {
            let position = SourcePosition(line: i, column: 1)
            
            // Report error
            let error = SemanticError.undeclaredVariable("var\(i)", at: position)
            reporter.report(error)
            
            // Report warning
            let warning = SemanticWarning.unusedVariable("unused\(i)", at: position)
            reporter.reportWarning(warning)
        }
        
        let reportingTime = Date().timeIntervalSince(startTime)
        
        // Test sorting performance
        let sortingStartTime = Date()
        let sortedErrors = reporter.getErrorsSorted()
        let sortedWarnings = reporter.getWarningsSorted()
        let sortingTime = Date().timeIntervalSince(sortingStartTime)
        
        // Test formatting performance
        let formattingStartTime = Date()
        for error in sortedErrors.prefix(100) {
            _ = ErrorFormatter.format(error)
        }
        let formattingTime = Date().timeIntervalSince(formattingStartTime)
        
        // Verify performance benchmarks
        #expect(reportingTime < 0.5, "Error reporting should be fast")
        #expect(sortingTime < 0.1, "Error sorting should be fast")
        #expect(formattingTime < 0.1, "Error formatting should be fast")
        
        // Verify correctness
        #expect(reporter.errorCount == 1000)
        #expect(reporter.warningCount == 1000)
        #expect(sortedErrors.count == 1000)
        #expect(sortedWarnings.count == 1000)
    }

    // MARK: - Real-world Scenario Tests

    @Test("Complex Program Analysis Simulation")
    func testComplexProgramAnalysisSimulation() async throws {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Simulate analyzing a complex program with multiple scopes
        
        // Global scope
        symbolTable.declare(name: "globalVar", type: .integer, kind: .variable, at: SourcePosition(line: 1, column: 1))
        symbolTable.declare(name: "PI", type: .real, kind: .constant, at: SourcePosition(line: 2, column: 1))
        
        // Function declarations
        symbolTable.declare(
            name: "calculateArea", 
            type: .function(parameters: [.real], returnType: .real), 
            kind: .function, 
            at: SourcePosition(line: 4, column: 1)
        )
        
        // Enter function scope
        symbolTable.enterScope("calculateArea")
        symbolTable.declare(name: "radius", type: .real, kind: .parameter, at: SourcePosition(line: 4, column: 20))
        
        // Errors in function
        reporter.report(.typeMismatch(expected: .real, actual: .integer, at: SourcePosition(line: 5, column: 10)))
        reporter.report(.undeclaredVariable("area", at: SourcePosition(line: 6, column: 5)))
        
        // Exit function scope
        symbolTable.exitScope()
        
        // Main program errors
        reporter.report(.incorrectArgumentCount(
            function: "calculateArea", 
            expected: 1, 
            actual: 2, 
            at: SourcePosition(line: 10, column: 15)
        ))
        
        reporter.report(.constantReassignment("PI", at: SourcePosition(line: 11, column: 1)))
        
        // Warnings
        reporter.reportWarning(.unusedVariable("temp", at: SourcePosition(line: 12, column: 1)))
        
        // Create final result
        let result = reporter.createAnalysisResult(symbolTable: symbolTable)
        
        // Validate complex analysis results
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 4)
        #expect(result.warnings.count == 1)
        
        // Verify error categories
        let typeErrors = reporter.typeErrors
        let scopeErrors = reporter.scopeErrors
        let functionErrors = reporter.functionErrors
        
        #expect(typeErrors.count == 1)
        #expect(scopeErrors.count == 2) // undeclaredVariable + constantReassignment
        #expect(functionErrors.count == 1)
        
        // Test comprehensive error reporting
        let allErrors = reporter.getErrorsSorted()
        for error in allErrors {
            let formatted = ErrorFormatter.formatWithContext(error, symbolTable: symbolTable)
            #expect(formatted.contains("SemanticError"))
            #expect(!formatted.isEmpty)
        }
    }

    @Test("Error Recovery and Continued Analysis")
    func testErrorRecoveryAndContinuedAnalysis() async throws {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Simulate analysis that encounters errors but continues
        
        // 1. Encounter type error but continue
        reporter.report(.typeMismatch(expected: .integer, actual: .string, at: SourcePosition(line: 1, column: 5)))
        
        // 2. Analysis continues and finds more errors
        reporter.report(.undeclaredFunction("unknownFunc", at: SourcePosition(line: 2, column: 10)))
        
        // 3. Analysis discovers warnings too
        reporter.reportWarning(.implicitTypeConversion(
            from: .integer, 
            to: .real, 
            at: SourcePosition(line: 3, column: 8)
        ))
        
        // 4. More errors in different parts
        reporter.report(.breakOutsideLoop(at: SourcePosition(line: 4, column: 3)))
        
        // Verify that analysis can continue despite errors
        #expect(reporter.hasErrors)
        #expect(reporter.hasWarnings)
        #expect(!reporter.isStopped)
        
        // Create result and verify all issues are captured
        let result = reporter.createAnalysisResult(symbolTable: symbolTable)
        #expect(result.errors.count == 3)
        #expect(result.warnings.count == 1)
        #expect(result.issueCount == 4)
        
        // Verify that error formatting works for all errors
        for error in result.errors {
            let formatted = ErrorFormatter.format(error)
            #expect(!formatted.isEmpty)
        }
        
        for warning in result.warnings {
            let description = warning.description
            #expect(!description.isEmpty)
        }
    }

    // MARK: - Thread Safety Integration Tests

    @Test("Concurrent Error Reporting in Analysis")
    func testConcurrentErrorReportingInAnalysis() async throws {
        let reporter = SemanticErrorReporter(maxErrors: 1000, maxWarnings: 1000)
        let group = DispatchGroup()
        let iterations = 50
        
        // Simulate concurrent semantic analysis phases
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                // Each "analysis phase" reports different types of errors
                let basePosition = SourcePosition(line: i * 10, column: 1)
                
                // Type checking phase
                reporter.report(.typeMismatch(
                    expected: .integer, 
                    actual: .string, 
                    at: SourcePosition(line: basePosition.line + 1, column: 1)
                ))
                
                // Scope checking phase
                reporter.report(.undeclaredVariable(
                    "var\(i)", 
                    at: SourcePosition(line: basePosition.line + 2, column: 1)
                ))
                
                // Function checking phase
                reporter.reportWarning(.unusedFunction(
                    "func\(i)", 
                    at: SourcePosition(line: basePosition.line + 3, column: 1)
                ))
                
                group.leave()
            }
        }
        
        group.wait()
        
        // Verify all errors were recorded correctly
        #expect(reporter.errorCount == iterations * 2)
        #expect(reporter.warningCount == iterations)
        
        // Verify thread safety - all errors should be properly sorted
        let sortedErrors = reporter.getErrorsSorted()
        let sortedWarnings = reporter.getWarningsSorted()
        
        #expect(sortedErrors.count == iterations * 2)
        #expect(sortedWarnings.count == iterations)
        
        // Verify sorting is correct (line numbers should be increasing)
        for i in 1..<sortedErrors.count {
            let prevPosition = extractPosition(from: sortedErrors[i - 1])
            let currPosition = extractPosition(from: sortedErrors[i])
            
            if let prev = prevPosition, let curr = currPosition {
                #expect(prev.line <= curr.line, "Errors should be sorted by line number")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractPosition(from error: SemanticError) -> SourcePosition? {
        switch error {
        case .typeMismatch(_, _, let pos),
             .undeclaredVariable(_, let pos):
            return pos
        default:
            return nil
        }
    }
}