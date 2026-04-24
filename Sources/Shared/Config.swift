import Foundation

public enum Config {
    public static let notionToken    = ProcessInfo.processInfo.environment["NOTION_TOKEN"]     ?? ""
    public static let studentsDBID   = ProcessInfo.processInfo.environment["STUDENTS_DB_ID"]   ?? ""
    public static let attendanceDBID = ProcessInfo.processInfo.environment["ATTENDANCE_DB_ID"] ?? ""
    public static let leavesDBID     = ProcessInfo.processInfo.environment["LEAVES_DB_ID"]     ?? ""
}
