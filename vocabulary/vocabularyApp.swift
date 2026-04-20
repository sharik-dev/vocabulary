import SwiftUI
import SwiftData

@main
struct vocabularyApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var wordStore = WordStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(wordStore)
        }
        .modelContainer(for: [DailyEntryModel.self, WordProgressModel.self])
    }
}
