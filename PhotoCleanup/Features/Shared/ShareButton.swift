import SwiftUI
import UIKit

/// Exports the photo first, then opens the share sheet with the file, so a slow iCloud download
/// can be cancelled from the button and the file is removed once the sheet closes.
struct ShareButton: View {
    @Environment(AppModel.self) private var model

    let id: AssetID

    @State private var export: Task<Void, Never>?
    @State private var shared: SharedFile?
    @State private var failure: String?

    var body: some View {
        Button {
            if export == nil {
                start()
            } else {
                cancel()
            }
        } label: {
            if export == nil {
                Label("Share", systemImage: "square.and.arrow.up")
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                    Text("Cancel")
                }
            }
        }
        .accessibilityIdentifier("preview.share")
        .onChange(of: id) { cancel() }
        .onDisappear { cancel() }
        .sheet(item: $shared) { file in
            ShareSheet(file: file.url) { shared = nil }
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
                .onDisappear { discard(file.url) }
        }
        .alert("Can't share", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK") {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func start() {
        let id = id
        export = Task {
            do {
                let file = try await model.library.exportOriginal(for: id)
                if Task.isCancelled {
                    discard(file)
                } else {
                    shared = SharedFile(url: file)
                }
            } catch {
                if !Task.isCancelled { failure = error.localizedDescription }
            }
            if !Task.isCancelled { export = nil }
        }
    }

    private func cancel() {
        export?.cancel()
        export = nil
    }

    private func discard(_ file: URL) {
        do {
            try ShareExports.discard(file)
        } catch {
            failure = "The shared copy could not be removed: \(error.localizedDescription)"
        }
    }
}

private struct SharedFile: Identifiable {
    let url: URL

    var id: URL { url }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let file: URL
    let finished: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in finished() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
