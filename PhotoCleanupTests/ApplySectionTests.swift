import Testing
@testable import PhotoCleanup

struct ApplySectionTests {
    let ids = ["a", "b", "c", "d"].map(AssetID.init)

    @Test func everyTileStartsWithTheSectionDecision() {
        let section = ApplySection(ids: ids, decision: .trash)

        #expect(ids.allSatisfy { section.decision(for: $0) == .trash })
        #expect(section.count(of: .trash) == 4)
        #expect(section.count(of: .keep) == 0)
        #expect(section.hasDecisions)
    }

    @Test(arguments: [Decision.trash, .keep])
    func tapSwitchesBetweenKeepAndDelete(section decision: Decision) {
        var section = ApplySection(ids: ids, decision: decision)

        #expect(section.tap(ids[1]) == decision.opposite)
        #expect(section.decision(for: ids[1]) == decision.opposite)
        #expect(section.count(of: decision.opposite) == 1)
        #expect(section.count(of: decision) == 3)

        #expect(section.tap(ids[1]) == decision)
        #expect(section.decision(for: ids[1]) == decision)
        #expect(section.count(of: decision.opposite) == 0)
        #expect(section.count(of: decision) == 4)
    }

    @Test func takeBackAllClearsEveryTile() {
        var section = ApplySection(ids: ids, decision: .trash)
        section.tap(ids[0])

        section.takeBackAll()

        #expect(ids.allSatisfy { section.decision(for: $0) == nil })
        #expect(section.count(of: .trash) == 0)
        #expect(section.count(of: .keep) == 0)
        #expect(!section.hasDecisions)
        #expect(ids.allSatisfy(section.contains))
    }

    @Test func tappingATakenBackTileGivesItTheSectionDecision() {
        var section = ApplySection(ids: ids, decision: .keep)
        section.takeBackAll()

        #expect(section.tap(ids[2]) == .keep)
        #expect(section.decision(for: ids[2]) == .keep)
        #expect(section.decision(for: ids[0]) == nil)
        #expect(section.count(of: .keep) == 1)
        #expect(section.hasDecisions)
    }

    @Test func restoreAllOverwritesSwitchedTiles() {
        var section = ApplySection(ids: ids, decision: .trash)
        section.tap(ids[0])
        section.takeBackAll()
        section.tap(ids[3])
        section.tap(ids[3])

        section.restoreAll()

        #expect(ids.allSatisfy { section.decision(for: $0) == .trash })
        #expect(section.count(of: .trash) == 4)
        #expect(section.count(of: .keep) == 0)
    }

    @Test func tilesNeverMove() {
        var section = ApplySection(ids: ids, decision: .trash)

        section.tap(ids[1])
        section.takeBackAll()
        section.tap(ids[2])
        section.restoreAll()

        #expect(section.ids == ids)
    }

    @Test func aTileWhosePendingDecisionChangedElsewhereLeavesAndTheRestStayInOrder() {
        var section = ApplySection(ids: ids, decision: .trash)
        section.tap(ids[1])
        var pending = PendingDecisions()
        pending.set(.trash, for: [ids[0], ids[3]])
        pending.set(.keep, for: ids[1])

        section.dropTiles(disagreeingWith: pending)

        #expect(section.ids == [ids[0], ids[1], ids[3]])
        #expect(!section.contains(ids[2]))
        #expect(section.decision(for: ids[2]) == nil)
        #expect(section.decision(for: ids[1]) == .keep)
        #expect(section.count(of: .trash) == 2)
        #expect(section.count(of: .keep) == 1)
        #expect(section.hasDecisions)
    }

    @Test func aSwitchedTileThatLeavesNoLongerCounts() {
        var section = ApplySection(ids: ids, decision: .keep)
        section.tap(ids[2])
        var pending = PendingDecisions()
        pending.set(.keep, for: [ids[0], ids[1], ids[3]])

        section.dropTiles(disagreeingWith: pending)

        #expect(section.ids == [ids[0], ids[1], ids[3]])
        #expect(section.count(of: .trash) == 0)
        #expect(section.count(of: .keep) == 3)
    }

    @Test func takenBackTilesStayWhenNothingIsPending() {
        var section = ApplySection(ids: ids, decision: .trash)
        section.takeBackAll()

        section.dropTiles(disagreeingWith: PendingDecisions())

        #expect(section.ids == ids)
        #expect(!section.hasDecisions)
        #expect(section.tap(ids[0]) == .trash)
    }

    @Test func droppingEveryTileLeavesAnEmptySection() {
        var section = ApplySection(ids: ids, decision: .trash)

        section.dropTiles(disagreeingWith: PendingDecisions())

        #expect(section.ids.isEmpty)
        #expect(section.count(of: .trash) == 0)
        #expect(section.count(of: .keep) == 0)
        #expect(!section.hasDecisions)
    }

    @Test func idsOutsideTheSectionAreIgnored() {
        var section = ApplySection(ids: ids, decision: .trash)
        let stranger = AssetID("z")

        #expect(!section.contains(stranger))
        #expect(section.tap(stranger) == nil)
        #expect(section.decision(for: stranger) == nil)
        #expect(section.count(of: .trash) == 4)
        #expect(section.count(of: .keep) == 0)
    }
}
