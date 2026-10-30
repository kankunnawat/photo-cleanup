/// Which media kinds a screen shows. Assets that are neither photo nor video show only under All.
nonisolated enum MediaFilter: CaseIterable, Hashable, Sendable {
    case all, photos, videos

    func includes(_ kind: MediaKind) -> Bool {
        switch self {
        case .all: true
        case .photos: kind == .photo
        case .videos: kind == .video
        }
    }
}
