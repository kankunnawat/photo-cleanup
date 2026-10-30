import Foundation

nonisolated struct CleanupLog: Sendable, Codable {
    struct Entry: Hashable, Sendable, Codable {
        let date: Date
        let deletedCount: Int
        let bytes: Int64
    }

    private(set) var entries: [Entry] = []

    init(entries: [Entry] = []) {
        self.entries = entries
    }

    var totalBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }
    var totalDeleted: Int { entries.reduce(0) { $0 + $1.deletedCount } }

    mutating func append(_ entry: Entry) {
        entries.append(entry)
    }
}
