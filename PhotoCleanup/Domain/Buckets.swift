import Foundation

nonisolated struct FreeUpSelection: Sendable {
    /// In the requested `AssetOrder`.
    let candidates: [AssetInfo]
    /// Candidates already pending keep; Free up shows them as kept tiles.
    let kept: Set<AssetID>
    let skippedProtected: Int
}

nonisolated struct MonthRow: Identifiable, Sendable {
    let group: MonthGroup
    /// Assets of the row's kind that the deck would still show.
    let open: Int
    /// Assets of the row's kind, decided or not.
    let total: Int

    var id: String { group.id }
}

nonisolated enum Buckets {
    /// IDs the swipe deck should still show: undecided and not protected.
    static func reviewDeck(
        _ ids: [AssetID],
        pending: PendingDecisions,
        protected: ProtectedSet
    ) -> [AssetID] {
        ids.filter { isOpen($0, protected: protected, pending: pending) }
    }

    /// The IDs a bulk mode may queue as trash: protected assets are dropped.
    static func trashable(_ ids: [AssetID], protected: ProtectedSet) -> [AssetID] {
        ids.filter { !protected.contains($0) }
    }

    /// The IDs of the kinds `filter` shows. All keeps every ID, even one no longer in the library.
    static func matching(_ ids: [AssetID], _ filter: MediaFilter, assetsByID: [AssetID: AssetInfo]) -> [AssetID] {
        guard filter != .all else { return ids }
        return ids.filter { assetsByID[$0].map { filter.includes($0.kind) } ?? false }
    }

    /// One row per month that holds any of the filter's kinds, so under All every month has a row.
    static func monthRows(
        _ months: [MonthGroup],
        filter: MediaFilter,
        assetsByID: [AssetID: AssetInfo],
        pending: PendingDecisions,
        protected: ProtectedSet
    ) -> [MonthRow] {
        months.compactMap { group in
            let ids = matching(group.assetIDs, filter, assetsByID: assetsByID)
            guard !ids.isEmpty else { return nil }
            return MonthRow(group: group, open: ids.count { isOpen($0, protected: protected, pending: pending) }, total: ids.count)
        }
    }

    /// Unprotected assets of the chosen kind created before the cutoff; pending keeps are listed in `kept`.
    /// The kind decides what Free up's Delete can queue. Undated assets are never candidates, because their age is unknown.
    static func freeUpCandidates(
        _ assets: [AssetInfo],
        before cutoff: Date,
        kind: MediaFilter,
        order: AssetOrder,
        protected: ProtectedSet,
        pending: PendingDecisions,
        sizes: SizeCache
    ) -> FreeUpSelection {
        var candidates: [AssetInfo] = []
        var kept: Set<AssetID> = []
        var skipped = 0
        for asset in assets {
            guard let date = asset.creationDate, date < cutoff, kind.includes(asset.kind) else { continue }
            if protected.contains(asset.id) {
                skipped += 1
                continue
            }
            candidates.append(asset)
            if pending.decision(for: asset.id) == .keep {
                kept.insert(asset.id)
            }
        }
        return FreeUpSelection(candidates: order.sorted(candidates, sizes: sizes), kept: kept, skippedProtected: skipped)
    }

    /// Unprotected, undecided screenshots, newest first.
    static func screenshots(
        _ assets: [AssetInfo],
        protected: ProtectedSet,
        pending: PendingDecisions
    ) -> [AssetInfo] {
        assets
            .filter { $0.isScreenshot && isOpen($0.id, protected: protected, pending: pending) }
            .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
    }

    /// Unprotected, undecided videos, in library order; the Large videos screen sorts them when it opens.
    static func largeVideos(_ assets: [AssetInfo], protected: ProtectedSet, pending: PendingDecisions) -> [AssetInfo] {
        assets.filter { $0.kind == .video && isOpen($0.id, protected: protected, pending: pending) }
    }

    private static func isOpen(_ id: AssetID, protected: ProtectedSet, pending: PendingDecisions) -> Bool {
        !protected.contains(id) && pending.decision(for: id) == nil
    }
}
