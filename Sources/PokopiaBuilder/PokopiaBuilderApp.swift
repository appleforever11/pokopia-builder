import SwiftUI

@main
struct PokopiaBuilderApp: App {
    @StateObject private var store = PlannerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 700)
        .windowStyle(.titleBar)
    }
}
