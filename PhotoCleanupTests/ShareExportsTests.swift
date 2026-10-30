import Foundation
import Testing
@testable import PhotoCleanup

final class ShareExportsTests {
    let root = FileManager.default.temporaryDirectory.appending(path: "ShareExportsTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    isolated deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @Test func eachExportGetsItsOwnFolderAndKeepsThePhotoName() throws {
        let first = try ShareExports.makeFile(named: "IMG_0001.HEIC", in: root)
        let second = try ShareExports.makeFile(named: "IMG_0001.HEIC", in: root)

        #expect(first.lastPathComponent == "IMG_0001.HEIC")
        #expect(second.lastPathComponent == "IMG_0001.HEIC")
        #expect(first.deletingLastPathComponent() != second.deletingLastPathComponent())
        #expect(first.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL)
        #expect(exists(first) && exists(second))
    }

    @Test func discardRemovesOneExportAndIsSafeToRepeat() throws {
        let kept = try ShareExports.makeFile(named: "a.jpg", in: root)
        let discarded = try ShareExports.makeFile(named: "b.jpg", in: root)

        try ShareExports.discard(discarded)
        try ShareExports.discard(discarded)

        #expect(!exists(discarded.deletingLastPathComponent()))
        #expect(exists(kept))
    }

    @Test func clearRemovesEveryExportAndSucceedsWhenNothingIsThere() throws {
        let file = try ShareExports.makeFile(named: "a.jpg", in: root)

        try ShareExports.clear(root)
        try ShareExports.clear(root)

        #expect(!exists(file))
        #expect(!exists(root))
    }
}
