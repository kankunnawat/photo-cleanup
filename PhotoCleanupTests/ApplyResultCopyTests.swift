import Testing
@testable import PhotoCleanup

@MainActor
struct ApplyResultCopyTests {
    func report(_ outcome: ApplyReport.Outcome, kept: Int = 0, missing: Int = 0, protected: Int = 0) -> ApplyResultCard {
        ApplyResultCard(report: ApplyReport(
            outcome: outcome,
            pending: PendingDecisions(),
            keptCount: kept,
            logEntry: nil,
            droppedMissing: missing,
            droppedProtected: protected,
            measuredSizes: [:]
        ))
    }

    @Test func everythingDroppedAndNoKeepsSaysNothingLeft() {
        let card = report(.completed, missing: 1, protected: 2)

        #expect(card.headline == "Nothing left to apply")
        #expect(card.details == [
            "Skipped 2 items that are now protected.",
            "Removed 1 item that is no longer in your library.",
        ])
    }

    @Test func keepsOnlyRunCountsTheKeeps() {
        #expect(report(.completed, kept: 3).headline == "Added 3 items to Keep")
    }

    @Test func failureCopyDoesNotContradictDroppedItems() {
        let card = report(.failed("Could not delete: disk on fire"), protected: 1)

        #expect(card.headline == "Apply stopped")
        #expect(card.details == [
            "Could not delete: disk on fire",
            "Nothing was deleted. Your other decisions are still queued.",
            "Skipped 1 item that is now protected.",
        ])
    }
}
