import Foundation

/// Files handed to the share sheet. Each export gets its own folder, so the file keeps the photo's name.
nonisolated enum ShareExports {
    static let folder = FileManager.default.temporaryDirectory.appending(path: "Share", directoryHint: .isDirectory)

    /// `root` is for tests; the app always uses `folder`.
    static func makeFile(named name: String, in root: URL = folder) throws -> URL {
        let directory = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: name)
        guard FileManager.default.createFile(atPath: file.path(percentEncoded: false), contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSURLErrorKey: file])
        }
        return file
    }

    /// Removes one export. Safe to call more than once.
    static func discard(_ file: URL) throws {
        try removeIfPresent(file.deletingLastPathComponent())
    }

    static func clear(_ root: URL = folder) throws {
        try removeIfPresent(root)
    }

    private static func removeIfPresent(_ url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }
}
