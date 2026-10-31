import Testing
@testable import PhotoCleanup

struct AlbumMembershipTests {
    let a = AssetID("a")
    let b = AssetID("b")

    @Test func allSomeOrNoneOfTheItemsAreInTheAlbum() {
        #expect(AlbumMembership(of: [a, b], in: [a, b, AssetID("other")]) == .all)
        #expect(AlbumMembership(of: [a, b], in: [b]) == .some)
        #expect(AlbumMembership(of: [a, b], in: [AssetID("other")]) == .none)
    }

    @Test func oneItemIsEitherInOrOut() {
        #expect(AlbumMembership(of: [a], in: [a]) == .all)
        #expect(AlbumMembership(of: [a], in: []) == .none)
    }
}
