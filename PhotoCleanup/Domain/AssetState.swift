nonisolated enum AssetState: Sendable, Equatable {
    case undecided
    case pendingKeep
    case pendingTrash
    case kept
    case deleted

    init(id: AssetID, inLibrary: Bool, pending: PendingDecisions, keepAlbum: Set<AssetID>) {
        guard inLibrary else {
            self = .deleted
            return
        }
        switch pending.decision(for: id) {
        case .keep?: self = .pendingKeep
        case .trash?: self = .pendingTrash
        case nil: self = keepAlbum.contains(id) ? .kept : .undecided
        }
    }
}
