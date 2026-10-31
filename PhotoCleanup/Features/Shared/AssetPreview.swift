import AVKit
import SwiftUI

/// The items a viewer pages through, captured once when it opens so paging never touches the presenting screen.
struct PreviewSession: Identifiable {
    let assets: [AssetInfo]
    let start: Int

    var id: AssetID { assets[start].id }

    /// Nil when `id` is not among `assets`.
    init?(_ assets: [AssetInfo], showing id: AssetID) {
        guard let start = assets.firstIndex(where: { $0.id == id }) else { return nil }
        self.assets = assets
        self.start = start
    }
}

/// Full-screen pager over a screen's own items, in the screen's order.
struct AssetPreview: View {
    @Environment(AppModel.self) private var model

    let session: PreviewSession
    let choice: (AssetInfo) -> PreviewChoice
    /// Called with the last page shown.
    let close: (AssetID) -> Void

    @State private var page: Int?
    @State private var albumTarget: AssetID?

    init(session: PreviewSession, choice: @escaping (AssetInfo) -> PreviewChoice, close: @escaping (AssetID) -> Void) {
        self.session = session
        self.choice = choice
        self.close = close
        _page = State(initialValue: session.start)
    }

    var body: some View {
        let assets = session.assets
        let current = assets[page ?? session.start].id
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button("Album", systemImage: "rectangle.stack.badge.plus") { albumTarget = current }
                    .accessibilityIdentifier("preview.album")
                ShareButton(id: current)
                Spacer()
                Button("Close") { close(current) }
                    .bold()
                    .accessibilityIdentifier("preview.close")
            }
            .padding()
            pager
            if let page {
                bar(for: assets[page], position: page + 1)
            }
        }
        .background(.black)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("preview")
        .sheet(item: $albumTarget) { AlbumPicker(assetIDs: [$0]) }
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(session.assets.indices, id: \.self) { index in
                    page(for: session.assets[index], isCurrent: index == page)
                        .containerRelativeFrame(.horizontal)
                        .frame(maxHeight: .infinity)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func page(for asset: AssetInfo, isCurrent: Bool) -> some View {
        if asset.kind == .video {
            PreviewVideo(id: asset.id, isCurrent: isCurrent)
        } else {
            PreviewImage(id: asset.id)
        }
    }

    private func bar(for asset: AssetInfo, position: Int) -> some View {
        // An album add from this viewer can protect the photo; offering the screen's actions then
        // would let a tap queue it again.
        let choice = model.protected.contains(asset.id)
            ? PreviewChoice(status: .init(text: "Protected", tint: .keepGreen), actions: [])
            : self.choice(asset)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(details(of: asset))
                Spacer()
                Text("\(position.formatted()) of \(session.assets.count.formatted())")
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let status = choice.status {
                    Text(status.text)
                        .font(.headline)
                        .foregroundStyle(status.tint)
                        .accessibilityIdentifier("preview.status")
                    Spacer()
                }
                ForEach(choice.actions, id: \.title) { action in
                    Button(action: action.perform) {
                        Text(action.title)
                            .font(.headline)
                            .frame(maxWidth: choice.status == nil ? .infinity : nil)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(action.tint)
                    .accessibilityIdentifier("preview.action")
                }
            }
        }
        .padding()
    }

    private func details(of asset: AssetInfo) -> String {
        let parts = [
            Formatting.day(asset.creationDate),
            model.sizes[asset.id].map(Formatting.bytes),
            asset.kind == .video ? Formatting.duration(asset.duration) : nil,
        ]
        return parts.compactMap(\.self).joined(separator: " · ")
    }
}

extension View {
    /// Presents the viewer while `session` is set. With a grid's proxy, closing scrolls the grid to the last asset shown.
    func assetPreview(
        _ session: Binding<PreviewSession?>,
        returningTo grid: ScrollViewProxy? = nil,
        choice: @escaping (AssetInfo) -> PreviewChoice
    ) -> some View {
        fullScreenCover(item: session) { presented in
            AssetPreview(session: presented, choice: choice) { last in
                session.wrappedValue = nil
                grid?.scrollTo(last, anchor: .center)
            }
        }
    }

    /// Touch and hold, or the Preview accessibility action, opens the viewer.
    func opensPreview(_ open: @escaping () -> Void) -> some View {
        onLongPressGesture(perform: open)
            .accessibilityAction(named: "Preview", open)
    }
}

private struct PreviewImage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.displayScale) private var displayScale

    let id: AssetID

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .task(id: id) {
                let pixels = CGSize(width: proxy.size.width * displayScale, height: proxy.size.height * displayScale)
                let loaded = await model.library.thumbnail(for: id, targetSize: pixels)
                guard !Task.isCancelled else { return }
                image = loaded
            }
        }
        .onDisappear { image = nil }
    }
}

/// Loads its player the first time it is the page on screen, and plays only while it is.
private struct PreviewVideo: View {
    @Environment(AppModel.self) private var model

    let id: AssetID
    let isCurrent: Bool

    @State private var player: AVPlayer?
    @State private var failure: String?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            } else {
                PreviewImage(id: id)
                if let failure {
                    ContentUnavailableView("Can't play this video", systemImage: "exclamationmark.triangle", description: Text(failure))
                        .background(.black.opacity(0.6))
                }
            }
        }
        .task(id: isCurrent) {
            guard isCurrent else {
                player?.pause()
                return
            }
            if player == nil, failure == nil {
                do {
                    let item = try await model.library.playerItem(for: id)
                    try Task.checkCancellation()
                    player = AVPlayer(playerItem: item)
                } catch {
                    guard !Task.isCancelled else { return }
                    failure = error.localizedDescription
                }
            }
            guard !Task.isCancelled else { return }
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
