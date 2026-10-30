import Foundation

/// Decisions waiting for Apply, in the order they were made.
nonisolated struct PendingDecisions: Sendable, Codable {
    struct Entry: Hashable, Sendable, Codable {
        let id: AssetID
        let decision: Decision
    }

    private var order: [AssetID] = []
    private var decisions: [AssetID: Decision] = [:]

    init() {}

    var entries: [Entry] {
        order.compactMap { id in decisions[id].map { Entry(id: id, decision: $0) } }
    }

    var isEmpty: Bool { decisions.isEmpty }
    var keeps: [AssetID] { order.filter { decisions[$0] == .keep } }
    var trash: [AssetID] { order.filter { decisions[$0] == .trash } }
    var allIDs: [AssetID] { order }

    func decision(for id: AssetID) -> Decision? {
        decisions[id]
    }

    mutating func set(_ decision: Decision, for id: AssetID) {
        set(decision, for: [id])
    }

    mutating func set(_ decision: Decision, for ids: some Sequence<AssetID>) {
        for id in ids where decisions[id] != decision {
            write(decision, for: id)
        }
    }

    /// Takes a decision back by user request.
    mutating func clear(_ id: AssetID) {
        write(nil, for: id)
    }

    /// Takes many decisions back in one pass over `order`.
    mutating func clear(_ ids: some Sequence<AssetID>) {
        let taken = Set(ids)
        guard !taken.isEmpty else { return }
        order.removeAll { taken.contains($0) }
        for id in taken { decisions[id] = nil }
    }

    /// Drops decisions that are settled (applied, gone, or now protected).
    mutating func resolve(_ ids: some Sequence<AssetID>) {
        let settled = Set(ids)
        guard !settled.isEmpty else { return }
        order.removeAll { settled.contains($0) }
        for id in settled { decisions[id] = nil }
    }

    private mutating func write(_ decision: Decision?, for id: AssetID) {
        switch (decisions[id], decision) {
        case (nil, let new?):
            order.append(id)
            decisions[id] = new
        case (.some, let new?):
            decisions[id] = new
        case (.some, nil):
            order.removeAll { $0 == id }
            decisions[id] = nil
        case (nil, nil):
            break
        }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case entries
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        for entry in try container.decode([Entry].self, forKey: .entries) {
            write(entry.decision, for: entry.id)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .entries)
    }
}
