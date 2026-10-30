import Foundation

/// What Apply will do, decided right before it runs against fresh library facts.
nonisolated struct ApplyPlan: Sendable, Equatable {
    let keeps: [AssetID]
    let trash: [AssetID]
    /// Pending IDs that are no longer in the library.
    let missing: [AssetID]
    /// Pending-trash IDs that became protected after they were queued.
    let newlyProtected: [AssetID]

    init(pending: PendingDecisions, existing: Set<AssetID>, protected: ProtectedSet) {
        var keeps: [AssetID] = []
        var trash: [AssetID] = []
        var missing: [AssetID] = []
        var newlyProtected: [AssetID] = []
        for id in pending.allIDs {
            let state = AssetState(id: id, inLibrary: existing.contains(id), pending: pending, keepAlbum: [])
            switch state {
            case .deleted:
                missing.append(id)
            case .pendingKeep:
                keeps.append(id)
            case .pendingTrash where protected.contains(id):
                newlyProtected.append(id)
            case .pendingTrash:
                trash.append(id)
            case .undecided, .kept:
                break
            }
        }
        self.keeps = keeps
        self.trash = trash
        self.missing = missing
        self.newlyProtected = newlyProtected
    }
}
