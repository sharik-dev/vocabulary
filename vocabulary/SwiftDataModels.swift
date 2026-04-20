import Foundation
import SwiftData

@Model
final class DailyEntryModel {
    var day: Date
    var wordId: Int
    var levelRaw: String
    var stateRaw: String
    var revealedAt: Date?
    var learnedAt: Date?

    init(day: Date, wordId: Int, level: CEFRLevel, state: DailyState = .pending) {
        self.day = day.startOfDay
        self.wordId = wordId
        self.levelRaw = level.rawValue
        self.stateRaw = state.rawValue
        self.revealedAt = nil
        self.learnedAt = nil
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

@Model
final class WordProgressModel {
    var wordId: Int
    var levelRaw: String
    var stateRaw: String
    var firstSeenAt: Date?
    var learnedAt: Date?

    init(wordId: Int, level: CEFRLevel, state: WordState = .new) {
        self.wordId = wordId
        self.levelRaw = level.rawValue
        self.stateRaw = state.rawValue
        self.firstSeenAt = nil
        self.learnedAt = nil
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

