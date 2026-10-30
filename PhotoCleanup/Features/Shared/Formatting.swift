import Foundation

enum Formatting {
    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    /// A size total; while sizes are still being measured it says so, because the sum is partial.
    static func upTo(_ count: Int64, measuring: Bool) -> String {
        let total = "Up to \(bytes(count))"
        return measuring ? "\(total), measuring…" : total
    }

    static func items(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count.formatted()) items"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func monthTitle(_ key: MonthKey?) -> String {
        guard let key, let date = key.firstDay(in: .current) else { return "No date" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    static func day(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .omitted) ?? "No date"
    }
}
