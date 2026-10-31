import SwiftUI

struct SwipeDeckView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let source: DeckSource

    @State private var deck: SwipeDeck?
    /// Nil is the order the cards were dealt in, which only the shuffle deck offers.
    @State private var order: AssetOrder?
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
                if open.isEmpty, deck != nil {
                    finished
                }
                ForEach(Array(open.prefix(3).enumerated().reversed()), id: \.element) { depth, id in
                    if let asset = model.assetsByID[id] {
                        SwipeCard(
                            asset: asset,
                            bytes: model.sizes[id],
                            isTop: depth == 0,
                            onDecide: { decide($0, for: id, animated: false) },
                            onTap: { preview = PreviewSession([asset], showing: id) },
                            onZoomOut: asset.creationDate == nil ? nil : { openAround(id) }
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
                // Sorts on the menu pick, not when deal() sets `order`; the closure form avoids a swift-frontend 6.3.1 crash.
                SortMenu(selection: Binding(get: { order }, set: { sort($0) }), orders: orders, label: { $0?.label ?? "Shuffled" }, id: "deck.sort")
            }
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
        .sheet(item: $albumTarget, onDismiss: refilter) { AlbumPicker(assetIDs: [$0]) }
        .onAppear {
            if deck == nil { deal() }
            refilter()
        }
        // The card under the album picker stays until the picker closes.
        .onChange(of: model.revision) { if albumTarget == nil { refilter() } }
        .onChange(of: open.isEmpty) { _, isEmpty in
            // The grid can empty the deck while it is on top; Apply must not open over the grid.
            if isEmpty, keptTick + trashedTick > 0, router.path.last == .deck(source) { router.openApply() }
        }
    }

    private var title: String {
        switch source {
        case .month(let group): Formatting.monthTitle(group.key)
        case .shuffle: "Shuffle"
        }
    }

    private var orders: [AssetOrder?] {
        switch source {
        case .month: [.newestFirst, .oldestFirst, .biggestFirst]
        case .shuffle: [nil, .biggestFirst]
        }
    }

    /// Rebuilds the open cards from the deck dealt when it opened.
    private func refilter() {
        open = deck?.open(pending: model.pending, protected: model.protected, assetsByID: model.assetsByID) ?? []
    }

    /// A month deck opens in the order last picked in one; the shuffle deck always opens shuffled.
    private func deal() {
        if case .month = source { order = model.monthDeckOrder }
        var dealt = makeDeck()
        dealt.sort(order, assetsByID: model.assetsByID, sizes: model.sizes)
        deck = dealt
    }

    /// The open cards of the kind picked on the month list, in the source's order.
    private func makeDeck() -> SwipeDeck {
        let ids: [AssetID] = switch source {
        case .month(let group): (model.months.first { $0.id == group.id } ?? group).assetIDs
        case .shuffle: model.assets.map(\.id).shuffled()
        }
        return SwipeDeck(dealing: ids, filter: model.swipeFilter, assetsByID: model.assetsByID, pending: model.pending, protected: model.protected)
    }

    /// Reorders the dealt cards, decided ones included, so Undo still finds every card this deck swiped.
    private func sort(_ picked: AssetOrder?) {
        order = picked
        if case .month = source, let picked { model.monthDeckOrder = picked }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            deck?.sort(picked, assetsByID: model.assetsByID, sizes: model.sizes)
            refilter()
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

    private func openAround(_ id: AssetID) {
        if router.path.last == .deck(source) { router.path.append(.around(id)) }
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
            if let filter = deck?.filter, filter != .all {
                Text("\(filter.label) only")
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }
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
        // Five buttons, 272 pt, with four 16 pt gaps fit the 343 pt a 375 pt wide screen leaves inside the padding.
        HStack(spacing: 16) {
            roundButton("xmark", tint: .red, size: 64, label: "Delete") {
                if let id = open.first { decide(.trash, for: id, animated: true) }
            }
            .disabled(!hasCard)
            roundButton("arrow.uturn.backward", tint: .orange, size: 48, label: "Undo") {
                guard var current = deck else { return }
                withAnimation(.spring(duration: 0.3)) {
                    model.undo(&history, in: &current)
                    deck = current
                    refilter()
                }
            }
            .disabled(!history.canUndo(in: model.pending))
            roundButton("square.grid.2x2", tint: .accentColor, size: 48, label: "Around this time", id: "around") {
                if let id = open.first { openAround(id) }
            }
            .disabled(open.first.flatMap { model.assetsByID[$0]?.creationDate } == nil)
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

    private func roundButton(_ symbol: String, tint: Color, size: CGFloat, label: String, id: String? = nil, action: @escaping () -> Void) -> some View {
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
        .accessibilityIdentifier("deck.\(id ?? label.lowercased())")
    }

    private var finished: some View {
        ContentUnavailableView {
            Label("All done here", systemImage: "checkmark.seal.fill")
        } description: {
            Text(deck?.filter == .videos ? "Every video in this deck has a decision." : "Every photo in this deck has a decision.")
        } actions: {
            Button("Review and apply") { router.openApply() }
                .buttonStyle(.borderedProminent)
                .disabled(model.pendingSummary.isEmpty)
        }
    }
}
