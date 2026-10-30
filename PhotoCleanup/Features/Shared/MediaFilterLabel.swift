extension MediaFilter {
    var label: String {
        switch self {
        case .all: "All"
        case .photos: "Photos"
        case .videos: "Videos"
        }
    }
}
