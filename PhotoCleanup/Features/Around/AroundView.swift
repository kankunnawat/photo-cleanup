import SwiftUI

/// Every photo and video from the days around one deck card, to pick a set and act on it at once.
struct AroundView: View {
    @Environment(AppModel.self) private var model

    let center: AssetID

    @State private var days: [NearbyDay] = []
    @State private var selected: Set<AssetID>
    @State private var preview: PreviewSession?
    @State private var isPickingAlbum = false
    /// When on, a drag across tiles paints a selection range; scrolling uses the edges.
    /// When off, taps and scrolling work as they always have.
    @State private var isDragSelecting = false

    init(center: AssetID) {
        self.center = center
        _selected = State(initialValue: [center])
    }

    var body: some View {
        let items = days.flatMap(\.assets)
        let picked = items.map(\.id).filter(selected.contains)
        let decidable = picked.filter { !model.protected.contains($0) }
        let indexByID = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
        ScrollViewReader { proxy in
            // Built once the days are in: scrolling to the card in the update that adds its tile does nothing.
            if days.isEmpty {
                ContentUnavailableView("Nothing around this time", systemImage: "photo.on.rectangle")
            } else {
                ScrollView {
                    LazyVGrid(columns: AssetGrid.columns, spacing: 3, pinnedViews: [.sectionHeaders]) {
                        ForEach(days) { day in
                            Section {
                                ForEach(day.assets) { asset in
                                    if let index = indexByID[asset.id] {
                                        tile(for: asset, in: items, index: index)
                                    }
                                }
                            } header: {
                                Text(day.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGroupedBackground))
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .dragSelect(
                    ids: items.map(\.id),
                    selected: $selected,
                    enabled: isDragSelecting,
                    proxy: proxy,
                    columns: AssetGrid.columns.count
                )
                .onAppear { proxy.scrollTo(center, anchor: .center) }
                .assetPreview($preview, returningTo: proxy, choice: choice(for:))
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isDragSelecting ? "Done" : "Select") {
                    isDragSelecting.toggle()
                }
                .accessibilityIdentifier("around.dragSelect")
            }
        }
        .onChange(of: model.revision, initial: true) { rebuild() }
        .sensoryFeedback(.selection, trigger: selected)
        .sheet(isPresented: $isPickingAlbum) { AlbumPicker(assetIDs: picked) }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if isDragSelecting {
                    Text(picked.isEmpty ? "Drag across items to select them" : "\(Formatting.items(picked.count)) selected · drag to adjust")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .accessibilityIdentifier("around.selectionCount")
                }
                bar(picked: picked, decidable: decidable)
            }
            .background(.bar)
        }
    }

    private var title: String {
        guard let date = model.assetsByID[center]?.creationDate,
              let window = Nearby.window(around: date, calendar: .current) else { return "Around this time" }
        return (window.lowerBound..<window.upperBound).formatted(.interval.month(.abbreviated).day())
    }

    private func tile(for asset: AssetInfo, in items: [AssetInfo], index: Int) -> some View {
        let isSelected = selected.contains(asset.id)
        return AssetGridCell(
            asset: asset,
            isSelected: isSelected,
            badge: badge(for: asset.id),
            selectionStyle: .pick,
            isLocked: model.protected.contains(asset.id)
        )
        .accessibilityElement(children: .combine)
        .id(asset.id)
        .reportsGridTileFrame(index: index)
        .onTapGesture { toggle(asset.id) }
        .opensPreview { preview = PreviewSession(items, showing: asset.id) }
        .accessibilityLabel(label(for: asset))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("around.tile")
    }

    /// The tile shows no date, so VoiceOver gets the day the header gives sighted users.
    private func label(for asset: AssetInfo) -> String {
        let badge: String? = switch model.pending.decision(for: asset.id) {
        case .keep: "Keep"
        case .trash: "Delete"
        case nil: nil
        }
        let parts = [
            asset.kind == .video ? "Video" : "Photo",
            Formatting.day(asset.creationDate),
            model.sizes[asset.id].map(Formatting.bytes),
            badge,
            model.protected.contains(asset.id) ? "Protected" : nil,
        ]
        return parts.compactMap(\.self).joined(separator: ", ")
    }

    private func bar(picked: [AssetID], decidable: [AssetID]) -> some View {
        HStack(spacing: 8) {
            barButton("Delete \(decidable.count.formatted())", tint: .red, id: "around.delete") {
                model.queueTrash(decidable)
                selected.removeAll()
            }
            .disabled(decidable.isEmpty)
            barButton("Keep \(decidable.count.formatted())", tint: .keepGreen, id: "around.keep") {
                model.queueKeep(decidable)
                selected.removeAll()
            }
            .disabled(decidable.isEmpty)
            barButton("Add \(picked.count.formatted()) to album", tint: .accentColor, id: "around.album") {
                isPickingAlbum = true
            }
            .disabled(picked.isEmpty)
        }
        .padding()
    }

    private func barButton(_ title: String, tint: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .accessibilityIdentifier(id)
    }

    private func badge(for id: AssetID) -> AssetGridCell.Badge? {
        switch model.pending.decision(for: id) {
        case .keep: .keep
        case .trash: .delete
        case nil: nil
        }
    }

    private func choice(for asset: AssetInfo) -> PreviewChoice {
        let toggle = { self.toggle(asset.id) }
        return if selected.contains(asset.id) {
            PreviewChoice(
                status: .init(text: "Selected", tint: .accentColor),
                actions: [.init(title: "Deselect", tint: .gray, perform: toggle)],
                keepsActionsWhenProtected: true
            )
        } else {
            PreviewChoice(
                status: .init(text: "Not selected", tint: .gray),
                actions: [.init(title: "Select", tint: .accentColor, perform: toggle)],
                keepsActionsWhenProtected: true
            )
        }
    }

    private func rebuild() {
        guard let date = model.assetsByID[center]?.creationDate else {
            days = []
            return
        }
        days = Nearby.days(around: date, in: model.assets, calendar: .current)
    }

    private func toggle(_ id: AssetID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}
