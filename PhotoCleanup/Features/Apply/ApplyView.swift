import SwiftUI

struct ApplyView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    @State private var isRunning = false
    @State private var report: ApplyReport?
    @State private var failure: String?
    // Tiles stay in place until the screen is left, except a tile an album add in the viewer protected.
    // Every change writes through to pending decisions, so leaving the screen keeps it.
    @State private var keepTiles = ApplySection(ids: [], decision: .keep)
    @State private var trashTiles = ApplySection(ids: [], decision: .trash)
    @State private var hasFrozen = false
    /// Counts the user's tile changes; opening the screen and applying also change the counts but get no tick.
    @State private var tileEdits = 0
    /// The viewer pages through the section of the tile that opened it.
    @State private var preview: PreviewSession?

    var body: some View {
        let keepCount = keepTiles.count(of: .keep) + trashTiles.count(of: .keep)
        let trashCount = keepTiles.count(of: .trash) + trashTiles.count(of: .trash)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let report {
                        ApplyResultCard(report: report)
                            .transition(.opacity.animation(.default))
                    }
                    if keepTiles.ids.isEmpty, trashTiles.ids.isEmpty {
                        if report == nil {
                            ContentUnavailableView("Nothing to apply", systemImage: "tray", description: Text("Swipe or pick photos first."))
                        }
                    } else {
                        Text("Tap an item to switch it between keep and delete. Touch and hold to view it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        section(
                            keepTiles,
                            title: "Keep (\(keepCount.formatted()))",
                            detail: "Added to the Keep album",
                            tint: .keepGreen,
                            id: "apply.keepSection",
                            allID: "apply.keep.all"
                        )
                        section(
                            trashTiles,
                            title: "Delete (\(trashCount.formatted()))",
                            detail: Formatting.upTo(model.pendingSummary.trashBytes, measuring: model.isMeasuringSizes),
                            tint: .red,
                            id: "apply.deleteSection",
                            allID: "apply.delete.all"
                        )
                        if trashCount > 0 {
                            Label(SafetyCopy.upTo, systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .assetPreview($preview, returningTo: proxy, choice: choice(for:))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Review and apply")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isRunning)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Home") { router.popToRoot() }
                    .disabled(isRunning)
                    .accessibilityIdentifier("apply.home")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if keepCount > 0 || trashCount > 0 {
                applyButton(keeps: keepCount, trash: trashCount)
            }
        }
        .onAppear {
            guard !hasFrozen else { return }
            hasFrozen = true
            freeze()
        }
        // Once per close, not per pending change: the sections can hold tens of thousands of tiles.
        .onChange(of: preview == nil) { _, closed in
            if closed { dropTilesChangedElsewhere() }
        }
        .sensoryFeedback(.selection, trigger: tileEdits)
        .alert("Apply failed", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .sensoryFeedback(.success, trigger: report?.logEntry)
    }

    private func applyButton(keeps: Int, trash: Int) -> some View {
        Button {
            Task { await run() }
        } label: {
            Group {
                if isRunning {
                    ProgressView()
                } else {
                    Text(buttonTitle(keeps: keeps, trash: trash))
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(trash > 0 ? .red : .keepGreen)
        .disabled(isRunning)
        .padding()
        .background(.bar)
        .accessibilityIdentifier("apply.run")
    }

    private func buttonTitle(keeps: Int, trash: Int) -> String {
        switch (keeps, trash) {
        case (0, _): "Delete \(Formatting.items(trash))"
        case (_, 0): "Keep \(Formatting.items(keeps))"
        default: "Keep \(keeps.formatted()), delete \(trash.formatted())"
        }
    }

    private func section(_ tiles: ApplySection, title: String, detail: String, tint: Color, id: String, allID: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(tint)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(id)
                Spacer()
                if !tiles.ids.isEmpty {
                    Button(tiles.hasDecisions ? "Take back all" : "Restore all") {
                        takeBackOrRestoreAll(tiles.decision)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier(allID)
                }
            }
            if !tiles.ids.isEmpty {
                LazyVGrid(columns: AssetGrid.columns, spacing: 3) {
                    ForEach(tiles.ids, id: \.self) { assetID in
                        let current = tiles.decision(for: assetID)
                        cell(for: assetID, badge: badge(for: current, in: tiles.decision), section: tiles.decision)
                            .onTapGesture {
                                guard !isRunning else { return }
                                tap(assetID, in: tiles.decision)
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityValue(current.map { $0 == .keep ? "Keep" : "Delete" } ?? "Taken back")
                            .accessibilityIdentifier("apply.tile")
                    }
                }
            }
        }
        .disabled(isRunning)
    }

    private func badge(for current: Decision?, in section: Decision) -> AssetGridCell.Badge? {
        guard let current else { return .takenBack }
        if current == section { return nil }
        return current == .keep ? .keep : .delete
    }

    @ViewBuilder
    private func cell(for id: AssetID, badge: AssetGridCell.Badge?, section: Decision) -> some View {
        if let asset = model.assetsByID[id] {
            AssetGridCell(asset: asset, badge: badge)
                .opensPreview {
                    guard !isRunning else { return }
                    let tiles = section == .keep ? keepTiles : trashTiles
                    preview = PreviewSession(tiles.ids.compactMap { model.assetsByID[$0] }, showing: id)
                }
        } else {
            Color(.secondarySystemFill)
                .aspectRatio(1, contentMode: .fit)
                .overlay(Image(systemName: "questionmark").foregroundStyle(.secondary))
                .modifier(BadgeOverlay(badge: badge))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func update(_ section: Decision, _ change: (inout ApplySection) -> Void) {
        tileEdits += 1
        switch section {
        case .keep: change(&keepTiles)
        case .trash: change(&trashTiles)
        }
    }

    private func tap(_ id: AssetID, in section: Decision) {
        update(section) { tiles in
            guard let decision = tiles.tap(id) else { return }
            model.decide(decision, for: id)
        }
    }

    private func takeBackOrRestoreAll(_ section: Decision) {
        update(section) { tiles in
            if tiles.hasDecisions {
                tiles.takeBackAll()
                model.clearDecisions(for: tiles.ids)
            } else {
                tiles.restoreAll()
                model.decide(tiles.decision, for: tiles.ids)
            }
        }
    }

    private func choice(for asset: AssetInfo) -> PreviewChoice {
        let tiles = keepTiles.contains(asset.id) ? keepTiles : trashTiles
        let tap = { self.tap(asset.id, in: tiles.decision) }
        return switch tiles.decision(for: asset.id) {
        case .keep?:
            PreviewChoice(status: .init(text: "Will be kept", tint: .keepGreen), actions: [.init(title: "Delete", tint: .red, perform: tap)])
        case .trash?:
            PreviewChoice(status: .init(text: "Will be deleted", tint: .red), actions: [.init(title: "Keep", tint: .keepGreen, perform: tap)])
        case nil:
            PreviewChoice(status: .init(text: "Taken back", tint: .gray), actions: [.init(title: "Restore", tint: .gray, perform: tap)])
        }
    }

    private func freeze() {
        keepTiles = ApplySection(ids: model.pending.keeps, decision: .keep)
        trashTiles = ApplySection(ids: model.pending.trash, decision: .trash)
    }

    /// An album add in the viewer clears a pending delete; that tile leaves, so no tap or Restore all queues it again.
    /// A tile that was taken back before the add stays, and Restore all can queue it; Apply then skips it.
    private func dropTilesChangedElsewhere() {
        keepTiles.dropTiles(disagreeingWith: model.pending)
        trashTiles.dropTiles(disagreeingWith: model.pending)
    }

    private func run() async {
        isRunning = true
        let result = await model.apply()
        isRunning = false
        freeze()
        // No withAnimation: it would commit the emptied tiles a frame early and flash "Nothing to apply".
        report = result
        if case .failed(let message) = result.outcome {
            failure = message
        }
    }
}
