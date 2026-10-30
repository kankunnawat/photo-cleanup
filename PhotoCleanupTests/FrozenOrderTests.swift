import Testing
@testable import PhotoCleanup

struct FrozenOrderTests {
    let a = Fixtures.video("a", Fixtures.date(2025, 1))
    let b = Fixtures.video("b", Fixtures.date(2025, 2))
    let c = Fixtures.video("c", Fixtures.date(2025, 3))

    @Test func keepsTheFrozenOrderWhateverOrderTheItemsArriveIn() {
        let frozen = FrozenOrder([b.id, c.id, a.id])

        #expect(frozen.arrange([a, b, c]) == [b, c, a])
        #expect(frozen.arrange([c, a, b]) == [b, c, a])
    }

    @Test func itemsThatLeaveDropOutAndTheRestStayInOrder() {
        let frozen = FrozenOrder([b.id, c.id, a.id])

        #expect(frozen.arrange([a, b]) == [b, a])
    }

    @Test func newItemsGoLastInTheirOwnOrder() {
        let d = Fixtures.video("d", Fixtures.date(2025, 4))
        let e = Fixtures.video("e", Fixtures.date(2025, 5))
        let frozen = FrozenOrder([b.id, a.id])

        #expect(frozen.arrange([e, a, d, b]) == [b, a, e, d])
    }
}
