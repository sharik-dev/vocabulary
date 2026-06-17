import Foundation
import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

@MainActor
final class WordStore: ObservableObject {
    private(set) var allWords: [Word] = []
    private(set) var wordsById: [Int: Word] = [:]
    private(set) var wordsByLevel: [CEFRLevel: [Word]] = [:]
    private(set) var loadError: String?

    init() {
        load()
    }

    func load() {
        do {
            guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
                loadError = "Impossible de trouver words.json dans le bundle."
                allWords = []
                wordsById = [:]
                wordsByLevel = [:]
                return
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let words = try decoder.decode([Word].self, from: data)

            allWords = words
            wordsById = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })

            var grouped: [CEFRLevel: [Word]] = [:]
            for word in words {
                grouped[word.level, default: []].append(word)
            }
            for level in CEFRLevel.allCases {
                grouped[level] = (grouped[level] ?? []).sorted(by: { $0.id < $1.id })
            }
            wordsByLevel = grouped
            loadError = nil
        } catch {
            loadError = "Erreur de chargement JSON: \(error.localizedDescription)"
            allWords = []
            wordsById = [:]
            wordsByLevel = [:]
        }
    }

    func word(id: Int) -> Word? {
        wordsById[id]
    }

    func words(for level: CEFRLevel) -> [Word] {
        wordsByLevel[level] ?? []
    }

    func totalCount(for level: CEFRLevel) -> Int {
        wordsByLevel[level]?.count ?? 0
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

@MainActor
enum DailyWordService {
    static func syncUpToToday(level: CEFRLevel, wordStore: WordStore, settings: SettingsStore, context: ModelContext) {
        let today = Date().startOfDay

        let lastEntry = fetchLastEntry(level: level, context: context)
        let startDay: Date = {
            guard let lastEntry else { return today }
            guard let next = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: lastEntry.day.startOfDay) else {
                return today
            }
            return min(next, today)
        }()

        let daysToGenerate = daysBetweenInclusive(from: startDay, to: today)
        guard !daysToGenerate.isEmpty else {
            updateWidgetSnapshotIfPossible(level: level, wordStore: wordStore, context: context)
            return
        }

        let alreadyAssignedIds = Set(fetchEntries(level: level, context: context).map(\.wordId))
        var assignedIds = alreadyAssignedIds

        let learnedIds = Set(fetchWordProgress(level: level, context: context)
            .filter { $0.state == .learned }
            .map(\.wordId))

        var orderedIds = wordStore.words(for: level).map(\.id)
        var rng = SeededGenerator(seed: settings.shuffleSeed ^ UInt64(level.sortOrder &* 0x9E3779B9))
        orderedIds.shuffle(using: &rng)

        var cursor = settings.nextIndex(for: level)

        for day in daysToGenerate {
            if fetchEntry(day: day, level: level, context: context) != nil {
                continue
            }

            guard let nextWordId = pickNextWordId(
                orderedIds: orderedIds,
                learnedIds: learnedIds,
                assignedIds: assignedIds,
                cursor: &cursor
            ) else {
                break // niveau terminé
            }

            assignedIds.insert(nextWordId)
            let entry = DailyEntryModel(day: day, wordId: nextWordId, level: level, state: .pending)
            context.insert(entry)
        }

        settings.setNextIndex(cursor, for: level)
        updateWidgetSnapshotIfPossible(level: level, wordStore: wordStore, context: context)
        updateHourlyWords(level: level, wordStore: wordStore)
    }

    static func markSeen(entry: DailyEntryModel, level: CEFRLevel, wordStore: WordStore, context: ModelContext) {
        guard entry.state == .pending else {
            updateWidgetSnapshotIfPossible(level: level, wordStore: wordStore, context: context)
            return
        }

        entry.state = .seen
        entry.revealedAt = entry.revealedAt ?? Date()
        upsertProgress(wordId: entry.wordId, level: level, newState: .seen, context: context)
        updateWidgetSnapshotIfPossible(level: level, wordStore: wordStore, context: context)
    }

    static func markLearned(entry: DailyEntryModel, level: CEFRLevel, wordStore: WordStore, context: ModelContext) {
        entry.state = .learned
        entry.revealedAt = entry.revealedAt ?? Date()
        entry.learnedAt = entry.learnedAt ?? Date()
        upsertProgress(wordId: entry.wordId, level: level, newState: .learned, context: context)
        updateWidgetSnapshotIfPossible(level: level, wordStore: wordStore, context: context)
    }

    static func markReview(entry: DailyEntryModel, level: CEFRLevel, wordStore: WordStore, context: ModelContext) {
        entry.state = .seen
        entry.learnedAt = nil
        upsertProgress(wordId: entry.wordId, level: level, newState: .seen, context: context)
        updateWidgetSnapshotIfPossible(level: level, wordStore: wordStore, context: context)
    }

    static func resetProgress(settings: SettingsStore, context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<DailyEntryModel>())) ?? []
        for e in entries { context.delete(e) }
        let progresses = (try? context.fetch(FetchDescriptor<WordProgressModel>())) ?? []
        for p in progresses { context.delete(p) }

        settings.resetProgressPointers()

        let defaults = UserDefaults(suiteName: AppConstants.appGroupId) ?? .standard
        defaults.removeObject(forKey: AppConstants.WidgetKey.snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func fetchEntry(day: Date, level: CEFRLevel, context: ModelContext) -> DailyEntryModel? {
        let d = day.startOfDay
        let levelRaw = level.rawValue
        var descriptor = FetchDescriptor<DailyEntryModel>(
            predicate: #Predicate { $0.day == d && $0.levelRaw == levelRaw },
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchEntries(level: CEFRLevel, context: ModelContext) -> [DailyEntryModel] {
        let levelRaw = level.rawValue
        let descriptor = FetchDescriptor<DailyEntryModel>(
            predicate: #Predicate { $0.levelRaw == levelRaw }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchLastEntry(level: CEFRLevel, context: ModelContext) -> DailyEntryModel? {
        let levelRaw = level.rawValue
        var descriptor = FetchDescriptor<DailyEntryModel>(
            predicate: #Predicate { $0.levelRaw == levelRaw },
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchWordProgress(level: CEFRLevel, context: ModelContext) -> [WordProgressModel] {
        let levelRaw = level.rawValue
        let descriptor = FetchDescriptor<WordProgressModel>(
            predicate: #Predicate { $0.levelRaw == levelRaw }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func pickNextWordId(
        orderedIds: [Int],
        learnedIds: Set<Int>,
        assignedIds: Set<Int>,
        cursor: inout Int
    ) -> Int? {
        var i = max(0, cursor)
        while i < orderedIds.count {
            let id = orderedIds[i]
            i += 1
            if learnedIds.contains(id) { continue }
            if assignedIds.contains(id) { continue }
            cursor = i
            return id
        }
        cursor = orderedIds.count
        return nil
    }

    private static func daysBetweenInclusive(from: Date, to: Date) -> [Date] {
        let start = from.startOfDay
        let end = to.startOfDay
        guard start <= end else { return [] }
        var out: [Date] = []
        var current = start
        while current <= end {
            out.append(current)
            current = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: current)!
        }
        return out
    }

    private static func upsertProgress(wordId: Int, level: CEFRLevel, newState: WordState, context: ModelContext) {
        let targetWordId = wordId
        var descriptor = FetchDescriptor<WordProgressModel>(
            predicate: #Predicate { $0.wordId == targetWordId }
        )
        descriptor.fetchLimit = 1
        let existing = try? context.fetch(descriptor).first

        if let existing {
            switch (existing.state, newState) {
            case (.learned, .seen):
                existing.state = .seen
                existing.learnedAt = nil
            default:
                existing.state = newState
                if newState == .seen { existing.firstSeenAt = existing.firstSeenAt ?? Date() }
                if newState == .learned { existing.learnedAt = existing.learnedAt ?? Date() }
            }
            existing.level = level
        } else {
            let progress = WordProgressModel(wordId: wordId, level: level, state: newState)
            if newState == .seen { progress.firstSeenAt = Date() }
            if newState == .learned {
                progress.firstSeenAt = Date()
                progress.learnedAt = Date()
            }
            context.insert(progress)
        }
    }

    static func updateHourlyWords(level: CEFRLevel, wordStore: WordStore) {
        let words = wordStore.words(for: level)
        guard !words.isEmpty else { return }

        let today = Date().startOfDay
        let cal = Calendar.autoupdatingCurrent
        let dayNumber = Int(today.timeIntervalSince1970 / 86400)
        let seed = (UInt64(bitPattern: Int64(dayNumber)) &* 0x9E3779B97F4A7C15) ^ UInt64(level.sortOrder * 17)
        var rng = SeededGenerator(seed: seed)
        var shuffled = words
        shuffled.shuffle(using: &rng)

        var snapshots: [HourlyWordSnapshot] = []
        for hour in 0..<24 {
            let word = shuffled[hour % shuffled.count]
            if let hourDate = cal.date(byAdding: .hour, value: hour, to: today) {
                snapshots.append(HourlyWordSnapshot(
                    wordId: word.id,
                    en: word.en,
                    fr: word.fr,
                    level: level.rawValue,
                    validFrom: hourDate
                ))
            }
        }

        let defaults = UserDefaults(suiteName: AppConstants.appGroupId) ?? .standard
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: AppConstants.WidgetKey.hourlyWords)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "hourlyVocabulary")
    }

    private static func updateWidgetSnapshotIfPossible(level: CEFRLevel, wordStore: WordStore, context: ModelContext) {
        let today = Date().startOfDay
        guard let entry = fetchEntry(day: today, level: level, context: context) else {
            return
        }
        guard let word = wordStore.word(id: entry.wordId) else {
            return
        }

        let snapshot = WidgetSnapshot(
            day: today,
            wordId: word.id,
            en: word.en,
            fr: word.fr,
            level: level,
            state: entry.state
        )

        let defaults = UserDefaults(suiteName: AppConstants.appGroupId) ?? .standard
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: AppConstants.WidgetKey.snapshot)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "dailyVocabulary")
    }
}

@MainActor
enum ProgressService {
    struct Stats: Hashable {
        let learned: Int
        let seen: Int
        let remaining: Int
        let total: Int
    }

    static func stats(level: CEFRLevel? = nil, wordStore: WordStore, context: ModelContext) -> Stats {
        let words: [Word] = {
            if let level { return wordStore.words(for: level) }
            return wordStore.allWords
        }()

        let total = words.count
        guard total > 0 else {
            return Stats(learned: 0, seen: 0, remaining: 0, total: 0)
        }

        let wordIds = Set(words.map(\.id))
        let descriptor = FetchDescriptor<WordProgressModel>()
        let progresses = (try? context.fetch(descriptor)) ?? []

        var learned = 0
        var seen = 0
        for p in progresses where wordIds.contains(p.wordId) {
            switch p.state {
            case .learned: learned += 1
            case .seen: seen += 1
            case .new: break
            }
        }

        return Stats(learned: learned, seen: seen, remaining: max(0, total - learned), total: total)
    }
}

enum NotificationScheduler {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func currentStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    static func scheduleDailyReminder(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [AppConstants.NotificationId.dailyReminder])

        let content = UNMutableNotificationContent()
        content.title = "Mot du jour"
        content.body = "Ton mot du jour est prêt"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: AppConstants.NotificationId.dailyReminder,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [AppConstants.NotificationId.dailyReminder])
    }
}
