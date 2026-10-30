import SwiftUI

/// Square grid cell with a size label and an optional selection mark or state badge.
struct AssetGridCell: View {
    enum Badge {
        /// Free up: spared from the delete. Apply: a delete switched to keep.
        case keep
        /// Apply: a keep switched to delete.
        case delete
        /// Apply: decision taken back.
        case takenBack
    }

    @Environment(AppModel.self) private var model

    let asset: AssetInfo
    var isSelected: Bool?
    var badge: Badge?

    var body: some View {
        AssetThumbnail(id: asset.id)
            .aspectRatio(1, contentMode: .fill)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    if asset.kind == .video {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text(Formatting.duration(asset.duration))
                        }
                    }
                    if let bytes = model.sizes[asset.id] {
                        Text(Formatting.bytes(bytes))
                    }
                }
                .lineLimit(1)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
                .padding(4)
            }
            .overlay(alignment: .topTrailing) {
                if let isSelected {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isSelected ? Color.red : Color.black.opacity(0.3))
                        .padding(4)
                }
            }
            .overlay {
                if isSelected == false {
                    Color.white.opacity(0.35)
                }
            }
            .modifier(BadgeOverlay(badge: badge))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .dynamicTypeSize(...AssetGrid.largestOverlayText)
    }
}

/// Draws a cell's badge; also used by the placeholder cell for assets that are gone.
struct BadgeOverlay: ViewModifier {
    let badge: AssetGridCell.Badge?

    /// Only the overlays switch; switching `content` itself would rebuild the thumbnail and flash it gray on every tap.
    func body(content: Content) -> some View {
        content
            .overlay {
                switch badge {
                case .keep: RoundedRectangle(cornerRadius: 6).strokeBorder(.keepGreen, lineWidth: 3)
                case .delete: RoundedRectangle(cornerRadius: 6).strokeBorder(.red, lineWidth: 3)
                case .takenBack: Color(.systemBackground).opacity(0.6)
                case nil: EmptyView()
                }
            }
            .overlay(alignment: badge == .takenBack ? .center : .topLeading) {
                switch badge {
                case .keep: BadgeLabel(text: "Keep", symbol: "heart.fill", background: .keepGreen)
                case .delete: BadgeLabel(text: "Delete", symbol: "trash.fill", background: .red)
                case .takenBack: BadgeLabel(text: "Taken back", symbol: "arrow.uturn.backward", background: .gray)
                case nil: EmptyView()
                }
            }
    }
}

private struct BadgeLabel: View {
    let text: String
    let symbol: String
    let background: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .padding(4)
            .dynamicTypeSize(...AssetGrid.largestOverlayText)
    }
}

enum AssetGrid {
    static let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 4)
    /// Tiles stay about 90 pt wide at every text size, so their labels stop growing here.
    static let largestOverlayText = DynamicTypeSize.xxLarge
}
