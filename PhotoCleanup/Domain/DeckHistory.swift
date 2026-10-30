/// Undo for one swipe deck while it is open. It reverts only swipes made in that deck,
/// and skips a swipe whose decision was changed somewhere else since.
nonisolated struct DeckHistory: Sendable {
    private struct Swipe: Sendable {
        let id: AssetID
        let decision: Decision
    }

    private var swipes: [Swipe] = []

    /// Decides an undecided card and remembers the swipe.
    mutating func swipe(_ decision: Decision, for id: AssetID, in pending: inout PendingDecisions) {
        pending.set(decision, for: id)
        swipes.append(Swipe(id: id, decision: decision))
    }

    func canUndo(in pending: PendingDecisions) -> Bool {
        swipes.contains { pending.decision(for: $0.id) == $0.decision }
    }

    /// Takes back the latest swipe that still stands and returns its card, which is undecided again.
    mutating func undo(in pending: inout PendingDecisions) -> AssetID? {
        while let last = swipes.popLast() {
            if pending.decision(for: last.id) == last.decision {
                pending.clear(last.id)
                return last.id
            }
        }
        return nil
    }
}
