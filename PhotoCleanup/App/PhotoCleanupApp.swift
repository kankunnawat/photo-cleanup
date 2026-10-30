import SwiftUI

@main
struct PhotoCleanupApp: App {
    @State private var model: AppModel

    init() {
        let persistence = Persistence.live()
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            do {
                try persistence.resetForUITesting()
            } catch {
                fatalError("UI test reset failed: \(error)")
            }
        }
        let model = AppModel(library: PhotoKitLibrary(), persistence: persistence)
        do {
            try ShareExports.clear()
        } catch {
            model.errorMessage = "Old shared files could not be removed: \(error.localizedDescription)"
        }
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
