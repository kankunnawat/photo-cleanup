import Foundation

/// Which media kinds Free up lists, and so the only kinds its Delete can queue.
nonisolated enum FreeUpKind: CaseIterable, Hashable, Sendable {
    case all, photos, videos

    func includes(_ kind: MediaKind) -> Bool {
        switch self {
        case .all: true
        case .photos: kind == .photo
        case .videos: kind == .video
        }
    }
}

nonisolated enum FreeUpOrder: CaseIterable, Hashable, Sendable {
    case oldestFirst, biggestFirst
}

nonisolated struct FreeUpSelection: Sendable {
    /// In the requested `FreeUpOrder`.
    let candidates: [AssetInfo]
    /// Candidates already pending keep; Free up shows them as kept tiles.
    let kept: Set<AssetID>
    let skippedProtected: Int
}

nonisolated struct MonthRow: Identifiable, Sendable {
    let group: MonthGroup
    /// Assets the deck would still show.
    let open: Int

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

    static func monthRows(_ months: [MonthGroup], pending: PendingDecisions, protected: ProtectedSet) -> [MonthRow] {
        months.map { group in
            MonthRow(group: group, open: group.assetIDs.count { isOpen($0, protected: protected, pending: pending) })
        }
    }

    /// Unprotected assets of the chosen kind created before the cutoff; pending keeps are listed in `kept`.
    /// Undated assets are never candidates, because their age is unknown.
    /// Biggest first puts unknown sizes last; equal sizes fall back to oldest first.
    static func freeUpCandidates(
        _ assets: [AssetInfo],
        before cutoff: Date,
        kind: FreeUpKind,
        order: FreeUpOrder,
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
        let isOlder = { (a: AssetInfo, b: AssetInfo) in (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast) }
        switch order {
        case .oldestFirst:
            candidates.sort(by: isOlder)
        case .biggestFirst:
            candidates.sort { a, b in
                let sizeA = sizes[a.id] ?? -1
                let sizeB = sizes[b.id] ?? -1
                return sizeA == sizeB ? isOlder(a, b) : sizeA > sizeB
            }
        }
        return FreeUpSelection(candidates: candidates, kept: kept, skippedProtected: skipped)
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

    /// Unprotected, undecided videos, biggest first; unknown sizes last.
    static func largeVideos(
        _ assets: [AssetInfo],
        protected: ProtectedSet,
        pending: PendingDecisions,
        sizes: SizeCache
    ) -> [AssetInfo] {
        assets
            .filter { $0.kind == .video && isOpen($0.id, protected: protected, pending: pending) }
            .sorted { (sizes[$0.id] ?? -1) > (sizes[$1.id] ?? -1) }
    }

    private static func isOpen(_ id: AssetID, protected: ProtectedSet, pending: PendingDecisions) -> Bool {
        !protected.contains(id) && pending.decision(for: id) == nil
    }
}
