import Foundation

// ─── Config ────────────────────────────────────────────────────────────────

// Exact property names as they appear in your Notion databases
public enum StudentsProps {
    public static let name   = "Name"   // Title field
    public static let class_ = "Class"  // Select field
}

public enum AttendanceProps {
    public static let remarks    = "Remarks"         // Title field
    public static let student    = "Student"        // Relation → Students DB
    public static let date       = "Date"           // Date field
    public static let class_     = "Class"          // Rollup from Students DB (read-only, auto-populated)
    public static let status     = "Status"         // Select field: Present / Absent / Late / On Leave
}

public enum LeavesProps {
    public static let student = "Student"   // Relation → Students DB
    public static let fromTo  = "From - To" // Date range field
    public static let reason  = "Reason"    // Title field
}

// ─── Notion API Client ─────────────────────────────────────────────────────

public struct NotionClient {
    public let token: String
    let session = URLSession.shared

    public init(token: String) {
        self.token = token
    }

    public func request(method: String, path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
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
    public func queryAll(databaseID: String, filter: [String: Any]? = nil) async throws -> [[String: Any]] {
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

    public func createPage(databaseID: String, properties: [String: Any]) async throws {
        _ = try await request(method: "POST", path: "/pages", body: [
            "parent": ["database_id": databaseID],
            "properties": properties
        ])
    }

    public func archivePage(pageID: String) async throws {
        _ = try await request(method: "PATCH", path: "/pages/\(pageID)", body: [
            "archived": true
        ])
    }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

/// Returns today's date in IST as "YYYY-MM-DD"
public func todayIST() -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let now = Date()
    let comps = cal.dateComponents([.year, .month, .day], from: now)
    return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
}

/// Returns today's midnight in IST as ISO 8601 (for created_time filters)
public func todayMidnightIST() -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let now = Date()
    let comps = cal.dateComponents([.year, .month, .day], from: now)
    return String(format: "%04d-%02d-%02dT00:00:00+05:30", comps.year!, comps.month!, comps.day!)
}

/// Returns yesterday's midnight in IST as ISO 8601 (for created_time filters)
public func yesterdayMidnightIST() -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
    let comps = cal.dateComponents([.year, .month, .day], from: yesterday)
    return String(format: "%04d-%02d-%02dT00:00:00+05:30", comps.year!, comps.month!, comps.day!)
}

public func getTitle(_ page: [String: Any], field: String) -> String {
    let props = page["properties"] as? [String: Any] ?? [:]
    let prop  = props[field] as? [String: Any] ?? [:]
    let title = prop["title"] as? [[String: Any]] ?? []
    return title.first?["plain_text"] as? String ?? "Unknown"
}

public func getSelect(_ page: [String: Any], field: String) -> String? {
    let props  = page["properties"] as? [String: Any] ?? [:]
    let prop   = props[field] as? [String: Any] ?? [:]
    let select = prop["select"] as? [String: Any]
    return select?["name"] as? String
}

public func getRelationIDs(_ page: [String: Any], field: String) -> [String] {
    let props    = page["properties"] as? [String: Any] ?? [:]
    let prop     = props[field] as? [String: Any] ?? [:]
    let relation = prop["relation"] as? [[String: Any]] ?? []
    return relation.compactMap { $0["id"] as? String }
}

/// Returns (start, end?) for a date-range property; end is nil if no end date set
public func getDateRange(_ page: [String: Any], field: String) -> (start: String, end: String?)? {
    let props = page["properties"] as? [String: Any] ?? [:]
    let prop  = props[field] as? [String: Any] ?? [:]
    let date  = prop["date"] as? [String: Any] ?? [:]
    guard let start = date["start"] as? String else { return nil }
    let end = date["end"] as? String
    return (start, end)
}
