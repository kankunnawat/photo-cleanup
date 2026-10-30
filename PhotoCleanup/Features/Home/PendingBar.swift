import SwiftUI

struct PendingBar: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.openApply() } label: {
            HStack(spacing: 12) {
                Image(systemName: "tray.full")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.pendingSummary.keepCount) to keep, \(model.pendingSummary.trashCount) to delete")
                        .font(.headline)
                    Text("\(Formatting.upTo(model.pendingSummary.trashBytes, measuring: model.isMeasuringSizes)). Review and apply.")
                        .font(.caption)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.pendingBar")
    }
}
