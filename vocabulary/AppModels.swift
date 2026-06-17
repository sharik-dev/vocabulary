import Foundation

enum CEFRLevel: String, CaseIterable, Codable, Identifiable, Hashable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .a1: 0
        case .a2: 1
        case .b1: 2
        case .b2: 3
        }
    }

    var title: String { rawValue }
}

struct Word: Identifiable, Codable, Hashable {
    let id: Int
    let en: String
    let fr: String
    let level: CEFRLevel
}

enum DailyState: String, Codable, Hashable {
    case pending
    case seen
    case learned
}

enum WordState: String, Codable, Hashable {
    case new
    case seen
    case learned
}

struct WidgetSnapshot: Codable, Hashable {
    let day: Date
    let wordId: Int
    let en: String
    let fr: String
    let level: CEFRLevel
    let state: DailyState
}

struct HourlyWordSnapshot: Codable, Hashable {
    let wordId: Int
    let en: String
    let fr: String
    let level: String
    let validFrom: Date
}

extension Date {
    var startOfDay: Date {
        Calendar.autoupdatingCurrent.startOfDay(for: self)
    }
}

