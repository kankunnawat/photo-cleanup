import SwiftUI

/// Collects each tile's frame in global space so a drag can hit-test without UIKit.
struct GridTileFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Publishes this tile's global frame under `index` for drag-select hit-testing.
    func reportsGridTileFrame(index: Int) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(key: GridTileFramesKey.self, value: [index: geo.frame(in: .global)])
            }
        }
    }
}

/// Frames keyed by flat grid index, ordered for `DragMultiSelect.index(at:frames:)`.
enum GridTileFrames {
    static func ordered(_ frames: [Int: CGRect], count: Int) -> [CGRect] {
        (0..<count).map { frames[$0] ?? .null }
    }
}

private struct ViewportFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Drag gesture that paints a `DragMultiSelect.Session` onto a selection, with edge auto-scroll.
struct DragSelectOverlay: ViewModifier {
    let ids: [AssetID]
    @Binding var selected: Set<AssetID>
    var isEnabled: Bool
    var scrollProxy: ScrollViewProxy
    var columns: Int = 4

    @State private var frames: [Int: CGRect] = [:]
    @State private var session: DragMultiSelect.Session?
    @State private var finger: CGPoint?
    @State private var viewport: CGRect = .zero
    @State private var scrollDirection = 0

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(GridTileFramesKey.self) { frames = $0 }
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: ViewportFrameKey.self, value: geo.frame(in: .global))
                }
            }
            .onPreferenceChange(ViewportFrameKey.self) { viewport = $0 }
            .scrollDisabled(session != nil)
            .highPriorityGesture(isEnabled ? drag : nil)
            .onChange(of: isEnabled) { _, enabled in
                if !enabled {
                    session = nil
                    finger = nil
                    scrollDirection = 0
                }
            }
            .task(id: scrollDirection) {
                guard scrollDirection != 0 else { return }
                while !Task.isCancelled, scrollDirection != 0, session != nil {
                    scrollTowardEdge()
                    try? await Task.sleep(for: .milliseconds(16))
                }
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged(changed)
            .onEnded { _ in
                session = nil
                finger = nil
                scrollDirection = 0
            }
    }

    private func changed(_ value: DragGesture.Value) {
        finger = value.location
        let list = GridTileFrames.ordered(frames, count: ids.count)
        if session == nil {
            // Anchor is where the finger went down, even though the gesture starts after a short move.
            guard let index = DragMultiSelect.index(at: value.startLocation, frames: list)
                    ?? DragMultiSelect.index(at: value.location, frames: list) else { return }
            let selectedIndices = Set(ids.indices.filter { selected.contains(ids[$0]) })
            let started = DragMultiSelect.Session(anchor: index, selected: selectedIndices)
            session = started
            selected = started.selectedIDs(current: index, ids: ids)
        } else if let current = session, let index = DragMultiSelect.index(at: value.location, frames: list) {
            selected = current.selectedIDs(current: index, ids: ids)
        }
        let delta = DragMultiSelect.autoScrollDelta(
            pointerY: value.location.y,
            viewportMinY: viewport.minY,
            viewportMaxY: viewport.maxY
        )
        let direction = delta == 0 ? 0 : (delta < 0 ? -1 : 1)
        if direction != scrollDirection { scrollDirection = direction }
        if direction != 0 { scrollTowardEdge() }
    }

    private func scrollTowardEdge() {
        guard let currentSession = session, scrollDirection != 0, !ids.isEmpty else { return }
        let list = GridTileFrames.ordered(frames, count: ids.count)
        let current = finger.flatMap { DragMultiSelect.index(at: $0, frames: list) } ?? currentSession.anchor
        let step = max(columns, 1) * scrollDirection
        let target = min(max(current + step, 0), ids.count - 1)
        scrollProxy.scrollTo(ids[target], anchor: scrollDirection < 0 ? .top : .bottom)
        if let finger, let index = DragMultiSelect.index(at: finger, frames: GridTileFrames.ordered(frames, count: ids.count)) {
            selected = currentSession.selectedIDs(current: index, ids: ids)
        }
    }
}

extension View {
    /// Enables Photos-style drag-to-select over tiles that call `reportsGridTileFrame`.
    func dragSelect(
        ids: [AssetID],
        selected: Binding<Set<AssetID>>,
        enabled: Bool,
        proxy: ScrollViewProxy,
        columns: Int = 4
    ) -> some View {
        modifier(DragSelectOverlay(
            ids: ids,
            selected: selected,
            isEnabled: enabled,
            scrollProxy: proxy,
            columns: columns
        ))
    }
}
