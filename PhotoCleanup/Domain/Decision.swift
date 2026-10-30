nonisolated enum Decision: String, Sendable, Codable {
    case keep
    case trash

    var opposite: Decision {
        switch self {
        case .keep: .trash
        case .trash: .keep
        }
    }
}
