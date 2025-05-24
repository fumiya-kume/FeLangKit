import Testing
@testable import FeLangCore
import Foundation

/// Performance Benchmark Tests for Custom Codable Implementations
/// Establishes baseline metrics and performance regression tests for GitHub issue #40
@Suite("Performance Benchmarks for Codable Implementations")
struct PerformanceBenchmarkTests {

    // MARK: - Configuration

    private static let performanceThresholds = PerformanceThresholds(
        singleLiteralEncodingMs: 1.0,
        singleLiteralDecodingMs: 1.0,
        batchEncodingMsPerItem: 0.1,
        batchDecodingMsPerItem: 0.1,
        largeLiteralEncodingMs: 100.0,
        largeLiteralDecodingMs: 100.0
    )

    // MARK: - Single Item Performance Tests

    @Test("Single Literal Encoding Performance")
    func testSingleLiteralEncodingPerformance() throws {
        let encoder = JSONEncoder()

        let testCases: [(Literal, String)] = [
            (.integer(42), "integer"),
            (.real(3.14159), "real"),
            (.string("Hello, World!"), "string"),
            (.character("A"), "character"),
            (.boolean(true), "boolean")
        ]

        var results: [String: TimeInterval] = [:]

        for (literal, description) in testCases {
            let measurements = measureMultiple(iterations: 1000) {
                do {
                    _ = try encoder.encode(literal)
                } catch {
                    // Performance test should not fail - log error but continue
                    print("Encoding error in performance test: \(error)")
                }
            }

            let averageTime = measurements.average * 1000 // Convert to milliseconds
            results[description] = averageTime

            #expect(averageTime < Self.performanceThresholds.singleLiteralEncodingMs,
                   "Single \(description) encoding took \(averageTime)ms, exceeds threshold of \(Self.performanceThresholds.singleLiteralEncodingMs)ms")
        }

        printPerformanceResults(title: "Single Literal Encoding Performance", results: results, unit: "ms")
    }

    @Test("Single Literal Decoding Performance")
    func testSingleLiteralDecodingPerformance() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let testCases: [(Literal, String)] = [
            (.integer(42), "integer"),
            (.real(3.14159), "real"),
            (.string("Hello, World!"), "string"),
            (.character("A"), "character"),
            (.boolean(true), "boolean")
        ]

        var results: [String: TimeInterval] = [:]

        for (literal, description) in testCases {
            let encodedData = try encoder.encode(literal)

            let measurements = measureMultiple(iterations: 1000) {
                do {
                    _ = try decoder.decode(Literal.self, from: encodedData)
                } catch {
                    // Performance test should not fail - log error but continue
                    print("Decoding error in performance test: \(error)")
                }
            }

            let averageTime = measurements.average * 1000 // Convert to milliseconds
            results[description] = averageTime

            #expect(averageTime < Self.performanceThresholds.singleLiteralDecodingMs,
                   "Single \(description) decoding took \(averageTime)ms, exceeds threshold of \(Self.performanceThresholds.singleLiteralDecodingMs)ms")
        }

        printPerformanceResults(title: "Single Literal Decoding Performance", results: results, unit: "ms")
    }

    // MARK: - Batch Performance Tests

    @Test("Batch Literal Encoding Performance")
    func testBatchLiteralEncodingPerformance() throws {
        let encoder = JSONEncoder()

        let batchSizes = [10, 100, 1000]

        for batchSize in batchSizes {
            let literals = generateMixedLiterals(count: batchSize)

            let measurements = measureMultiple(iterations: 10) {
                for literal in literals {
                    do {
                        _ = try encoder.encode(literal)
                    } catch {
                        // Performance test should not fail - log error but continue
                        print("Encoding error in performance test: \(error)")
                    }
                }
            }

            let averageTimePerItem = (measurements.average / Double(batchSize)) * 1000 // ms per item

            #expect(averageTimePerItem < Self.performanceThresholds.batchEncodingMsPerItem,
                   "Batch encoding (\(batchSize) items) took \(averageTimePerItem)ms per item, exceeds threshold of \(Self.performanceThresholds.batchEncodingMsPerItem)ms")

            print("Batch encoding performance (\(batchSize) items): \(averageTimePerItem)ms per item")
        }
    }

    @Test("Batch Literal Decoding Performance")
    func testBatchLiteralDecodingPerformance() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let batchSizes = [10, 100, 1000]

        for batchSize in batchSizes {
            let literals = generateMixedLiterals(count: batchSize)
            let encodedData = try literals.map { try encoder.encode($0) }

            let measurements = measureMultiple(iterations: 10) {
                for data in encodedData {
                    do {
                        _ = try decoder.decode(Literal.self, from: data)
                    } catch {
                        // Performance test should not fail - log error but continue
                        print("Decoding error in performance test: \(error)")
                    }
                }
            }

            let averageTimePerItem = (measurements.average / Double(batchSize)) * 1000 // ms per item

            #expect(averageTimePerItem < Self.performanceThresholds.batchDecodingMsPerItem,
                   "Batch decoding (\(batchSize) items) took \(averageTimePerItem)ms per item, exceeds threshold of \(Self.performanceThresholds.batchDecodingMsPerItem)ms")

            print("Batch decoding performance (\(batchSize) items): \(averageTimePerItem)ms per item")
        }
    }

    // MARK: - Large Data Performance Tests

    @Test("Large String Literal Performance")
    func testLargeStringLiteralPerformance() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let stringSizes = [1_000, 10_000, 100_000]

        for stringSize in stringSizes {
            let largeString = String(repeating: "A", count: stringSize)
            let largeLiteral = Literal.string(largeString)

            // Test encoding performance
            let encodingTime = measureSingle {
                do {
                    _ = try encoder.encode(largeLiteral)
                } catch {
                    // Performance test should not fail - log error but continue
                    print("Encoding error in performance test: \(error)")
                }
            } * 1000 // Convert to milliseconds

            #expect(encodingTime < Self.performanceThresholds.largeLiteralEncodingMs,
                   "Large string encoding (\(stringSize) chars) took \(encodingTime)ms, exceeds threshold of \(Self.performanceThresholds.largeLiteralEncodingMs)ms")

            // Test decoding performance
            let encodedData = try encoder.encode(largeLiteral)
            let decodingTime = measureSingle {
                do {
                    _ = try decoder.decode(Literal.self, from: encodedData)
                } catch {
                    // Performance test should not fail - log error but continue
                    print("Decoding error in performance test: \(error)")
                }
            } * 1000 // Convert to milliseconds

            #expect(decodingTime < Self.performanceThresholds.largeLiteralDecodingMs,
                   "Large string decoding (\(stringSize) chars) took \(decodingTime)ms, exceeds threshold of \(Self.performanceThresholds.largeLiteralDecodingMs)ms")

            print("Large string performance (\(stringSize) chars): encoding \(encodingTime)ms, decoding \(decodingTime)ms")
        }
    }

    // MARK: - Memory Performance Tests

    @Test("Memory Usage During Serialization")
    func testMemoryUsageDuringSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let memoryBefore = getMemoryUsage()

        // Perform a significant amount of serialization work
        let literals = generateMixedLiterals(count: 10_000)
        var encodedData: [Data] = []

        for literal in literals {
            encodedData.append(try encoder.encode(literal))
        }

        let memoryAfterEncoding = getMemoryUsage()

        // Now decode everything
        var decodedLiterals: [Literal] = []
        for data in encodedData {
            decodedLiterals.append(try decoder.decode(Literal.self, from: data))
        }

        let memoryAfterDecoding = getMemoryUsage()

        let encodingMemoryIncrease = memoryAfterEncoding - memoryBefore
        let decodingMemoryIncrease = memoryAfterDecoding - memoryAfterEncoding

        print("Memory usage:")
        print("  Before: \(memoryBefore) KB")
        print("  After encoding: \(memoryAfterEncoding) KB (increase: \(encodingMemoryIncrease) KB)")
        print("  After decoding: \(memoryAfterDecoding) KB (increase: \(decodingMemoryIncrease) KB)")

        // Verify we can decode everything correctly
        #expect(decodedLiterals.count == literals.count, "All literals should be decoded")

        for (original, decoded) in zip(literals, decodedLiterals) {
            #expect(original == decoded, "Decoded literal should match original")
        }
    }

    // MARK: - Concurrent Performance Tests

    @Test("Concurrent Serialization Performance")
    func testConcurrentSerializationPerformance() throws {
        let concurrentOperations = 100
        let operationsPerThread = 10

        let startTime = CFAbsoluteTimeGetCurrent()

        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        for threadIndex in 0..<concurrentOperations {
            group.enter()
            queue.async {
                defer { group.leave() }

                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                let literals = generateMixedLiterals(count: operationsPerThread)

                // Perform encoding and decoding
                for literal in literals {
                    do {
                        let encoded = try encoder.encode(literal)
                        let decoded = try decoder.decode(Literal.self, from: encoded)

                        if decoded != literal {
                            print("Mismatch in thread \(threadIndex)")
                        }
                    } catch {
                        print("Error in thread \(threadIndex): \(error)")
                    }
                }
            }
        }

        group.wait()

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let totalOperations = concurrentOperations * operationsPerThread * 2 // encode + decode
        let operationsPerSecond = Double(totalOperations) / totalTime

        print("Concurrent performance: \(operationsPerSecond) operations/second with \(concurrentOperations) concurrent threads")

        // Expect reasonable concurrent performance
        #expect(operationsPerSecond > 1000, "Concurrent operations should achieve at least 1000 ops/sec")
        #expect(totalTime < 10.0, "Concurrent test should complete within 10 seconds")
    }

    // MARK: - AnyCodable Performance Comparison

    @Test("AnyCodable vs Native Performance Comparison")
    func testAnyCodablePerformanceComparison() throws {
        let iterations = 1000

        // Test SafeAnyCodable performance
        let safeAnyCodableTime = measureMultiple(iterations: iterations) {
            do {
                let anyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable(42)
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()

                let encoded = try encoder.encode(anyCodable)
                let decoded = try decoder.decode(SafeAnyCodable.self, from: encoded)
                let _: Int = try decoded.getValue()
            } catch {
                print("SafeAnyCodable performance test error: \(error)")
            }
        }.average * 1000 // Convert to milliseconds

        // Test ImprovedAnyCodable performance
        let improvedAnyCodableTime = measureMultiple(iterations: iterations) {
            do {
                let anyCodable = try ImprovedAnyCodable(42)
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()

                let encoded = try encoder.encode(anyCodable)
                let decoded = try decoder.decode(ImprovedAnyCodable.self, from: encoded)
                let _: Int = try decoded.getValue()
            } catch {
                print("ImprovedAnyCodable performance test error: \(error)")
            }
        }.average * 1000 // Convert to milliseconds

        // Test native Literal performance
        let literalTime = measureMultiple(iterations: iterations) {
            do {
                let literal = Literal.integer(42)
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()

                let encoded = try encoder.encode(literal)
                let decoded = try decoder.decode(Literal.self, from: encoded)

                if case .integer(let value) = decoded {
                    #expect(value == 42)
                }
            } catch {
                print("Literal performance test error: \(error)")
            }
        }.average * 1000 // Convert to milliseconds

        print("Performance comparison (per operation):")
        print("  SafeAnyCodable: \(safeAnyCodableTime)ms")
        print("  ImprovedAnyCodable: \(improvedAnyCodableTime)ms")
        print("  Native Literal: \(literalTime)ms")

        // Performance expectations (AnyCodable implementations should not be more than 3x slower)
        #expect(safeAnyCodableTime < literalTime * 3.0, "SafeAnyCodable should not be more than 3x slower than native")
        #expect(improvedAnyCodableTime < literalTime * 3.0, "ImprovedAnyCodable should not be more than 3x slower than native")
    }

    // MARK: - Helper Methods

    private func generateMixedLiterals(count: Int) -> [Literal] {
        var literals: [Literal] = []

        for index in 0..<count {
            switch index % 5 {
            case 0:
                literals.append(.integer(index))
            case 1:
                literals.append(.real(Double(index) * 3.14))
            case 2:
                literals.append(.string("String \(index)"))
            case 3:
                literals.append(.character(Character(UnicodeScalar((index % 26) + 65)!)))
            case 4:
                literals.append(.boolean(index % 2 == 0))
            default:
                break
            }
        }

        return literals
    }

    private func measureSingle<T>(operation: () throws -> T) rethrows -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try operation()
        return CFAbsoluteTimeGetCurrent() - startTime
    }

    private func measureMultiple<T>(iterations: Int, operation: () throws -> T) rethrows -> PerformanceMeasurement {
        var measurements: [TimeInterval] = []

        for _ in 0..<iterations {
            let time = try measureSingle(operation: operation)
            measurements.append(time)
        }

        return PerformanceMeasurement(measurements: measurements)
    }

    private func printPerformanceResults(title: String, results: [String: TimeInterval], unit: String) {
        print("\n\(title):")
        for (key, value) in results.sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(String(format: "%.3f", value))\(unit)")
        }
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kernelResult = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kernelResult == KERN_SUCCESS {
            return info.resident_size / 1024 // Convert to KB
        } else {
            return 0
        }
    }
}

// MARK: - Supporting Types

private struct PerformanceThresholds {
    let singleLiteralEncodingMs: TimeInterval
    let singleLiteralDecodingMs: TimeInterval
    let batchEncodingMsPerItem: TimeInterval
    let batchDecodingMsPerItem: TimeInterval
    let largeLiteralEncodingMs: TimeInterval
    let largeLiteralDecodingMs: TimeInterval
}

private struct PerformanceMeasurement {
    let measurements: [TimeInterval]

    var average: TimeInterval {
        measurements.reduce(0, +) / Double(measurements.count)
    }

    var min: TimeInterval {
        measurements.min() ?? 0
    }

    var max: TimeInterval {
        measurements.max() ?? 0
    }

    var standardDeviation: TimeInterval {
        let avg = average
        let squaredDifferences = measurements.map { ($0 - avg) * ($0 - avg) }
        let variance = squaredDifferences.reduce(0, +) / Double(measurements.count)
        return sqrt(variance)
    }
}
