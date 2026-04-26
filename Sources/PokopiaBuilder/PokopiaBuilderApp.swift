import SwiftUI

@main
struct PokopiaBuilderApp: App {
    @StateObject private var store = PlannerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.titleBar)
    }
}
