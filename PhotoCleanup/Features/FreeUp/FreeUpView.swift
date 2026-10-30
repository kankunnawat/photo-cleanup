import SwiftUI

struct FreeUpView: View {
    enum Cutoff: Hashable, CaseIterable {
        case one, three, six, twelve, custom

        var months: Int? {
            switch self {
            case .one: 1
            case .three: 3
            case .six: 6
            case .twelve: 12
            case .custom: nil
            }
        }

        var label: String {
            months.map { "\($0) mo" } ?? "Custom"
        }
    }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var cutoff: Cutoff = .three
    @State private var customDate = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    // Frozen when the screen opens or the cutoff changes, so tiles stay put while the user taps.
    // Closing the viewer only drops tiles that became protected.
    @State private var cutoffDate = Date.now
    @State private var candidates: [AssetInfo] = []
    @State private var skippedProtected = 0
    /// Flipped tiles are the ones to keep.
    @State private var tiles = TileToggles(ids: [])
    /// Counts the user's taps; rebuilding the tiles also changes `flipped` but gets no tick.
    @State private var tileTaps = 0
    @State private var preview: PreviewSession?

    var body: some View {
        let deleteCount = tiles.unflippedCount
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    cutoffPicker
                    summary(count: deleteCount, bytes: model.sizes.total(of: tiles.unflipped))
                    Label(SafetyCopy.backup, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    if !candidates.isEmpty {
                        Text("Tap a photo to keep it. Tap again to delete it after all. Touch and hold to view it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: AssetGrid.columns, spacing: 3) {
                            ForEach(candidates) { asset in
                                let isKept = tiles.isFlipped(asset.id)
                                AssetGridCell(asset: asset, badge: isKept ? .keep : nil)
                                    .onTapGesture { toggle(asset.id) }
                                    .opensPreview { preview = PreviewSession(candidates, showing: asset.id) }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityValue(isKept ? "Keep" : "Delete")
                                    .accessibilityIdentifier("freeUp.tile")
                            }
                        }
                    }
                }
                .padding()
            }
            .assetPreview($preview, returningTo: proxy, choice: choice(for:))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Free up space")
        .sensoryFeedback(.selection, trigger: tileTaps)
        .onAppear(perform: freeze)
        .onChange(of: cutoff) { freeze() }
        .onChange(of: customDate) { freeze() }
        .onChange(of: preview == nil) { _, closed in
            if closed { dropProtected() }
        }
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                model.queueFreeUp(trash: tiles.unflipped, keep: tiles.flippedInOrder)
                router.openApply()
            } label: {
                Text(deleteCount == 0 ? "Nothing to delete" : "Delete \(Formatting.items(deleteCount))")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(deleteCount == 0)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("freeUp.delete")
        }
    }

    private func toggle(_ id: AssetID) {
        tileTaps += 1
        if tiles.toggle(id) {
            model.decide(.keep, for: id)
        } else {
            model.clearDecision(for: id)
        }
    }

    private func choice(for asset: AssetInfo) -> PreviewChoice {
        let toggle = { self.toggle(asset.id) }
        return if tiles.isFlipped(asset.id) {
            PreviewChoice(
                status: .init(text: "Keeping", tint: .keepGreen),
                actions: [.init(title: "Delete after all", tint: .red, perform: toggle)]
            )
        } else {
            PreviewChoice(
                status: .init(text: "Will be deleted", tint: .red),
                actions: [.init(title: "Keep", tint: .keepGreen, perform: toggle)]
            )
        }
    }

    /// Rebuilds the candidate list; pending keeps show as kept tiles.
    private func freeze() {
        let date: Date = if let months = cutoff.months {
            Calendar.current.date(byAdding: .month, value: -months, to: .now) ?? .now
        } else {
            customDate
        }
        let selection = model.freeUpSelection(before: date, kind: .all, order: .oldestFirst)
        cutoffDate = date
        candidates = selection.candidates
        skippedProtected = selection.skippedProtected
        tiles = TileToggles(ids: selection.candidates.map(\.id), flipped: selection.kept)
    }

    /// An album add in the viewer protects a photo; it leaves the grid and counts as skipped.
    /// The other tiles and the user's taps stay as they were, so `freeze()` is not the tool here.
    private func dropProtected() {
        let remaining = candidates.filter { !model.protected.contains($0.id) }
        guard remaining.count < candidates.count else { return }
        skippedProtected += candidates.count - remaining.count
        candidates = remaining
        tiles = TileToggles(ids: remaining.map(\.id), flipped: tiles.flipped)
    }

    private var cutoffPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delete everything older than")
                .font(.subheadline.weight(.semibold))
            Picker("Older than", selection: $cutoff) {
                ForEach(Cutoff.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            if cutoff == .custom {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
                layout {
                    Text("Before")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                    DatePicker("Before", selection: $customDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                }
            } else {
                Text("Before \(Formatting.day(cutoffDate))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summary(count: Int, bytes: Int64) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 0))
        return layout {
            figure(count.formatted(), "to delete", id: "freeUp.count")
            figure(Formatting.bytes(bytes), model.isMeasuringSizes ? "up to, measuring…" : "up to", id: "freeUp.bytes")
            figure(skippedProtected.formatted(), "protected, skipped", id: "freeUp.skipped")
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func figure(_ value: String, _ caption: String, id: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .accessibilityIdentifier(id)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
