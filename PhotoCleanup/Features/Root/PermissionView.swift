import SwiftUI

struct PermissionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                page
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var page: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: model.access == .notDetermined ? "photo.on.rectangle.angled" : "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: act) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("permission.action")
        }
        .padding(32)
    }

    private var title: String {
        switch model.access {
        case .notDetermined: "Clean up your photos"
        case .limited: "Full access needed"
        default: "Photo access is off"
        }
    }

    private var message: String {
        switch model.access {
        case .notDetermined:
            "Photo Cleanup needs access to your library to find photos to keep and delete. Nothing leaves your phone."
        case .limited:
            "With limited access the app only sees some photos, so it cannot tell what is safe to delete. Choose \u{201C}Full Access\u{201D} in Settings."
        default:
            "Turn on full photo access for Photo Cleanup in Settings."
        }
    }

    private var buttonTitle: String {
        model.access == .notDetermined ? "Allow access" : "Open Settings"
    }

    private func act() {
        if model.access == .notDetermined {
            Task { await model.requestAccess() }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
