import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    private let tileColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.hasLoaded {
                    LibrarySummaryCard()
                    if model.sources.keepAlbumMissing {
                        KeepAlbumMissingRow()
                    }
                    LazyVGrid(columns: tileColumns, spacing: 12) {
                        ForEach(CleanupMode.allCases) { mode in
                            Button { router.path.append(.mode(mode)) } label: {
                                ModeTile(mode: mode)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("mode.\(mode.rawValue)")
                        }
                    }
                    if model.log.totalBytes > 0 || model.log.totalDeleted > 0 {
                        FreedSoFarRow(log: model.log)
                    }
                } else {
                    ProgressView("Reading your library…")
                        .padding(.top, 80)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Photo Cleanup")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.path.append(.settings) } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !model.pendingSummary.isEmpty {
                PendingBar()
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }
}

private struct ModeTile: View {
    @Environment(AppModel.self) private var model
    let mode: CleanupMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: mode.systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(mode.tint.gradient, in: RoundedRectangle(cornerRadius: 12))
            Text(mode.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(mode.summary(in: model))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct KeepAlbumMissingRow: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keep album not found")
                    .font(.headline)
                Text("Photos you kept before are no longer protected. A new Keep album is created the next time you apply photos to keep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.keepAlbumMissing")
    }
}

private struct FreedSoFarRow: View {
    let log: CleanupLog

    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.keepGreen)
            Text("Freed up to \(Formatting.bytes(log.totalBytes)) from \(Formatting.items(log.totalDeleted))")
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
