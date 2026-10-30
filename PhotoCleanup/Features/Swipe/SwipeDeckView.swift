import SwiftUI

struct SwipeDeckView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let source: DeckSource

    @State private var queue: [AssetID]?
    @State private var open: [AssetID] = []
    /// Created with the deck and gone when it closes, so Undo never reaches decisions made elsewhere.
    @State private var history = DeckHistory()
    @State private var lastDecision: Decision = .keep
    @State private var keptTick = 0
    @State private var trashedTick = 0
    @State private var preview: PreviewSession?
    @State private var albumTarget: AssetID?

    var body: some View {
        VStack(spacing: 16) {
            header(remaining: open.count)
            ZStack {
                if open.isEmpty, queue != nil {
                    finished
                }
                ForEach(Array(open.prefix(3).enumerated().reversed()), id: \.element) { depth, id in
                    if let asset = model.assetsByID[id] {
                        SwipeCard(
                            asset: asset,
                            bytes: model.sizes[id],
                            isTop: depth == 0,
                            onDecide: { decide($0, for: id, animated: false) },
                            onTap: { preview = PreviewSession([asset], showing: id) }
                        )
                        .scaleEffect(1 - CGFloat(depth) * 0.04)
                        .offset(y: CGFloat(depth) * 14)
                        .zIndex(Double(-depth))
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .offset(x: lastDecision == .keep ? 600 : -600).combined(with: .opacity)
                        ))
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(duration: 0.3), value: open.first)
            controls(hasCard: !open.isEmpty)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { router.openApply() }
                    .bold()
                    .disabled(model.pendingSummary.isEmpty)
                    .accessibilityIdentifier("deck.done")
            }
        }
        .sensoryFeedback(.success, trigger: keptTick)
        .sensoryFeedback(.impact(weight: .heavy), trigger: trashedTick)
        .assetPreview($preview, choice: choice(for:))
        .sheet(item: $albumTarget, onDismiss: refilter) { AlbumPicker(assetID: $0) }
        .onAppear {
            if queue == nil { queue = makeQueue() }
            refilter()
        }
        // The card under the album picker stays until the picker closes.
        .onChange(of: model.revision) { if albumTarget == nil { refilter() } }
        .onChange(of: open.isEmpty) { _, isEmpty in
            if isEmpty, keptTick + trashedTick > 0 { router.openApply() }
        }
    }

    private var title: String {
        switch source {
        case .month(let group): Formatting.monthTitle(group.key)
        case .shuffle: "Shuffle"
        }
    }

    /// Rebuilds the open cards from the queue fixed when the deck opened.
    private func refilter() {
        open = Buckets.reviewDeck(queue ?? [], pending: model.pending, protected: model.protected)
            .filter { model.assetsByID[$0] != nil }
    }

    private func makeQueue() -> [AssetID] {
        switch source {
        case .month(let group):
            let current = model.months.first { $0.id == group.id } ?? group
            return Buckets.reviewDeck(current.assetIDs, pending: model.pending, protected: model.protected)
        case .shuffle:
            return Buckets.reviewDeck(model.assets.map(\.id), pending: model.pending, protected: model.protected).shuffled()
        }
    }

    private func decide(_ decision: Decision, for id: AssetID, animated: Bool) {
        lastDecision = decision
        if decision == .keep { keptTick += 1 } else { trashedTick += 1 }
        let commit = {
            model.swipe(decision, for: id, history: &history)
            if let index = open.firstIndex(of: id) { open.remove(at: index) }
        }
        if animated {
            withAnimation(.easeIn(duration: 0.25), commit)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, commit)
        }
    }

    private func choice(for asset: AssetInfo) -> PreviewChoice {
        let decideAndClose = { (decision: Decision) in
            preview = nil
            decide(decision, for: asset.id, animated: true)
        }
        return PreviewChoice(status: nil, actions: [
            .init(title: "Delete", tint: .red) { decideAndClose(.trash) },
            .init(title: "Keep", tint: .keepGreen) { decideAndClose(.keep) },
        ])
    }

    private func header(remaining: Int) -> some View {
        HStack {
            Label("\(remaining) left", systemImage: "square.stack")
                .accessibilityIdentifier("deck.remaining")
            Spacer()
            Label("\(model.pendingSummary.keepCount)", systemImage: "heart.fill")
                .foregroundStyle(.keepGreen)
            Label("\(model.pendingSummary.trashCount)", systemImage: "trash.fill")
                .foregroundStyle(.red)
        }
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
    }

    private func controls(hasCard: Bool) -> some View {
        HStack(spacing: 28) {
            roundButton("xmark", tint: .red, size: 64, label: "Delete") {
                if let id = open.first { decide(.trash, for: id, animated: true) }
            }
            .disabled(!hasCard)
            roundButton("arrow.uturn.backward", tint: .orange, size: 48, label: "Undo") {
                withAnimation(.spring(duration: 0.3)) {
                    model.undo(&history)
                    refilter()
                }
            }
            .disabled(!history.canUndo(in: model.pending))
            roundButton("rectangle.stack.badge.plus", tint: .accentColor, size: 48, label: "Album") {
                albumTarget = open.first
            }
            .disabled(!hasCard)
            roundButton("heart.fill", tint: .keepGreen, size: 64, label: "Keep") {
                if let id = open.first { decide(.keep, for: id, animated: true) }
            }
            .disabled(!hasCard)
        }
        .padding(.bottom, 8)
    }

    private func roundButton(_ symbol: String, tint: Color, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("deck.\(label.lowercased())")
    }

    private var finished: some View {
        ContentUnavailableView {
            Label("All done here", systemImage: "checkmark.seal.fill")
        } description: {
            Text("Every photo in this deck has a decision.")
        } actions: {
            Button("Review and apply") { router.openApply() }
                .buttonStyle(.borderedProminent)
                .disabled(model.pendingSummary.isEmpty)
        }
    }
}
