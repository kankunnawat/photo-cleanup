import SwiftUI

/// Collects each tile's frame in global space so a drag can hit-test without UIKit.
private struct GridTileFramesKey: PreferenceKey {
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

/// Drag gesture that paints a `DragMultiSelect.Session` onto a selection, with edge auto-scroll.
private struct DragSelectOverlay: ViewModifier {
    let ids: [AssetID]
    @Binding var selected: Set<AssetID>
    var isEnabled: Bool
    var scrollProxy: ScrollViewProxy
    var columns: Int

    @State private var frames: [Int: CGRect] = [:]
    @State private var session: DragMultiSelect.Session?
    /// Set when the list changed under the drag; the rest of that drag paints nothing.
    @State private var isAbandoned = false
    @State private var finger: CGPoint?
    @State private var viewport: CGRect = .zero
    @State private var scrollDirection: DragMultiSelect.ScrollDirection?

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(GridTileFramesKey.self) { frames = $0 }
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { viewport = $0 }
            .scrollDisabled(session != nil)
            .highPriorityGesture(isEnabled ? drag : nil)
            .onChange(of: isEnabled) { _, enabled in
                if !enabled {
                    endDrag()
                    isAbandoned = false
                }
            }
            .onChange(of: ids) {
                // The edge-scroll loop holds the list it started with, so a still finger would never hit move's check.
                guard session != nil else { return }
                endDrag()
                isAbandoned = true
            }
            .task(id: scrollDirection) {
                guard let scrollDirection else { return }
                while !Task.isCancelled, session != nil {
                    scrollOneRow(scrollDirection)
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged(changed)
            .onEnded { _ in
                endDrag()
                isAbandoned = false
            }
    }

    private func changed(_ value: DragGesture.Value) {
        guard !isAbandoned else { return }
        finger = value.location
        if session == nil {
            // Anchor is where the finger went down, even though the gesture starts after a short move.
            guard let anchor = hit(value.startLocation) ?? hit(value.location) else { return }
            session = DragMultiSelect.Session(anchor: anchor, ids: ids, selected: selected)
        }
        paint(hit(value.location))
        let direction = DragMultiSelect.autoScrollDirection(
            pointerY: value.location.y,
            viewportMinY: viewport.minY,
            viewportMaxY: viewport.maxY
        )
        if direction != scrollDirection { scrollDirection = direction }
    }

    private func scrollOneRow(_ direction: DragMultiSelect.ScrollDirection) {
        paint(finger.flatMap(hit))
        guard let lastHit = session?.lastHit else { return }
        let step = direction == .down ? columns : -columns
        let target = min(max(lastHit + step, 0), ids.count - 1)
        scrollProxy.scrollTo(ids[target], anchor: direction == .down ? .bottom : .top)
    }

    private func paint(_ index: Int?) {
        guard var current = session else { return }
        guard let selection = current.move(to: index, ids: ids) else {
            endDrag()
            isAbandoned = true
            return
        }
        session = current
        if selection != selected { selected = selection }
    }

    private func hit(_ point: CGPoint) -> Int? {
        DragMultiSelect.index(at: point, frames: (0..<ids.count).map { frames[$0] ?? .null })
    }

    private func endDrag() {
        session = nil
        finger = nil
        scrollDirection = nil
    }
}

extension View {
    /// Enables Photos-style drag-to-select over tiles that call `reportsGridTileFrame`.
    func dragSelect(
        ids: [AssetID],
        selected: Binding<Set<AssetID>>,
        enabled: Bool,
        proxy: ScrollViewProxy,
        columns: Int
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
