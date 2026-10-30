import Testing
@testable import PhotoCleanup

struct DeckHistoryTests {
    let a = AssetID("a")
    let b = AssetID("b")
    let elsewhere = AssetID("elsewhere")

    @Test func undoTakesBackTheDecksSwipesNewestFirst() {
        var pending = PendingDecisions()
        var history = DeckHistory()
        history.swipe(.keep, for: a, in: &pending)
        history.swipe(.trash, for: b, in: &pending)

        #expect(history.undo(in: &pending) == b)
        #expect(pending.decision(for: b) == nil)
        #expect(pending.decision(for: a) == .keep)
        #expect(history.undo(in: &pending) == a)
        #expect(pending.isEmpty)
        #expect(!history.canUndo(in: pending))
    }

    @Test func undoNeverChangesADecisionMadeOutsideTheDeck() {
        var pending = PendingDecisions()
        pending.set(.trash, for: elsewhere)
        var history = DeckHistory()
        history.swipe(.keep, for: a, in: &pending)

        #expect(history.undo(in: &pending) == a)
        #expect(history.undo(in: &pending) == nil)
        #expect(history.undo(in: &pending) == nil)

        #expect(pending.entries == [.init(id: elsewhere, decision: .trash)])
    }

    @Test func undoSkipsASwipeThatWasChangedElsewhere() {
        var pending = PendingDecisions()
        var history = DeckHistory()
        history.swipe(.trash, for: a, in: &pending)
        history.swipe(.trash, for: b, in: &pending)
        pending.set(.keep, for: b)

        #expect(history.canUndo(in: pending))
        #expect(history.undo(in: &pending) == a)
        #expect(pending.decision(for: b) == .keep)
    }

    @Test func aSwipeTakenBackElsewhereCannotBeUndone() {
        var pending = PendingDecisions()
        var history = DeckHistory()
        history.swipe(.trash, for: a, in: &pending)
        pending.clear(a)
        pending.set(.keep, for: elsewhere)

        #expect(!history.canUndo(in: pending))
        #expect(history.undo(in: &pending) == nil)
        #expect(pending.entries == [.init(id: elsewhere, decision: .keep)])
    }
}
