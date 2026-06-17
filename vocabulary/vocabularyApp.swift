import SwiftUI

@main
struct vocabularyApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var wordStore = WordStore()
    @StateObject private var store = EntryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(wordStore)
                .environmentObject(store)
        }
    }
}
