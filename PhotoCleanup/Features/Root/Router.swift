import Observation

enum DeckSource: Hashable {
    case month(MonthGroup)
    case shuffle
}

enum Route: Hashable {
    case mode(CleanupMode)
    case deck(DeckSource)
    case around(AssetID)
    case apply
    case settings
}

@Observable
final class Router {
    var path: [Route] = []

    func openApply() {
        if path.last != .apply { path.append(.apply) }
    }

    func popToRoot() {
        path.removeAll()
    }
}
