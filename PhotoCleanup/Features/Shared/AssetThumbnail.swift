import SwiftUI

struct AssetThumbnail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.displayScale) private var displayScale

    let id: AssetID
    var pointSize = CGSize(width: 120, height: 120)

    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemFill)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .task(id: id) {
                let pixels = CGSize(width: pointSize.width * displayScale, height: pointSize.height * displayScale)
                let loaded = await model.library.thumbnail(for: id, targetSize: pixels)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.15)) { image = loaded }
            }
            .onDisappear { image = nil }
    }
}
