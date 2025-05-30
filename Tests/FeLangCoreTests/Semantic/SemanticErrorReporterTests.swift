import XCTest
@testable import FeLangCore

final class SemanticErrorReporterTests: XCTestCase {

    var symbolTable: SymbolTable!
    var sourcePosition: SourcePosition!

    override func setUp() {
        super.setUp()
        symbolTable = SymbolTable()
        sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
    }

    override func tearDown() {
        symbolTable = nil
        sourcePosition = nil
        super.tearDown()
    }

    // MARK: - Basic Error Collection Tests

    func testCollectSingleError() {
        let reporter = SemanticErrorReporter()
        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)

        reporter.collect(error)

        XCTAssertEqual(reporter.errorCount, 1)
        XCTAssertEqual(reporter.warningCount, 0)
        XCTAssertFalse(reporter.hasReachedErrorLimit)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.errors[0], error)
    }

    func testCollectMultipleErrors() {
        let reporter = SemanticErrorReporter()
        let errors = [
            SemanticError.undeclaredVariable("x", position: sourcePosition),
            SemanticError.undeclaredVariable("y", position: SourcePosition(line: 2, column: 1, offset: 10)),
            SemanticError.typeMismatch(expected: .integer, actual: .string, position: SourcePosition(line: 3, column: 1, offset: 20))
        ]

        reporter.collect(errors)

        XCTAssertEqual(reporter.errorCount, 3)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 3)
    }

    func testCollectSingleWarning() {
        let reporter = SemanticErrorReporter()
        let warning = SemanticWarning.unusedVariable("x", position: sourcePosition)

        reporter.collect(warning)

        XCTAssertEqual(reporter.errorCount, 0)
        XCTAssertEqual(reporter.warningCount, 1)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertTrue(result.isSuccessful) // No errors, only warnings
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertEqual(result.warnings[0], warning)
    }

    func testCollectMultipleWarnings() {
        let reporter = SemanticErrorReporter()
        let warnings = [
            SemanticWarning.unusedVariable("x", position: sourcePosition),
            SemanticWarning.unusedFunction("foo", position: SourcePosition(line: 2, column: 1, offset: 10))
        ]

        reporter.collect(warnings)

        XCTAssertEqual(reporter.warningCount, 2)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(result.warnings.count, 2)
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = SemanticErrorReportingConfig.default

        XCTAssertEqual(config.maxErrorCount, 100)
        XCTAssertTrue(config.enableDeduplication)
        XCTAssertFalse(config.enableErrorCorrelation)
        XCTAssertFalse(config.verboseOutput)
    }

    func testStrictConfiguration() {
        let config = SemanticErrorReportingConfig.strict

        XCTAssertEqual(config.maxErrorCount, 1000)
        XCTAssertTrue(config.enableDeduplication)
        XCTAssertTrue(config.enableErrorCorrelation)
        XCTAssertTrue(config.verboseOutput)
    }

    func testFastConfiguration() {
        let config = SemanticErrorReportingConfig.fast

        XCTAssertEqual(config.maxErrorCount, 50)
        XCTAssertFalse(config.enableDeduplication)
        XCTAssertFalse(config.enableErrorCorrelation)
        XCTAssertFalse(config.verboseOutput)
    }

    func testCustomConfiguration() {
        let config = SemanticErrorReportingConfig(
            maxErrorCount: 25,
            enableDeduplication: true,
            enableErrorCorrelation: true,
            verboseOutput: false
        )

        XCTAssertEqual(config.maxErrorCount, 25)
        XCTAssertTrue(config.enableDeduplication)
        XCTAssertTrue(config.enableErrorCorrelation)
        XCTAssertFalse(config.verboseOutput)
    }

    // MARK: - Error Deduplication Tests

    func testErrorDeduplicationEnabled() {
        let config = SemanticErrorReportingConfig(enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)

        // Same error at same position should be deduplicated
        let error1 = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let error2 = SemanticError.undeclaredVariable("y", position: sourcePosition) // Different variable, same position

        reporter.collect(error1)
        reporter.collect(error2)

        XCTAssertEqual(reporter.errorCount, 1) // Should only have one error due to deduplication

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 1)
    }

    func testErrorDeduplicationDisabled() {
        let config = SemanticErrorReportingConfig(enableDeduplication: false)
        let reporter = SemanticErrorReporter(config: config)

        // Same position, different errors
        let error1 = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let error2 = SemanticError.undeclaredVariable("y", position: sourcePosition)

        reporter.collect(error1)
        reporter.collect(error2)

        XCTAssertEqual(reporter.errorCount, 2) // Should have both errors

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 2)
    }

    func testErrorDeduplicationDifferentPositions() {
        let config = SemanticErrorReportingConfig(enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)

        let pos1 = SourcePosition(line: 1, column: 1, offset: 0)
        let pos2 = SourcePosition(line: 2, column: 1, offset: 10)

        let error1 = SemanticError.undeclaredVariable("x", position: pos1)
        let error2 = SemanticError.undeclaredVariable("x", position: pos2)

        reporter.collect(error1)
        reporter.collect(error2)

        XCTAssertEqual(reporter.errorCount, 2) // Different positions, should not deduplicate

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 2)
    }

    // MARK: - Error Limit Tests

    func testErrorLimit() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 3)
        let reporter = SemanticErrorReporter(config: config)

        for index in 1...5 {
            let error = SemanticError.undeclaredVariable("var\(index)", position: SourcePosition(line: index, column: 1, offset: index * 10))
            reporter.collect(error)
        }

        XCTAssertEqual(reporter.errorCount, 4) // 3 regular errors + 1 "too many errors" error
        XCTAssertTrue(reporter.hasReachedErrorLimit)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 4)

        // Check that the last error is the "too many errors" error
        let lastError = result.errors.last
        XCTAssertNotNil(lastError)
        if case .tooManyErrors(let count) = lastError! {
            XCTAssertEqual(count, 3)
        } else {
            XCTFail("Expected tooManyErrors error")
        }
    }

    func testErrorLimitWithZeroMax() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 0)
        let reporter = SemanticErrorReporter(config: config)

        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)
        reporter.collect(error)

        XCTAssertEqual(reporter.errorCount, 1) // Should add "too many errors" error immediately
        XCTAssertTrue(reporter.hasReachedErrorLimit)

        let result = reporter.finalize(with: symbolTable)
        if case .tooManyErrors(let count) = result.errors.first! {
            XCTAssertEqual(count, 0)
        } else {
            XCTFail("Expected tooManyErrors error")
        }
    }

    // MARK: - Error Correlation Tests

    func testErrorCorrelationEnabled() throws {
        // Add unused variables to symbol table
        _ = symbolTable.declare(name: "unusedVar", type: .integer, kind: .variable, position: sourcePosition)
        _ = symbolTable.declare(name: "unusedFunc", type: .function(parameters: [], returnType: .integer), kind: .function, position: SourcePosition(line: 2, column: 1, offset: 10))

        let config = SemanticErrorReportingConfig(enableErrorCorrelation: true)
        let reporter = SemanticErrorReporter(config: config)

        let result = reporter.finalize(with: symbolTable)

        // Should generate warnings for unused symbols
        // Note: SymbolTable.getUnusedSymbols() excludes functions by design, so we only expect the variable
        XCTAssertEqual(result.warnings.count, 1)

        let warningTypes = result.warnings.map { warning in
            switch warning {
            case .unusedVariable(let name, _):
                return "unusedVariable:\(name)"
            case .unusedFunction(let name, _):
                return "unusedFunction:\(name)"
            default:
                return "other"
            }
        }

        XCTAssertTrue(warningTypes.contains("unusedVariable:unusedVar"))
    }

    func testErrorCorrelationDisabled() throws {
        // Add unused variables to symbol table
        _ = symbolTable.declare(name: "unusedVar", type: .integer, kind: .variable, position: sourcePosition)

        let config = SemanticErrorReportingConfig(enableErrorCorrelation: false)
        let reporter = SemanticErrorReporter(config: config)

        let result = reporter.finalize(with: symbolTable)

        // Should not generate warnings for unused symbols
        XCTAssertEqual(result.warnings.count, 0)
    }

    // MARK: - Finalization Tests

    func testFinalizationPreventsMoreCollections() {
        let reporter = SemanticErrorReporter()
        let error1 = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let error2 = SemanticError.undeclaredVariable("y", position: SourcePosition(line: 2, column: 1, offset: 10))

        reporter.collect(error1)
        let result1 = reporter.finalize(with: symbolTable)

        // Try to collect another error after finalization
        reporter.collect(error2)
        let result2 = reporter.finalize(with: symbolTable)

        XCTAssertEqual(result1.errors.count, 1)
        XCTAssertEqual(result2.errors.count, 1) // Should be the same as first result
        XCTAssertEqual(reporter.errorCount, 1) // Should not increase
    }

    func testMultipleFinalizationCalls() {
        let reporter = SemanticErrorReporter()
        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)

        reporter.collect(error)

        let result1 = reporter.finalize(with: symbolTable)
        let result2 = reporter.finalize(with: symbolTable)

        XCTAssertEqual(result1.errors.count, 1)
        XCTAssertEqual(result2.errors.count, 1)
        XCTAssertEqual(result1.errors, result2.errors)
    }

    // MARK: - Reset Functionality Tests

    func testReset() {
        let reporter = SemanticErrorReporter()
        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let warning = SemanticWarning.unusedVariable("y", position: sourcePosition)

        reporter.collect(error)
        reporter.collect(warning)

        XCTAssertEqual(reporter.errorCount, 1)
        XCTAssertEqual(reporter.warningCount, 1)

        reporter.reset()

        XCTAssertEqual(reporter.errorCount, 0)
        XCTAssertEqual(reporter.warningCount, 0)
        XCTAssertFalse(reporter.hasReachedErrorLimit)

        // Should be able to collect new errors after reset
        reporter.collect(error)
        XCTAssertEqual(reporter.errorCount, 1)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 1)
    }

    func testResetAfterFinalization() {
        let reporter = SemanticErrorReporter()
        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)

        reporter.collect(error)
        _ = reporter.finalize(with: symbolTable)

        reporter.reset()

        // Should be able to collect new errors after reset
        let newError = SemanticError.undeclaredVariable("z", position: SourcePosition(line: 3, column: 1, offset: 20))
        reporter.collect(newError)

        XCTAssertEqual(reporter.errorCount, 1)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.errors[0], newError)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentErrorCollection() {
        let reporter = SemanticErrorReporter()
        let expectation = XCTestExpectation(description: "Concurrent error collection")
        let errorCount = 100
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()

        for index in 0..<errorCount {
            group.enter()
            queue.async {
                let position = SourcePosition(line: index + 1, column: 1, offset: index * 10)
                let error = SemanticError.undeclaredVariable("var\(index)", position: position)
                reporter.collect(error)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            XCTAssertEqual(reporter.errorCount, errorCount)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentWarningCollection() {
        let reporter = SemanticErrorReporter()
        let expectation = XCTestExpectation(description: "Concurrent warning collection")
        let warningCount = 50
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()

        for index in 0..<warningCount {
            group.enter()
            queue.async {
                let position = SourcePosition(line: index + 1, column: 1, offset: index * 10)
                let warning = SemanticWarning.unusedVariable("var\(index)", position: position)
                reporter.collect(warning)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            XCTAssertEqual(reporter.warningCount, warningCount)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Edge Case Tests

    func testEmptyErrorCollection() {
        let reporter = SemanticErrorReporter()

        XCTAssertEqual(reporter.errorCount, 0)
        XCTAssertEqual(reporter.warningCount, 0)
        XCTAssertFalse(reporter.hasReachedErrorLimit)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.warnings.count, 0)
    }

    func testTooManyErrorsDeduplication() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 1, enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)

        // Add multiple errors at same position to trigger both deduplication and limit
        let error1 = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let error2 = SemanticError.undeclaredVariable("y", position: sourcePosition)
        let error3 = SemanticError.undeclaredVariable("z", position: SourcePosition(line: 2, column: 1, offset: 10))

        reporter.collect(error1)
        reporter.collect(error2) // Should be deduplicated
        reporter.collect(error3) // Should trigger limit

        XCTAssertEqual(reporter.errorCount, 2) // 1 regular error + 1 "too many errors" error

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 2)
    }
}
