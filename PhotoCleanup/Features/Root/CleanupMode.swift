import SwiftUI

/// The ways to clean up, shown as Home tiles. Each mode knows its copy and how many assets it covers.
enum CleanupMode: String, CaseIterable, Identifiable, Hashable {
    case swipe
    case freeUp
    case screenshots
    case largeVideos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .swipe: "Swipe review"
        case .freeUp: "Free up space"
        case .screenshots: "Screenshots"
        case .largeVideos: "Large videos"
        }
    }

    var systemImage: String {
        switch self {
        case .swipe: "rectangle.stack"
        case .freeUp: "externaldrive.badge.minus"
        case .screenshots: "camera.viewfinder"
        case .largeVideos: "video"
        }
    }

    var tint: Color {
        switch self {
        case .swipe: .pink
        case .freeUp: .blue
        case .screenshots: .orange
        case .largeVideos: .purple
        }
    }

    @MainActor
    func summary(in model: AppModel) -> String {
        switch self {
        case .swipe:
            return "\(model.openCount.formatted()) to review"
        case .freeUp:
            return "Clear old photos"
        case .screenshots:
            return "\(model.screenshots.count.formatted()) found"
        case .largeVideos:
            let count = model.largeVideos.count
            return count == 1 ? "1 video" : "\(count.formatted()) videos"
        }
    }
}
