import SwiftUI

struct LibrarySummaryCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var countSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.assets.count)")
                        .font(.system(size: countSize, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("home.libraryCount")
                    Text("items on this iPhone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                sizeLabel
            }
            Divider()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 2 : 4)) {
                stat("Photos", value: model.snapshot.photoCount, id: "home.photoCount")
                stat("Videos", value: model.snapshot.videos.count, id: "home.videoCount")
                stat("In Keep", value: model.sources.keepAlbum.count, id: "home.keepCount")
                stat("Protected", value: model.protected.ids.count, id: "home.protectedCount")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var sizeLabel: some View {
        if let progress = model.sizeProgress {
            VStack(alignment: .trailing, spacing: 4) {
                Text("Measuring sizes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(progress.measured), total: Double(max(progress.total, 1)))
                    .frame(width: 110)
            }
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatting.bytes(model.totalBytes))
                    .font(.title3.weight(.semibold))
                Text("up to, on device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stat(_ title: String, value: Int, id: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
                .accessibilityIdentifier(id)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
