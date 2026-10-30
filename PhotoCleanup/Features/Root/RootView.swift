import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Persistence.noticeDismissedKey) private var noticeDismissed = false
    @State private var router = Router()

    var body: some View {
        @Bindable var model = model
        Group {
            if model.access == .full {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            } else {
                PermissionView()
            }
        }
        .environment(router)
        .sheet(isPresented: Binding(get: { !noticeDismissed }, set: { noticeDismissed = !$0 })) {
            ICloudNoticeView { noticeDismissed = true }
                .interactiveDismissDisabled()
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.flushPendingSave()
            }
            if phase == .active, model.access != .full {
                Task { await model.start() }
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .mode(.swipe): MonthPickerView()
        case .mode(.freeUp): FreeUpView()
        case .mode(.screenshots): BulkSelectView(mode: .screenshots)
        case .mode(.largeVideos): BulkSelectView(mode: .largeVideos)
        case .deck(let source): SwipeDeckView(source: source)
        case .apply: ApplyView()
        case .settings: SettingsView()
        }
    }
}
