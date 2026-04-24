import Foundation
import Shared

// ─── Config ────────────────────────────────────────────────────────────────

let notionToken  = ProcessInfo.processInfo.environment["NOTION_TOKEN"]   ?? ""
let studentsDBID = ProcessInfo.processInfo.environment["STUDENTS_DB_ID"] ?? ""
let leavesDBID   = ProcessInfo.processInfo.environment["LEAVES_DB_ID"]   ?? ""

// ─── Main ──────────────────────────────────────────────────────────────────

let notion            = NotionClient(token: notionToken)
let today             = todayIST()
let todayMidnight     = todayMidnightIST()
let yesterdayMidnight = yesterdayMidnightIST()

print("Running for date: \(today)")

// 1. Delete yesterday's pages with empty From - To (no leave was marked)
let stalePages = try await notion.queryAll(
    databaseID: leavesDBID,
    filter: [
        "and": [
            ["timestamp": "created_time", "created_time": ["on_or_after": yesterdayMidnight]],
            ["timestamp": "created_time", "created_time": ["before": todayMidnight]],
            ["property": LeavesProps.fromTo, "date": ["is_empty": true]]
        ]
    ]
)
print("Deleting \(stalePages.count) empty pages from yesterday")
for page in stalePages {
    let pageID = page["id"] as! String
    try await notion.deletePage(pageID: pageID)
}

// 2. Fetch all students
let students = try await notion.queryAll(databaseID: studentsDBID)
print("Found \(students.count) students")

// 3. Fetch today's already-created leave pages to avoid duplicates
let existingToday = try await notion.queryAll(
    databaseID: leavesDBID,
    filter: ["timestamp": "created_time", "created_time": ["on_or_after": todayMidnight]]
)
let alreadyCreated = Set(existingToday.flatMap { getRelationIDs($0, field: LeavesProps.student) })
print("Already created today: \(alreadyCreated.count) rows")

// 4. Create missing pages
var created = 0
for student in students {
    let studentID = student["id"] as! String
    guard !alreadyCreated.contains(studentID) else { continue }

    let studentName  = getTitle(student, field: StudentsProps.name)
    let studentClass = getSelect(student, field: StudentsProps.class_)

    let properties: [String: Any] = [
        LeavesProps.reason: [
            "title": []
        ],
        LeavesProps.student: [
            "relation": [["id": studentID]]
        ],
    ]

    try await notion.createPage(databaseID: leavesDBID, properties: properties)
    print("✓ Created: \(studentName) (\(studentClass ?? "No class"))")
    created += 1
}

print("\nDone. Created \(created) new leave rows for \(today).")
