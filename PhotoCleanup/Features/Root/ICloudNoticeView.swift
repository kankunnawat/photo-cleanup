import SwiftUI

struct ICloudNoticeView: View {
    let onDismiss: () -> Void

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
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Before you start")
                .font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 16) {
                Label(SafetyCopy.iCloud, systemImage: "exclamationmark.icloud")
                Label("iOS asks you to confirm every delete. Deleted items go to Recently Deleted for 30 days.", systemImage: "trash")
                Label("Photos in your Keep album, Favorites, hidden photos and the albums you protect are never offered for deletion.", systemImage: "lock.shield")
            }
            .font(.body)
            Spacer()
            Button(action: onDismiss) {
                Text("Got it")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}
