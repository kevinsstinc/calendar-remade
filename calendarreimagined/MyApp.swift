import SwiftUI

@main struct MyApp: App {
    @State private var store = EventStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
