import SwiftUI

@main
struct HerbertApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var battlefield = BattlefieldModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(battlefield)
                .defaultAppStorage(store.preferences)
                .tint(Palette.mint)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { store.flush() }
                    #if os(iOS)
                        if phase == .background { Task { await battlefield.stop(reason: .backgrounded) } }
                    #endif
                }
                #if os(macOS)
                    .frame(minWidth: 850, minHeight: allowsShortTestWindow ? 300 : 650)
                #endif
        }
        #if os(macOS)
            .defaultSize(width: 1240, height: 850)
        #endif
    }

    private var allowsShortTestWindow: Bool {
        #if DEBUG
            // Exercise the short-height layout on Mac when no iOS runtime is available.
            ProcessInfo.processInfo.arguments.contains("--ui-testing")
                && ProcessInfo.processInfo.arguments.contains("--ui-testing-short-window")
        #else
            false
        #endif
    }
}
