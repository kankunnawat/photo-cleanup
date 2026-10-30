import Foundation

nonisolated enum MediaKind: String, Sendable, Codable {
    case photo
    case video
    case other
}

nonisolated struct AssetInfo: Hashable, Sendable, Identifiable {
    let id: AssetID
    let kind: MediaKind
    let isScreenshot: Bool
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: TimeInterval
    let isFavorite: Bool

    init(
        id: AssetID,
        kind: MediaKind = .photo,
        isScreenshot: Bool = false,
        creationDate: Date?,
        pixelWidth: Int = 4032,
        pixelHeight: Int = 3024,
        duration: TimeInterval = 0,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.isScreenshot = isScreenshot
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.isFavorite = isFavorite
    }
}
