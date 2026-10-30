import Foundation

nonisolated struct SizeCache: Sendable, Codable {
    private(set) var bytes: [AssetID: Int64] = [:]

    init(bytes: [AssetID: Int64] = [:]) {
        self.bytes = bytes
    }

    subscript(id: AssetID) -> Int64? {
        bytes[id]
    }

    var count: Int { bytes.count }

    mutating func merge(_ sizes: [AssetID: Int64]) {
        bytes.merge(sizes) { _, new in new }
    }

    /// Unknown sizes count as zero.
    func total(of ids: some Sequence<AssetID>) -> Int64 {
        ids.reduce(0) { $0 + (bytes[$1] ?? 0) }
    }

    func missing(from ids: some Sequence<AssetID>) -> [AssetID] {
        ids.filter { bytes[$0] == nil }
    }

    mutating func prune(keeping ids: Set<AssetID>) {
        bytes = bytes.filter { ids.contains($0.key) }
    }
}
