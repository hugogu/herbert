import SwiftUI

@main
struct HerbertApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .defaultAppStorage(store.preferences)
                .tint(Palette.mint)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { store.flush() }
                }
                #if os(macOS)
                    .frame(minWidth: 850, minHeight: 650)
                #endif
        }
        #if os(macOS)
            .defaultSize(width: 1240, height: 850)
        #endif
    }
}
