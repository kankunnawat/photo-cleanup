import SwiftUI

struct MonthPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                Picker("Show", selection: $model.swipeFilter) {
                    ForEach(MediaFilter.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("months.kind")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                Button { router.path.append(.deck(.shuffle)) } label: {
                    Label("Shuffle all months", systemImage: "shuffle")
                        .font(.headline)
                }
                .accessibilityIdentifier("deck.shuffle")
                .disabled(model.monthRows.isEmpty)
            }
            Section("Months") {
                ForEach(model.monthRows) { row in
                    Button { router.path.append(.deck(.month(row.group))) } label: {
                        HStack {
                            Text(Formatting.monthTitle(row.group.key))
                                .foregroundStyle(row.open == 0 ? .secondary : .primary)
                            Spacer()
                            if row.open == 0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.keepGreen)
                            } else {
                                Text("\(row.open) of \(row.total)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .disabled(row.open == 0)
                    .accessibilityIdentifier("months.row")
                }
                if model.monthRows.isEmpty, model.swipeFilter != .all {
                    Text(model.swipeFilter == .videos ? "No videos in your library." : "No photos in your library.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Swipe review")
    }
}
