import Foundation
import Testing
@testable import FeLangCore

@Suite("CrossPlatformUtilities Tests")
struct CrossPlatformUtilitiesTests {

    @Test func testGetCurrentTimeReturnsPositiveValue() throws {
        let time = getCurrentTime()
        #expect(time > 0)
    }

    @Test func testGetCurrentTimeIsMonotonicallyIncreasing() throws {
        let time1 = getCurrentTime()
        // Small operation to ensure some time passes
        _ = (0..<100).reduce(0, +)
        let time2 = getCurrentTime()
        #expect(time2 >= time1)
    }

    @Test func testGetCurrentTimeHasReasonablePrecision() throws {
        let time1 = getCurrentTime()
        Thread.sleep(forTimeInterval: 0.01) // 10ms
        let time2 = getCurrentTime()
        let elapsed = time2 - time1
        // Should measure at least some time passed (allowing for timing variance)
        #expect(elapsed >= 0.005)
        #expect(elapsed < 1.0) // Should not be more than 1 second
    }

    @Test func testGetCurrentTimeConsistency() throws {
        // Get multiple time samples and verify they're consistent
        var times: [TimeInterval] = []
        for _ in 0..<5 {
            times.append(getCurrentTime())
        }

        // All times should be in ascending order
        for index in 1..<times.count {
            #expect(times[index] >= times[index-1])
        }
    }
}
