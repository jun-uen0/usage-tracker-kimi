import SwiftUI

@main
struct KimiUsageTrackerApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(store)
                .onAppear { store.start() }
        } label: {
            MenuLabelView()
                .environmentObject(store)
                .onAppear { store.start() }
        }
        .menuBarExtraStyle(.window)
    }
}
