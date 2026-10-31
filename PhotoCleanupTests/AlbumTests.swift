import Foundation
import Testing
@testable import PhotoCleanup

final class AlbumTests {
    let a = AssetID("a")
    let b = AssetID("b")
    let c = AssetID("c")
    let suite = "AlbumTests-\(UUID().uuidString)"
    let directory: URL
    let defaults: UserDefaults
    let persistence: Persistence

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: suite)
        defaults = try #require(UserDefaults(suiteName: suite))
        persistence = Persistence(directory: directory, defaults: defaults)
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }

    func makeModel(albums: [AlbumInfo] = [], disabled: Set<String> = []) async -> (AppModel, FakePhotoLibrary) {
        let library = FakePhotoLibrary(assets: [
            Fixtures.photo("a", Fixtures.date(2025, 1)),
            Fixtures.photo("b", Fixtures.date(2025, 2)),
            Fixtures.photo("c", Fixtures.date(2025, 3)),
        ])
        await library.configure { $0.albums = albums }
        persistence.saveDisabledAlbumIDs(disabled)
        let model = AppModel(library: library, persistence: persistence)
        await model.start()
        return (model, library)
    }

    func album(_ id: String, _ members: [AssetID] = []) -> AlbumInfo {
        AlbumInfo(id: id, title: id.capitalized, assetIDs: Set(members))
    }

    func members(of albumID: String, in model: AppModel) -> Set<AssetID>? {
        model.sources.albums.first { $0.id == albumID }?.assetIDs
    }

    @Test func createMakesANewProtectedAlbumHoldingThePhoto() async throws {
        let (model, library) = await makeModel(albums: [album("zoo")])

        try await model.createAlbum(titled: "Pets", adding: [a])

        #expect(await library.calls == [.createAlbum("Pets"), .add([a], toAlbum: "created-1")])
        #expect(model.sources.albums.map(\.title) == ["Pets", "Zoo"])
        #expect(members(of: "created-1", in: model) == [a])
        #expect(model.protected.contains(a))
        #expect(model.recentAlbums.map(\.id) == ["created-1"])
    }

    @Test func addThenRemoveUpdatesMembershipAtOnce() async throws {
        let (model, library) = await makeModel(albums: [album("trip")])

        try await model.add([a], toAlbum: "trip")
        #expect(members(of: "trip", in: model) == [a])
        #expect(model.protected.contains(a))

        try await model.remove([a], fromAlbum: "trip")
        #expect(members(of: "trip", in: model) == [])
        #expect(!model.protected.contains(a))
        #expect(await library.albums.first?.assetIDs == [])
    }

    @Test func addingToAProtectedAlbumClearsAPendingDeleteAndKeepsAPendingKeep() async throws {
        let (model, _) = await makeModel(albums: [album("trip")])
        model.decide(.trash, for: a)
        model.decide(.keep, for: b)

        try await model.add([a], toAlbum: "trip")
        try await model.add([b], toAlbum: "trip")

        #expect(model.pending.decision(for: a) == nil)
        #expect(model.pending.decision(for: b) == .keep)
        #expect(model.pendingSummary.trashCount == 0)
    }

    @Test func aBatchAddIsOneLibraryCallAndOnePendingWrite() async throws {
        let (model, library) = await makeModel(albums: [album("trip", [b])])
        model.decide(.trash, for: [a, c])
        model.decide(.keep, for: b)
        let revisionBefore = model.revision

        try await model.add([a, b, c], toAlbum: "trip")

        #expect(await library.calls == [.add([a, b, c], toAlbum: "trip")])
        #expect(members(of: "trip", in: model) == [a, b, c])
        #expect(model.pending.decision(for: a) == nil)
        #expect(model.pending.decision(for: c) == nil)
        #expect(model.pending.decision(for: b) == .keep)
        // One bump for the album change and one for clearing both deletes.
        #expect(model.revision == revisionBefore + 2)
        #expect(model.recentAlbums.map(\.id) == ["trip"])
    }

    @Test func aBatchRemoveTakesEveryItemOutInOneCall() async throws {
        let (model, library) = await makeModel(albums: [album("trip", [a, b, c])])

        try await model.remove([a, c], fromAlbum: "trip")

        #expect(await library.calls == [.remove([a, c], fromAlbum: "trip")])
        #expect(members(of: "trip", in: model) == [b])
        #expect(!model.protected.contains(a))
        #expect(!model.protected.contains(c))
        #expect(model.pending.isEmpty)
    }

    @Test func createAddsEveryItemToTheNewAlbum() async throws {
        let (model, library) = await makeModel()

        try await model.createAlbum(titled: "Gym", adding: [a, b])

        #expect(await library.calls == [.createAlbum("Gym"), .add([a, b], toAlbum: "created-1")])
        #expect(members(of: "created-1", in: model) == [a, b])
    }

    @Test func addingToASwitchedOffAlbumClearsNothing() async throws {
        let (model, _) = await makeModel(albums: [album("trip")], disabled: ["trip"])
        model.decide(.trash, for: a)

        try await model.add([a], toAlbum: "trip")

        #expect(members(of: "trip", in: model) == [a])
        #expect(model.pending.decision(for: a) == .trash)
        #expect(!model.protected.contains(a))
    }

    @Test func removingNeverQueuesADelete() async throws {
        let (model, library) = await makeModel(albums: [album("trip", [a])])

        try await model.remove([a], fromAlbum: "trip")

        #expect(model.pending.decision(for: a) == nil)
        #expect(await library.calls == [.remove([a], fromAlbum: "trip")])
    }

    @Test func aFailedWriteLeavesEverythingAsItWas() async throws {
        let (model, library) = await makeModel(albums: [album("trip")])
        await library.configure { $0.albumWritesFail = true }
        model.decide(.trash, for: a)

        await #expect(throws: PhotoLibraryError.albumUnavailable) {
            try await model.add([a], toAlbum: "trip")
        }

        #expect(members(of: "trip", in: model) == [])
        #expect(model.pending.decision(for: a) == .trash)
        #expect(model.recentAlbums.isEmpty)
    }

    @Test(.timeLimit(.minutes(1))) func aRefreshThatReadBeforeAnAddDoesNotUndoIt() async throws {
        let (model, library) = await makeModel(albums: [album("trip")])
        let readsBefore = await library.protectionSourcesCalls
        await library.configure { $0.holdNextProtectionSources = true }
        let refresh = Task { await model.refresh() }
        await library.waitUntilProtectionSourcesHeld()

        try await model.add([a], toAlbum: "trip")
        await library.releaseProtectionSources()
        await refresh.value

        #expect(members(of: "trip", in: model) == [a])
        #expect(model.protected.contains(a))
        #expect(await library.protectionSourcesCalls == readsBefore + 2)
    }

    @Test func createListsTheNewAlbumOnceWhenARefreshAlreadyFoundIt() async throws {
        let (model, library) = await makeModel()
        await library.configure { $0.albums = [AlbumInfo(id: "created-1", title: "Trip", assetIDs: [])] }
        await model.refresh()

        try await model.createAlbum(titled: "Trip", adding: [a])

        #expect(model.sources.albums.filter { $0.id == "created-1" }.count == 1)
        #expect(members(of: "created-1", in: model) == [a])
    }

    @Test func recentsKeepTheLastThreeAddsMostRecentFirstAndPersist() async throws {
        let (model, _) = await makeModel(albums: ["w", "x", "y", "z"].map { album($0) })

        for albumID in ["x", "y", "z", "w", "y"] {
            try await model.add([a], toAlbum: albumID)
        }
        try await model.remove([a], fromAlbum: "x")

        #expect(model.recentAlbums.map(\.id) == ["y", "w", "z"])
        let (reopened, _) = await makeModel(albums: ["w", "x", "y", "z"].map { album($0) })
        #expect(reopened.recentAlbums.map(\.id) == ["y", "w", "z"])
    }

    @Test func recentsDropAlbumsThatNoLongerExist() async throws {
        let (model, library) = await makeModel(albums: ["x", "y"].map { album($0) })
        try await model.add([a], toAlbum: "x")
        try await model.add([a], toAlbum: "y")

        await library.configure { $0.albums.removeAll { $0.id == "y" } }
        await model.refresh()

        #expect(model.recentAlbums.map(\.id) == ["x"])
        #expect(model.recentAlbumIDs == ["x"])
        #expect(persistence.loadRecentAlbumIDs() == ["x"])
    }
}
