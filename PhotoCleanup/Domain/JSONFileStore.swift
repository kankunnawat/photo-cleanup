import Foundation

/// Reads and writes one Codable value as a JSON file.
nonisolated struct JSONFileStore<Value: Codable & Sendable>: Sendable {
    let url: URL

    func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }

    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }

    @concurrent func loadInBackground() async throws -> Value? {
        try load()
    }

    @concurrent func saveInBackground(_ value: Value) async throws {
        try save(value)
    }

    func remove() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
