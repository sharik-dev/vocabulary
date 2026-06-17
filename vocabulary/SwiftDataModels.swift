import Foundation
import SwiftUI

// Lightweight persistence (no SwiftData) so the app runs on iOS 16+.
// The data set is tiny — one entry per day per level + per-word progress —
// so it's stored as JSON on disk and kept in memory by `EntryStore`.

struct DailyEntryModel: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var day: Date
    var wordId: Int
    var levelRaw: String
    var stateRaw: String
    var revealedAt: Date?
    var learnedAt: Date?

    init(id: UUID = UUID(), day: Date, wordId: Int, level: CEFRLevel, state: DailyState = .pending) {
        self.id = id
        self.day = day.startOfDay
        self.wordId = wordId
        self.levelRaw = level.rawValue
        self.stateRaw = state.rawValue
    }

    var level: CEFRLevel {
        get { CEFRLevel(rawValue: levelRaw) ?? .a1 }
        set { levelRaw = newValue.rawValue }
    }
    var state: DailyState {
        get { DailyState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }
}

struct WordProgressModel: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var wordId: Int
    var levelRaw: String
    var stateRaw: String
    var firstSeenAt: Date?
    var learnedAt: Date?

    init(id: UUID = UUID(), wordId: Int, level: CEFRLevel, state: WordState = .new) {
        self.id = id
        self.wordId = wordId
        self.levelRaw = level.rawValue
        self.stateRaw = state.rawValue
    }

    var level: CEFRLevel {
        get { CEFRLevel(rawValue: levelRaw) ?? .a1 }
        set { levelRaw = newValue.rawValue }
    }
    var state: WordState {
        get { WordState(rawValue: stateRaw) ?? .new }
        set { stateRaw = newValue.rawValue }
    }
}

// MARK: - Store

@MainActor
final class EntryStore: ObservableObject {
    @Published private(set) var entries: [DailyEntryModel] = []
    @Published private(set) var progress: [WordProgressModel] = []

    private struct Payload: Codable {
        var entries: [DailyEntryModel]
        var progress: [WordProgressModel]
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vocabulary-store.json")
    }()

    init() { load() }

    // ── Queries ──────────────────────────────────────────────────────
    func entry(day: Date, level: CEFRLevel) -> DailyEntryModel? {
        let d = day.startOfDay
        return entries.first { $0.day == d && $0.levelRaw == level.rawValue }
    }
    func lastEntry(level: CEFRLevel) -> DailyEntryModel? {
        entries.filter { $0.levelRaw == level.rawValue }.max { $0.day < $1.day }
    }
    func entries(level: CEFRLevel) -> [DailyEntryModel] {
        entries.filter { $0.levelRaw == level.rawValue }
    }
    func progress(wordId: Int) -> WordProgressModel? {
        progress.first { $0.wordId == wordId }
    }
    func progresses(level: CEFRLevel) -> [WordProgressModel] {
        progress.filter { $0.levelRaw == level.rawValue }
    }
    func learnedWordIds(level: CEFRLevel) -> Set<Int> {
        Set(progresses(level: level).filter { $0.state == .learned }.map(\.wordId))
    }

    // ── Mutations ────────────────────────────────────────────────────
    func insertEntry(_ e: DailyEntryModel) { entries.append(e); save() }

    func removeEntry(id: UUID) { entries.removeAll { $0.id == id }; save() }

    @discardableResult
    func updateEntry(id: UUID, _ mutate: (inout DailyEntryModel) -> Void) -> DailyEntryModel? {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return nil }
        mutate(&entries[i]); save(); return entries[i]
    }

    func upsertProgress(_ p: WordProgressModel) {
        if let i = progress.firstIndex(where: { $0.wordId == p.wordId }) { progress[i] = p }
        else { progress.append(p) }
        save()
    }

    func reset() { entries = []; progress = []; save() }

    // ── Persistence ──────────────────────────────────────────────────
    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        entries = payload.entries
        progress = payload.progress
    }
    private func save() {
        let payload = Payload(entries: entries, progress: progress)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
