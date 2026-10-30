import SwiftUI

/// The toolbar's Sort button: a menu that ticks the screen's current order.
struct SortMenu<Order: Hashable>: View {
    @Binding var selection: Order
    let orders: [Order]
    let label: (Order) -> String
    let id: String

    var body: some View {
        Menu {
            Picker("Sort", selection: $selection) {
                ForEach(orders, id: \.self) { Text(label($0)).tag($0) }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort")
        .accessibilityIdentifier(id)
    }
}

extension AssetOrder {
    var label: String {
        switch self {
        case .oldestFirst: "Oldest first"
        case .newestFirst: "Newest first"
        case .biggestFirst: "Biggest first"
        }
    }
}
