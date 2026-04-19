import Foundation

// ─── Config ────────────────────────────────────────────────────────────────

let notionToken    = ProcessInfo.processInfo.environment["NOTION_TOKEN"]    ?? ""
let studentsDBID   = ProcessInfo.processInfo.environment["STUDENTS_DB_ID"]  ?? ""
let attendanceDBID = ProcessInfo.processInfo.environment["ATTENDANCE_DB_ID"] ?? ""

// Exact property names as they appear in your Notion databases
enum StudentsProps {
    static let name  = "Name"   // Title field
    static let class_ = "Class" // Select field
}

enum AttendanceProps {
    static let statusNote    = "Status Note"    // Title field e.g. "A - Apr 7"
    static let student = "Student" // Relation → Students DB
    static let date    = "Date"    // Date field
    static let class_  = "Class"   // Rollup from Students DB (read-only, auto-populated)
    static let status  = "Status"  // Select field: Present / Absent / Late
}

// ─── Notion API Client ─────────────────────────────────────────────────────

struct NotionClient {
    let token: String
    let session = URLSession.shared

    func request(method: String, path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        let url = URLComponents(string: "https://api.notion.com/v1\(path)")!
        var req = URLRequest(url: url.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, _) = try await session.data(for: req)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    /// Fetches all pages from a paginated Notion database query
    func queryAll(databaseID: String, filter: [String: Any]? = nil) async throws -> [[String: Any]] {
        var pages: [[String: Any]] = []
        var cursor: String? = nil
        repeat {
            var body: [String: Any] = ["page_size": 100]
            if let filter { body["filter"] = filter }
            if let cursor { body["start_cursor"] = cursor }
            let res = try await request(method: "POST", path: "/databases/\(databaseID)/query", body: body)
            let results = res["results"] as? [[String: Any]] ?? []
            pages.append(contentsOf: results)
            cursor = (res["has_more"] as? Bool == true) ? res["next_cursor"] as? String : nil
        } while cursor != nil
        return pages
    }

    func createPage(databaseID: String, properties: [String: Any]) async throws {
        _ = try await request(method: "POST", path: "/pages", body: [
            "parent": ["database_id": databaseID],
            "properties": properties
        ])
    }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

/// Returns today's date in IST as "YYYY-MM-DD"
func todayIST() -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let now = Date()
    let comps = cal.dateComponents([.year, .month, .day], from: now)
    return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
}


func getTitle(_ page: [String: Any], field: String) -> String {
    let props = page["properties"] as? [String: Any] ?? [:]
    let prop  = props[field] as? [String: Any] ?? [:]
    let title = prop["title"] as? [[String: Any]] ?? []
    return title.first?["plain_text"] as? String ?? "Unknown"
}

func getSelect(_ page: [String: Any], field: String) -> String? {
    let props  = page["properties"] as? [String: Any] ?? [:]
    let prop   = props[field] as? [String: Any] ?? [:]
    let select = prop["select"] as? [String: Any]
    return select?["name"] as? String
}

func getRelationIDs(_ page: [String: Any], field: String) -> [String] {
    let props    = page["properties"] as? [String: Any] ?? [:]
    let prop     = props[field] as? [String: Any] ?? [:]
    let relation = prop["relation"] as? [[String: Any]] ?? []
    return relation.compactMap { $0["id"] as? String }
}

// ─── Main ──────────────────────────────────────────────────────────────────

let notion    = NotionClient(token: notionToken)
let today     = todayIST()

print("Running for date: \(today)")

// 1. Fetch all students
let students = try await notion.queryAll(databaseID: studentsDBID)
print("Found \(students.count) students")

// 2. Fetch today's existing attendance rows to avoid duplicates
let existing = try await notion.queryAll(
    databaseID: attendanceDBID,
    filter: ["property": AttendanceProps.date, "date": ["equals": today]]
)

let alreadyCreated = Set(existing.flatMap { getRelationIDs($0, field: AttendanceProps.student) })
print("Already created today: \(alreadyCreated.count) rows")

// 3. Create missing rows
var created = 0
for student in students {
    let studentID = student["id"] as! String
    guard !alreadyCreated.contains(studentID) else { continue }

    let studentName  = getTitle(student, field: StudentsProps.name)
    let studentClass = getSelect(student, field: StudentsProps.class_)

    let properties: [String: Any] = [
        AttendanceProps.statusNote: [
            "title": []
        ],
        AttendanceProps.student: [
            "relation": [["id": studentID]]
        ],
        AttendanceProps.date: [
            "date": ["start": today]
        ],
    ]

    try await notion.createPage(databaseID: attendanceDBID, properties: properties)
    print("✓ Created: \(studentName) (\(studentClass ?? "No class"))")
    created += 1
}

print("\nDone. Created \(created) new attendance rows for \(today).")
