import Foundation

// Drives deterministic states for App Store screenshots. The app is launched with
// `-UITestMode YES -UITestScreen <name>`; this seeds progress + picks the screen
// so screenshots can be captured with `simctl` (no UITest target required).
//
// Screens: "onboarding" · "onboarding_widget" · "home" · "progres"

@MainActor
enum UITestSupport {
    static var isActive: Bool { CommandLine.arguments.contains("-UITestMode") }

    static var screen: String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-UITestScreen"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    static var showsOnboarding: Bool {
        screen == "onboarding" || screen == "onboarding_widget"
    }
    static var onboardingStartPage: Int { screen == "onboarding_widget" ? 2 : 0 }
    static var initialTab: Int { screen == "progres" ? 1 : 0 }
    static var autoReveal: Bool { screen == "home" || screen == nil }

    static func seedIfNeeded(wordStore: WordStore, settings: SettingsStore, store: EntryStore) {
        guard isActive else { return }

        settings.selectedLevelRaw = CEFRLevel.b1.rawValue
        store.reset()

        for level in CEFRLevel.allCases {
            let words = wordStore.words(for: level)
            let learnedCount = min(words.count, level == .b1 ? 24 : 12)
            for w in words.prefix(learnedCount) {
                DailyWordService.setWordState(wordId: w.id, level: level, state: .learned, store: store)
            }
            for w in words.dropFirst(learnedCount).prefix(8) {
                DailyWordService.setWordState(wordId: w.id, level: level, state: .seen, store: store)
            }
        }

        settings.onboardingCompleted = !showsOnboarding
        if !showsOnboarding {
            DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, store: store)
            DailyWordService.updateHourlyWords(level: settings.selectedLevel, wordStore: wordStore)

            // Force a clean, clearly-translated word for the screenshot.
            if let nice = wordStore.words(for: .b1).first(where: { $0.en == "knowledge" }),
               let today = store.entry(day: Date().startOfDay, level: .b1) {
                store.updateEntry(id: today.id) { $0.wordId = nice.id }
            }
        }
    }
}
