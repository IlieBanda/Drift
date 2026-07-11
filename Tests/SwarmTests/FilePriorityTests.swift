import XCTest
@testable import Swarm

final class FilePriorityTests: XCTestCase {
    func testRPCKeyMapping() {
        XCTAssertEqual(FilePriority.low.rpcKey, "priority-low")
        XCTAssertEqual(FilePriority.normal.rpcKey, "priority-normal")
        XCTAssertEqual(FilePriority.high.rpcKey, "priority-high")
    }

    func testInitFromRPCValue() {
        XCTAssertEqual(FilePriority(rpcValue: -1), .low)
        XCTAssertEqual(FilePriority(rpcValue: 0), .normal)
        XCTAssertEqual(FilePriority(rpcValue: 1), .high)
    }

    func testInitFromUnknownRPCValueFallsBackToNormal() {
        XCTAssertEqual(FilePriority(rpcValue: 99), .normal)
    }
}
