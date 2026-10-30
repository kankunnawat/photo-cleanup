import SwiftUI

/// Screenshots start all selected (tap to spare one); large videos start unselected (tap to pick).
struct BulkSelectView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    let mode: CleanupMode

    @State private var toggled: Set<AssetID> = []
    @State private var preview: PreviewSession?

    private var startsSelected: Bool { mode == .screenshots }

    var body: some View {
        let items = mode == .screenshots ? model.screenshots : model.largeVideos
        let selected = items.map(\.id).filter(isSelected)
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    mode == .screenshots ? "No screenshots" : "No videos",
                    systemImage: mode.systemImage,
                    description: Text("Nothing here needs cleaning up.")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(hint)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: AssetGrid.columns, spacing: 3) {
                                ForEach(items) { asset in
                                    AssetGridCell(asset: asset, isSelected: isSelected(asset.id))
                                        .onTapGesture { toggle(asset.id) }
                                        .opensPreview { preview = PreviewSession(items, showing: asset.id) }
                                }
                            }
                        }
                        .padding()
                    }
                    .assetPreview($preview, returningTo: proxy, choice: choice(for:))
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(mode.title)
        .sensoryFeedback(.selection, trigger: toggled)
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                Button(role: .destructive) {
                    model.queueTrash(selected)
                    router.openApply()
                } label: {
                    VStack(spacing: 2) {
                        Text(selected.isEmpty ? "Select items to delete" : "Delete \(Formatting.items(selected.count))")
                            .font(.headline)
                        Text(Formatting.upTo(model.sizes.total(of: selected), measuring: model.isMeasuringSizes))
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selected.isEmpty)
                .padding()
                .background(.bar)
            }
        }
    }

    private var hint: String {
        startsSelected
            ? "All selected. Tap a screenshot to keep it. Touch and hold to view it."
            : "Biggest first. Tap a video to select it. Touch and hold to play it."
    }

    private func choice(for asset: AssetInfo) -> PreviewChoice {
        let toggle = { self.toggle(asset.id) }
        return if isSelected(asset.id) {
            PreviewChoice(
                status: .init(text: "Selected to delete", tint: .red),
                actions: [.init(title: "Keep", tint: .gray, perform: toggle)]
            )
        } else {
            PreviewChoice(
                status: .init(text: "Not selected", tint: .gray),
                actions: [.init(title: "Select to delete", tint: .red, perform: toggle)]
            )
        }
    }

    private func isSelected(_ id: AssetID) -> Bool {
        toggled.contains(id) != startsSelected
    }

    private func toggle(_ id: AssetID) {
        if toggled.contains(id) {
            toggled.remove(id)
        } else {
            toggled.insert(id)
        }
    }
}
