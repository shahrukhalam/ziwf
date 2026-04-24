import XCTest
@testable import Shared

final class AttendanceTests: XCTestCase {

    // ─── Helpers ──────────────────────────────────────────────────────────────

    func makeLeavePage(studentID: String, start: String, end: String? = nil) -> [String: Any] {
        var dateValue: [String: Any] = ["start": start]
        if let end { dateValue["end"] = end }
        return [
            "id": UUID().uuidString,
            "properties": [
                LeavesProps.fromTo:  ["date": dateValue],
                LeavesProps.student: ["relation": [["id": studentID]]]
            ]
        ]
    }

    // ─── Single-day leave ─────────────────────────────────────────────────────

    func testSingleDayLeave_today_isOnLeave() {
        let pages = [makeLeavePage(studentID: "s1", start: "2026-04-24")]
        XCTAssertTrue(students_on_leave(from: pages, today: "2026-04-24").contains("s1"))
    }

    func testSingleDayLeave_yesterday_isNotOnLeave() {
        let pages = [makeLeavePage(studentID: "s1", start: "2026-04-23")]
        XCTAssertFalse(students_on_leave(from: pages, today: "2026-04-24").contains("s1"))
    }

    func testSingleDayLeave_tomorrow_isNotOnLeave() {
        let pages = [makeLeavePage(studentID: "s1", start: "2026-04-25")]
        XCTAssertFalse(students_on_leave(from: pages, today: "2026-04-24").contains("s1"))
    }

    // ─── Multi-day leave ──────────────────────────────────────────────────────

    func testMultiDayLeave_coveringToday_isOnLeave() {
        let pages = [makeLeavePage(studentID: "s1", start: "2026-04-22", end: "2026-04-26")]
        XCTAssertTrue(students_on_leave(from: pages, today: "2026-04-24").contains("s1"))
    }

    func testMultiDayLeave_startAndEndToday_isOnLeave() {
        let pages = [makeLeavePage(studentID: "s1", start: "2026-04-24", end: "2026-04-24")]
        XCTAssertTrue(students_on_leave(from: pages, today: "2026-04-24").contains("s1"))
    }

    func testMultiDayLeave_endedYesterday_isNotOnLeave() {
        let pages = [makeLeavePage(studentID: "s1", start: "2026-04-20", end: "2026-04-23")]
        XCTAssertFalse(students_on_leave(from: pages, today: "2026-04-24").contains("s1"))
    }

    func testMultiDayLeave_startsToday_isOnLeave() {
        let pages = [makeLeavePage(studentID: "s1", start: "2026-04-24", end: "2026-04-28")]
        XCTAssertTrue(students_on_leave(from: pages, today: "2026-04-24").contains("s1"))
    }

    // ─── No leave ─────────────────────────────────────────────────────────────

    func testNoLeavePages_noStudentsOnLeave() {
        XCTAssertTrue(students_on_leave(from: [], today: "2026-04-24").isEmpty)
    }

    func testPageWithNoDateRange_ignored() {
        let page: [String: Any] = [
            "id": "p1",
            "properties": [
                LeavesProps.fromTo:  ["date": NSNull()],
                LeavesProps.student: ["relation": [["id": "s1"]]]
            ]
        ]
        XCTAssertFalse(students_on_leave(from: [page], today: "2026-04-24").contains("s1"))
    }

    // ─── Duplicate avoidance (action re-run on same day) ─────────────────────

    func makeAttendancePage(studentID: String) -> [String: Any] {
        [
            "id": UUID().uuidString,
            "properties": [
                AttendanceProps.student: ["relation": [["id": studentID]]]
            ]
        ]
    }

    func testAlreadyCreated_studentWithRow_isSkipped() {
        let existing = [makeAttendancePage(studentID: "s1"), makeAttendancePage(studentID: "s2")]
        let alreadyCreated = Set(existing.flatMap { getRelationIDs($0, field: AttendanceProps.student) })
        XCTAssertTrue(alreadyCreated.contains("s1"))
        XCTAssertTrue(alreadyCreated.contains("s2"))
    }

    func testAlreadyCreated_studentWithoutRow_isNotSkipped() {
        let existing = [makeAttendancePage(studentID: "s1")]
        let alreadyCreated = Set(existing.flatMap { getRelationIDs($0, field: AttendanceProps.student) })
        XCTAssertFalse(alreadyCreated.contains("s2"))
    }

    func testAlreadyCreated_noExistingRows_isEmpty() {
        let alreadyCreated = Set([[String: Any]]().flatMap { getRelationIDs($0, field: AttendanceProps.student) })
        XCTAssertTrue(alreadyCreated.isEmpty)
    }

    // ─── Multiple students ────────────────────────────────────────────────────

    func testMixedStudents_correctSetReturned() {
        let pages = [
            makeLeavePage(studentID: "s1", start: "2026-04-24"),                       // single-day today     → on leave
            makeLeavePage(studentID: "s2", start: "2026-04-23"),                       // single-day yesterday → not on leave
            makeLeavePage(studentID: "s3", start: "2026-04-20", end: "2026-04-26"),    // multi-day covering   → on leave
            makeLeavePage(studentID: "s4", start: "2026-04-20", end: "2026-04-23"),    // multi-day ended      → not on leave
            makeLeavePage(studentID: "s5", start: "2026-04-24", end: "2026-04-28"),    // multi-day starts today → on leave
        ]
        let result = students_on_leave(from: pages, today: "2026-04-24")
        XCTAssertEqual(result, ["s1", "s3", "s5"])
    }
}
