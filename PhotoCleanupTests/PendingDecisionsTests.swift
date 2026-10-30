import Foundation
import Testing
@testable import PhotoCleanup

struct PendingDecisionsTests {
    let a = AssetID("a")
    let b = AssetID("b")
    let c = AssetID("c")

    @Test func keepsDecisionOrderAndSplitsByDecision() {
        var pending = PendingDecisions()
        pending.set(.trash, for: a)
        pending.set(.keep, for: b)
        pending.set(.trash, for: c)

        #expect(pending.allIDs == [a, b, c])
        #expect(pending.keeps == [b])
        #expect(pending.trash == [a, c])
    }

    @Test func changingADecisionKeepsItsPosition() {
        var pending = PendingDecisions()
        pending.set(.trash, for: a)
        pending.set(.trash, for: b)
        pending.set(.keep, for: a)

        #expect(pending.entries == [.init(id: a, decision: .keep), .init(id: b, decision: .trash)])
    }

    @Test func clearRemovesADecision() {
        var pending = PendingDecisions()
        pending.set(.trash, for: [a, b])

        pending.clear(a)

        #expect(pending.allIDs == [b])
        #expect(pending.decision(for: a) == nil)
    }

    @Test func clearingManyKeepsTheOrderOfTheRest() {
        let d = AssetID("d")
        var pending = PendingDecisions()
        pending.set(.trash, for: a)
        pending.set(.keep, for: b)
        pending.set(.trash, for: c)
        pending.set(.trash, for: d)

        pending.clear([c, a, AssetID("never-pending")])

        #expect(pending.entries == [.init(id: b, decision: .keep), .init(id: d, decision: .trash)])
        #expect(pending.decision(for: a) == nil)
        #expect(pending.decision(for: c) == nil)
    }

    @Test func resolveDropsDecisions() {
        var pending = PendingDecisions()
        pending.set(.keep, for: a)
        pending.set(.trash, for: b)

        pending.resolve([a])

        #expect(pending.allIDs == [b])
    }

    @Test func jsonRoundTripKeepsEntries() throws {
        var pending = PendingDecisions()
        pending.set(.trash, for: c)
        pending.set(.keep, for: a)
        pending.set(.trash, for: b)

        let decoded = try JSONDecoder().decode(PendingDecisions.self, from: JSONEncoder().encode(pending))

        #expect(decoded.entries == pending.entries)
    }

    @Test func fileStoreRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "pending.json")
        let store = JSONFileStore<PendingDecisions>(url: url)
        defer { try? store.remove() }
        var pending = PendingDecisions()
        pending.set(.keep, for: a)
        pending.set(.trash, for: b)

        #expect(try store.load() == nil)
        try store.save(pending)

        #expect(try store.load()?.entries == pending.entries)
    }
}
