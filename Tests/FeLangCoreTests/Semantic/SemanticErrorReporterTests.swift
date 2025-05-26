import XCTest
@testable import FeLangCore

final class SemanticErrorReporterTests: XCTestCase {
    
    var symbolTable: SymbolTable!
    
    override func setUp() {
        super.setUp()
        symbolTable = SymbolTable()
    }
    
    override func tearDown() {
        symbolTable = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() {
        let config = SemanticErrorReportingConfig.default
        
        XCTAssertEqual(config.maxErrorCount, 100)
        XCTAssertTrue(config.enableDeduplication)
        XCTAssertTrue(config.enableErrorCorrelation)
        XCTAssertFalse(config.verboseOutput)
    }
    
    func testCustomConfiguration() {
        let config = SemanticErrorReportingConfig(
            maxErrorCount: 50,
            enableDeduplication: false,
            enableErrorCorrelation: false,
            verboseOutput: true
        )
        
        XCTAssertEqual(config.maxErrorCount, 50)
        XCTAssertFalse(config.enableDeduplication)
        XCTAssertFalse(config.enableErrorCorrelation)
        XCTAssertTrue(config.verboseOutput)
    }
    
    func testConfigurationValidation() {
        // Test that maxErrorCount is at least 1
        let config = SemanticErrorReportingConfig(maxErrorCount: -5)
        XCTAssertEqual(config.maxErrorCount, 1)
    }
    
    // MARK: - Basic Error Collection Tests
    
    func testSingleErrorCollection() {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)
        
        reporter.collect(error)
        
        XCTAssertTrue(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 1)
        XCTAssertFalse(reporter.hasWarnings)
        XCTAssertEqual(reporter.warningCount, 0)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.warnings.count, 0)
        XCTAssertTrue(result.hasErrors)
        XCTAssertFalse(result.hasWarnings)
    }
    
    func testMultipleErrorCollection() {
        let reporter = SemanticErrorReporter()
        let position1 = SourcePosition(line: 1, column: 1, offset: 0)
        let position2 = SourcePosition(line: 2, column: 1, offset: 10)
        
        let errors = [
            SemanticError.typeMismatch(expected: .integer, actual: .string, at: position1),
            SemanticError.undeclaredVariable("x", at: position2)
        ]
        
        reporter.collect(errors)
        
        XCTAssertTrue(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 2)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 2)
    }
    
    func testWarningCollection() {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        let warning = SemanticWarning.unusedVariable("temp", at: position)
        
        reporter.collect(warning)
        
        XCTAssertFalse(reporter.hasErrors)
        XCTAssertTrue(reporter.hasWarnings)
        XCTAssertEqual(reporter.warningCount, 1)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertTrue(result.isSuccessful) // Warnings don't affect success
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertTrue(result.hasWarnings)
    }
    
    func testMultipleWarningCollection() {
        let reporter = SemanticErrorReporter()
        let position1 = SourcePosition(line: 1, column: 1, offset: 0)
        let position2 = SourcePosition(line: 2, column: 1, offset: 10)
        
        let warnings = [
            SemanticWarning.unusedVariable("temp", at: position1),
            SemanticWarning.unusedFunction("helper", at: position2)
        ]
        
        reporter.collect(warnings)
        
        XCTAssertEqual(reporter.warningCount, 2)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.warnings.count, 2)
    }
    
    // MARK: - Error Deduplication Tests
    
    func testErrorDeduplication() {
        let config = SemanticErrorReportingConfig(enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        
        // Add the same error at the same position multiple times
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)
        reporter.collect(error)
        reporter.collect(error)
        reporter.collect(error)
        
        // Only one error should be collected due to deduplication
        XCTAssertEqual(reporter.errorCount, 1)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 1)
    }
    
    func testErrorDeduplicationDisabled() {
        let config = SemanticErrorReportingConfig(enableDeduplication: false)
        let reporter = SemanticErrorReporter(config: config)
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        
        // Add the same error at the same position multiple times
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)
        reporter.collect(error)
        reporter.collect(error)
        reporter.collect(error)
        
        // All errors should be collected when deduplication is disabled
        XCTAssertEqual(reporter.errorCount, 3)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 3)
    }
    
    func testErrorDeduplicationDifferentPositions() {
        let config = SemanticErrorReportingConfig(enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)
        let position1 = SourcePosition(line: 1, column: 1, offset: 0)
        let position2 = SourcePosition(line: 2, column: 1, offset: 10)
        
        // Add similar errors at different positions
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: position1))
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: position2))
        
        // Both errors should be collected since they're at different positions
        XCTAssertEqual(reporter.errorCount, 2)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 2)
    }
    
    // MARK: - Error Threshold Tests
    
    func testErrorThreshold() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 3)
        let reporter = SemanticErrorReporter(config: config)
        
        // Add errors up to the threshold
        for i in 0..<5 {
            let position = SourcePosition(line: i + 1, column: 1, offset: i * 10)
            let error = SemanticError.undeclaredVariable("var\(i)", at: position)
            reporter.collect(error)
        }
        
        // Should stop at maxErrorCount + 1 (for the tooManyErrors)
        XCTAssertEqual(reporter.errorCount, 4) // 3 regular errors + 1 tooManyErrors
        XCTAssertTrue(reporter.isFull)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 4)
        
        // Check that the last error is tooManyErrors
        let lastError = result.errors.last
        if case .tooManyErrors(let count) = lastError {
            XCTAssertEqual(count, 3)
        } else {
            XCTFail("Expected tooManyErrors as last error")
        }
    }
    
    func testErrorThresholdBoundary() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 1)
        let reporter = SemanticErrorReporter(config: config)
        
        let position1 = SourcePosition(line: 1, column: 1, offset: 0)
        let position2 = SourcePosition(line: 2, column: 1, offset: 10)
        
        reporter.collect(.undeclaredVariable("var1", at: position1))
        XCTAssertEqual(reporter.errorCount, 1)
        XCTAssertFalse(reporter.isFull) // Not full yet because tooManyErrors not added
        
        reporter.collect(.undeclaredVariable("var2", at: position2))
        XCTAssertEqual(reporter.errorCount, 2) // 1 regular + 1 tooManyErrors
        XCTAssertTrue(reporter.isFull)
        
        // Additional errors should be ignored
        reporter.collect(.undeclaredVariable("var3", at: position1))
        XCTAssertEqual(reporter.errorCount, 2)
    }
    
    // MARK: - Clear Functionality Tests
    
    func testClearFunctionality() {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        
        // Add some errors and warnings
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: position))
        reporter.collect(.unusedVariable("temp", at: position))
        
        XCTAssertTrue(reporter.hasErrors)
        XCTAssertTrue(reporter.hasWarnings)
        
        // Clear all
        reporter.clear()
        
        XCTAssertFalse(reporter.hasErrors)
        XCTAssertFalse(reporter.hasWarnings)
        XCTAssertEqual(reporter.errorCount, 0)
        XCTAssertEqual(reporter.warningCount, 0)
        XCTAssertFalse(reporter.isFull)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.warnings.count, 0)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentErrorCollection() {
        let reporter = SemanticErrorReporter()
        let expectation = XCTestExpectation(description: "Concurrent error collection")
        expectation.expectedFulfillmentCount = 10
        
        // Simulate concurrent error collection from multiple threads
        for i in 0..<10 {
            DispatchQueue.global().async {
                let position = SourcePosition(line: i + 1, column: 1, offset: i * 10)
                let error = SemanticError.undeclaredVariable("var\(i)", at: position)
                reporter.collect(error)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // All errors should be collected
        XCTAssertEqual(reporter.errorCount, 10)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 10)
    }
    
    func testConcurrentWarningCollection() {
        let reporter = SemanticErrorReporter()
        let expectation = XCTestExpectation(description: "Concurrent warning collection")
        expectation.expectedFulfillmentCount = 10
        
        // Simulate concurrent warning collection from multiple threads
        for i in 0..<10 {
            DispatchQueue.global().async {
                let position = SourcePosition(line: i + 1, column: 1, offset: i * 10)
                let warning = SemanticWarning.unusedVariable("var\(i)", at: position)
                reporter.collect(warning)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // All warnings should be collected
        XCTAssertEqual(reporter.warningCount, 10)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.warnings.count, 10)
    }
    
    // MARK: - Integration Tests
    
    func testMixedErrorsAndWarnings() {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        
        // Add mixed errors and warnings
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: position))
        reporter.collect(.unusedVariable("temp", at: position))
        reporter.collect(.undeclaredVariable("x", at: position))
        reporter.collect(.unusedFunction("helper", at: position))
        
        XCTAssertEqual(reporter.errorCount, 2)
        XCTAssertEqual(reporter.warningCount, 2)
        XCTAssertTrue(reporter.hasErrors)
        XCTAssertTrue(reporter.hasWarnings)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful) // Errors make it unsuccessful
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertEqual(result.warnings.count, 2)
        XCTAssertEqual(result.issueCount, 4)
    }
    
    func testComplexErrorScenario() {
        let config = SemanticErrorReportingConfig(
            maxErrorCount: 5,
            enableDeduplication: true,
            enableErrorCorrelation: true
        )
        let reporter = SemanticErrorReporter(config: config)
        
        // Add various types of errors
        let positions = (1...10).map { SourcePosition(line: $0, column: 1, offset: $0 * 10) }
        
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: positions[0]))
        reporter.collect(.undeclaredVariable("x", at: positions[1]))
        reporter.collect(.functionAlreadyDeclared("func", at: positions[2]))
        reporter.collect(.breakOutsideLoop(at: positions[3]))
        reporter.collect(.invalidArrayAccess(at: positions[4]))
        
        // These should be ignored due to threshold
        reporter.collect(.undeclaredVariable("y", at: positions[5]))
        reporter.collect(.undeclaredVariable("z", at: positions[6]))
        
        XCTAssertEqual(reporter.errorCount, 6) // 5 regular + 1 tooManyErrors
        XCTAssertTrue(reporter.isFull)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 6)
        
        // Verify that tooManyErrors is present
        let hasTooManyErrors = result.errors.contains { error in
            if case .tooManyErrors = error { return true }
            return false
        }
        XCTAssertTrue(hasTooManyErrors)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyErrorCollection() {
        let reporter = SemanticErrorReporter()
        
        XCTAssertFalse(reporter.hasErrors)
        XCTAssertFalse(reporter.hasWarnings)
        XCTAssertEqual(reporter.errorCount, 0)
        XCTAssertEqual(reporter.warningCount, 0)
        XCTAssertFalse(reporter.isFull)
        
        let result = reporter.finalize(with: symbolTable)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.warnings.count, 0)
        XCTAssertFalse(result.hasErrors)
        XCTAssertFalse(result.hasWarnings)
    }
    
    func testMinimalErrorThreshold() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 1)
        let reporter = SemanticErrorReporter(config: config)
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        
        reporter.collect(.undeclaredVariable("x", at: position))
        XCTAssertEqual(reporter.errorCount, 1)
        XCTAssertFalse(reporter.isFull)
        
        // This should trigger the threshold
        reporter.collect(.undeclaredVariable("y", at: SourcePosition(line: 2, column: 1, offset: 10)))
        XCTAssertEqual(reporter.errorCount, 2) // 1 regular + 1 tooManyErrors
        XCTAssertTrue(reporter.isFull)
    }
    
    func testAllErrorTypes() {
        let reporter = SemanticErrorReporter()
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        
        // Test that all error types can be collected
        let errors: [SemanticError] = [
            .typeMismatch(expected: .integer, actual: .string, at: position),
            .incompatibleTypes(.integer, .string, operation: "+", at: position),
            .unknownType("CustomType", at: position),
            .invalidTypeConversion(from: .string, to: .integer, at: position),
            .undeclaredVariable("x", at: position),
            .variableAlreadyDeclared("y", at: position),
            .variableNotInitialized("z", at: position),
            .constantReassignment("CONST", at: position),
            .invalidAssignmentTarget(at: position),
            .undeclaredFunction("func", at: position),
            .functionAlreadyDeclared("func2", at: position),
            .incorrectArgumentCount(function: "func3", expected: 2, actual: 1, at: position),
            .argumentTypeMismatch(function: "func4", paramIndex: 0, expected: .integer, actual: .string, at: position),
            .missingReturnStatement(function: "func5", at: position),
            .returnTypeMismatch(function: "func6", expected: .integer, actual: .string, at: position),
            .voidFunctionReturnsValue(function: "proc", at: position),
            .unreachableCode(at: position),
            .breakOutsideLoop(at: position),
            .returnOutsideFunction(at: position),
            .invalidArrayAccess(at: position),
            .arrayIndexTypeMismatch(expected: .integer, actual: .string, at: position),
            .invalidArrayDimension(at: position),
            .undeclaredField(fieldName: "field", recordType: "Record", at: position),
            .invalidFieldAccess(at: position),
            .cyclicDependency(["A", "B", "A"], at: position),
            .analysisDepthExceeded(at: position)
        ]
        
        // Disable deduplication to collect all errors
        let config = SemanticErrorReportingConfig(
            maxErrorCount: 100,
            enableDeduplication: false
        )
        let reporterWithoutDedup = SemanticErrorReporter(config: config)
        
        for error in errors {
            reporterWithoutDedup.collect(error)
        }
        
        XCTAssertEqual(reporterWithoutDedup.errorCount, errors.count)
        
        let result = reporterWithoutDedup.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, errors.count)
    }
}