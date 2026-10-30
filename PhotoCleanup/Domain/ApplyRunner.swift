import Foundation

nonisolated struct ApplyReport: Sendable {
    enum Outcome: Sendable, Equatable {
        case completed
        /// The user cancelled the system delete alert; pending trash stays queued.
        case deleteCancelled
        case failed(String)
    }

    let outcome: Outcome
    /// Pending decisions after this run; store these back.
    let pending: PendingDecisions
    let keptCount: Int
    let logEntry: CleanupLog.Entry?
    let droppedMissing: Int
    let droppedProtected: Int
    /// Sizes Apply measured for queued trash the size cache did not know yet; merge these back.
    let measuredSizes: [AssetID: Int64]
}

/// Runs Apply: drop missing, drop newly protected trash, add keeps to the Keep album, then delete trash in one call.
nonisolated struct ApplyRunner: Sendable {
    let library: any PhotoLibrary

    func run(
        pending: PendingDecisions,
        disabledAlbumIDs: Set<String>,
        sizes: SizeCache,
        now: Date
    ) async -> ApplyReport {
        var pending = pending
        let existing = await library.existingIDs(among: pending.allIDs)
        let protected = ProtectedSet(sources: await library.protectionSources(), disabledAlbumIDs: disabledAlbumIDs)
        let plan = ApplyPlan(pending: pending, existing: existing, protected: protected)
        pending.resolve(plan.missing + plan.newlyProtected)
        var measured: [AssetID: Int64] = [:]

        func report(_ outcome: ApplyReport.Outcome, kept: Int, entry: CleanupLog.Entry? = nil) -> ApplyReport {
            ApplyReport(
                outcome: outcome,
                pending: pending,
                keptCount: kept,
                logEntry: entry,
                droppedMissing: plan.missing.count,
                droppedProtected: plan.newlyProtected.count,
                measuredSizes: measured
            )
        }

        if !plan.keeps.isEmpty {
            do {
                try await library.addToKeepAlbum(plan.keeps)
                pending.resolve(plan.keeps)
            } catch {
                return report(.failed("Could not add photos to the Keep album: \(error.localizedDescription)"), kept: 0)
            }
        }

        guard !plan.trash.isEmpty else { return report(.completed, kept: plan.keeps.count) }

        // Measured before the delete, because a deleted asset's size can no longer be read and the log keeps the total.
        let unmeasured = sizes.missing(from: plan.trash)
        if !unmeasured.isEmpty {
            measured = await library.fileSizes(for: unmeasured)
        }
        var sizes = sizes
        sizes.merge(measured)

        do {
            try await library.delete(plan.trash)
        } catch PhotoLibraryError.userCancelled {
            return report(.deleteCancelled, kept: plan.keeps.count)
        } catch {
            return report(.failed("Could not delete: \(error.localizedDescription)"), kept: plan.keeps.count)
        }
        pending.resolve(plan.trash)
        let entry = CleanupLog.Entry(date: now, deletedCount: plan.trash.count, bytes: sizes.total(of: plan.trash))
        return report(.completed, kept: plan.keeps.count, entry: entry)
    }
}
