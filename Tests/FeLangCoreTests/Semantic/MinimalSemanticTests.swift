import XCTest
@testable import FeLangCore

final class MinimalSemanticTests: XCTestCase {

    func testMinimal() {
        XCTAssertTrue(true)
    }

    func testSourcePosition() {
        let pos = SourcePosition(line: 1, column: 2, offset: 3)
        XCTAssertEqual(pos.line, 1)
        XCTAssertEqual(pos.column, 2)
        XCTAssertEqual(pos.offset, 3)
    }
}
