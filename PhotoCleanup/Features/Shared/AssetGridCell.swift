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

    enum SelectionStyle {
        /// Bulk modes: a red check, and unselected tiles washed out.
        case delete
        /// Around this time: a blue check at full brightness.
        case pick
    }

    @Environment(AppModel.self) private var model

    let asset: AssetInfo
    var isSelected: Bool?
    var badge: Badge?
    var selectionStyle = SelectionStyle.delete
    var isLocked = false

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
                        .foregroundStyle(.white, isSelected ? checkTint : Color.black.opacity(0.3))
                        .padding(4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(5)
                        .accessibilityLabel("Protected")
                }
            }
            .overlay {
                if isSelected == false, selectionStyle == .delete {
                    Color.white.opacity(0.35)
                }
            }
            // The Around grid's selection circle leaves no room in the top row for the badge's word.
            .modifier(BadgeOverlay(badge: badge, showsText: selectionStyle != .pick))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .dynamicTypeSize(...AssetGrid.largestOverlayText)
    }

    private var checkTint: Color {
        selectionStyle == .delete ? .red : .accentColor
    }
}

/// Draws a cell's badge; also used by the placeholder cell for assets that are gone.
struct BadgeOverlay: ViewModifier {
    let badge: AssetGridCell.Badge?
    var showsText = true

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
                case .keep: BadgeLabel(text: "Keep", symbol: "heart.fill", background: .keepGreen, showsText: showsText)
                case .delete: BadgeLabel(text: "Delete", symbol: "trash.fill", background: .red, showsText: showsText)
                case .takenBack: BadgeLabel(text: "Taken back", symbol: "arrow.uturn.backward", background: .gray, showsText: showsText)
                case nil: EmptyView()
                }
            }
    }
}

private struct BadgeLabel: View {
    let text: String
    let symbol: String
    let background: Color
    let showsText: Bool

    var body: some View {
        Group {
            if showsText {
                Label(text, systemImage: symbol)
                    .labelStyle(.titleAndIcon)
            } else {
                Label(text, systemImage: symbol)
                    .labelStyle(.iconOnly)
            }
        }
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
