import XCTest
@testable import Shared

final class LeavesTests: XCTestCase {

    // ─── Helpers ──────────────────────────────────────────────────────────────

    func makePage(studentID: String) -> [String: Any] {
        [
            "id": UUID().uuidString,
            "properties": [
                LeavesProps.student: ["relation": [["id": studentID]]]
            ]
        ]
    }

    // ─── Duplicate avoidance ──────────────────────────────────────────────────

    func testAlreadyCreated_studentWithPage_isDetected() {
        let pages = [makePage(studentID: "s1"), makePage(studentID: "s2")]
        let alreadyCreated = Set(pages.flatMap { getRelationIDs($0, field: LeavesProps.student) })
        XCTAssertTrue(alreadyCreated.contains("s1"))
        XCTAssertTrue(alreadyCreated.contains("s2"))
    }

    func testAlreadyCreated_studentWithoutPage_isNotDetected() {
        let pages = [makePage(studentID: "s1")]
        let alreadyCreated = Set(pages.flatMap { getRelationIDs($0, field: LeavesProps.student) })
        XCTAssertFalse(alreadyCreated.contains("s2"))
    }

    func testAlreadyCreated_noExistingPages_isEmpty() {
        let alreadyCreated = Set([[String: Any]]().flatMap { getRelationIDs($0, field: LeavesProps.student) })
        XCTAssertTrue(alreadyCreated.isEmpty)
    }

    func testAlreadyCreated_pageWithNoStudent_notIncluded() {
        let page: [String: Any] = ["id": "p1", "properties": [:]]
        let alreadyCreated = Set([page].flatMap { getRelationIDs($0, field: LeavesProps.student) })
        XCTAssertTrue(alreadyCreated.isEmpty)
    }
}
