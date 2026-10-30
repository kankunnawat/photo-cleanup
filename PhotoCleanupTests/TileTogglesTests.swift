import Testing
@testable import PhotoCleanup

struct TileTogglesTests {
    let ids = ["a", "b", "c", "d"].map(AssetID.init)

    @Test func tappingKeepsEveryTileInItsPlace() {
        var tiles = TileToggles(ids: ids)

        let first = tiles.toggle(ids[1])
        let second = tiles.toggle(ids[2])

        #expect(first && second)
        #expect(tiles.ids == ids)
        #expect(tiles.isFlipped(ids[1]))
        #expect(tiles.isFlipped(ids[2]))
        #expect(!tiles.isFlipped(ids[3]))
    }

    @Test func onlyUnflippedTilesAreActedOn() {
        var tiles = TileToggles(ids: ids)
        tiles.toggle(ids[0])
        tiles.toggle(ids[2])

        #expect(tiles.unflipped == [ids[1], ids[3]])
        #expect(tiles.unflippedCount == 2)
        #expect(tiles.flippedInOrder == [ids[0], ids[2]])
    }

    @Test func tappingTwiceRestoresTheTile() {
        var tiles = TileToggles(ids: ids)
        tiles.toggle(ids[1])

        let flippedAgain = tiles.toggle(ids[1])

        #expect(!flippedAgain)
        #expect(tiles.unflipped == ids)
    }

    @Test func idsThatAreNotTilesAreIgnored() {
        var tiles = TileToggles(ids: ids, flipped: [AssetID("gone"), ids[3]])

        let flipped = tiles.toggle(AssetID("stranger"))

        #expect(!flipped)
        #expect(tiles.flipped == [ids[3]])
        #expect(tiles.unflippedCount == 3)
    }
}
