import SwiftUI

@main
struct LapLogApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .preferredColorScheme(state.palette.dark ? .dark : .light)
        }
    }
}
