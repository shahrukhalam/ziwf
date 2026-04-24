import Foundation
import Shared

// ─── Config ────────────────────────────────────────────────────────────────

let notionToken    = ProcessInfo.processInfo.environment["NOTION_TOKEN"]    ?? ""
let studentsDBID   = ProcessInfo.processInfo.environment["STUDENTS_DB_ID"]  ?? ""
let attendanceDBID = ProcessInfo.processInfo.environment["ATTENDANCE_DB_ID"] ?? ""
let leavesDBID     = ProcessInfo.processInfo.environment["LEAVES_DB_ID"]    ?? ""

// ─── Main ──────────────────────────────────────────────────────────────────

let notion = NotionClient(token: notionToken)
let today  = todayIST()

print("Running for date: \(today)")

// 1. Fetch all students
let students = try await notion.queryAll(databaseID: studentsDBID)
print("Found \(students.count) students")

// 2. Fetch today's leaves — filter where leave starts on or before today,
//    then keep only entries whose end date is today or later (or has no end date)
let leavePages = try await notion.queryAll(
    databaseID: leavesDBID,
    filter: ["property": LeavesProps.fromTo, "date": ["on_or_before": today]]
)

let studentsOnLeave = students_on_leave(from: leavePages, today: today)
print("Students on leave today: \(studentsOnLeave.count)")

// 3. Fetch today's existing attendance rows to avoid duplicates
let existing = try await notion.queryAll(
    databaseID: attendanceDBID,
    filter: ["property": AttendanceProps.date, "date": ["equals": today]]
)

let alreadyCreated = Set(existing.flatMap { getRelationIDs($0, field: AttendanceProps.student) })
print("Already created today: \(alreadyCreated.count) rows")

// 4. Create missing rows
var created = 0
for student in students {
    let studentID = student["id"] as! String
    guard !alreadyCreated.contains(studentID) else { continue }

    let studentName  = getTitle(student, field: StudentsProps.name)
    let studentClass = getSelect(student, field: StudentsProps.class_)
    let onLeave      = studentsOnLeave.contains(studentID)

    var properties: [String: Any] = [
        AttendanceProps.remarks: [
            "title": []
        ],
        AttendanceProps.student: [
            "relation": [["id": studentID]]
        ],
        AttendanceProps.date: [
            "date": ["start": today]
        ],
    ]

    if onLeave {
        properties[AttendanceProps.status] = ["select": ["name": "On Leave"]]
    }

    try await notion.createPage(databaseID: attendanceDBID, properties: properties)
    print("✓ Created: \(studentName) (\(studentClass ?? "No class"))\(onLeave ? " — On Leave" : "")")
    created += 1
}

print("\nDone. Created \(created) new attendance rows for \(today).")
