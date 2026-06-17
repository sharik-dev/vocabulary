import WidgetKit
import SwiftUI

private enum WidgetConstants {
    static let appGroupId = "group.com.vocabulary.shared"
    static let snapshotKey = "widgetSnapshotV1"
    static let hourlyWordsKey = "hourlyWordsV1"
    static let dailyKind = "dailyVocabulary"
    static let hourlyKind = "hourlyVocabulary"
}

// Local copies of shared models (widget has no access to app target)
enum WDailyState: String, Codable {
    case pending, seen, learned
}

struct WWidgetSnapshot: Codable, Hashable {
    let day: Date
    let wordId: Int
    let en: String
    let fr: String
    let level: String
    let state: WDailyState
}

struct WHourlyWordSnapshot: Codable, Hashable {
    let wordId: Int
    let en: String
    let fr: String
    let level: String
    let validFrom: Date
}

// MARK: - Daily Widget

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: Date(), snapshot: WWidgetSnapshot(day: Date(), wordId: 1, en: "hello", fr: "bonjour", level: "A1", state: .pending))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(DailyEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let now = Date()
        let entry = DailyEntry(date: now, snapshot: loadSnapshot())
        let nextMidnight = Calendar.autoupdatingCurrent.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: now)!
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func loadSnapshot() -> WWidgetSnapshot? {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId) ?? .standard
        guard let data = defaults.data(forKey: WidgetConstants.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WWidgetSnapshot.self, from: data)
    }
}

struct DailyEntry: TimelineEntry {
    let date: Date
    let snapshot: WWidgetSnapshot?
}

struct DailyWidgetView: View {
    var entry: DailyProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.34, green: 0.34, blue: 0.84), Color(red: 0.58, green: 0.28, blue: 0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let snap = entry.snapshot {
                if family == .systemSmall {
                    smallLayout(snap: snap)
                } else {
                    mediumLayout(snap: snap)
                }
            } else {
                emptyLayout
            }
        }
    }

    private func smallLayout(snap: WWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Mot du jour")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(snap.level)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Spacer()
            Text(snap.en)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(snap.fr)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .padding(14)
    }

    private func mediumLayout(snap: WWidgetSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mot du jour")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(snap.en)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(snap.fr)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(snap.level)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Spacer()
                stateIcon(state: snap.state)
            }
        }
        .padding(16)
    }

    private var emptyLayout: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.book.closed.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))
            Text("Ouvre l'app")
                .font(.callout.bold())
                .foregroundStyle(.white)
            Text("Choisis ton niveau")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(14)
    }

    @ViewBuilder
    private func stateIcon(state: WDailyState) -> some View {
        switch state {
        case .learned:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        case .seen:
            Image(systemName: "eye.fill")
                .foregroundStyle(.yellow)
                .font(.title3)
        case .pending:
            EmptyView()
        }
    }
}

struct dailyVocabulary: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetConstants.dailyKind, provider: DailyProvider()) { entry in
            DailyWidgetView(entry: entry)
                .widgetURL(URL(string: "vocabulary://home"))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Mot du jour")
        .description("Affiche le mot du jour avec sa traduction.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Hourly Widget

struct HourlyProvider: TimelineProvider {
    func placeholder(in context: Context) -> HourlyEntry {
        HourlyEntry(date: Date(), snapshot: WHourlyWordSnapshot(wordId: 1, en: "apple", fr: "pomme", level: "A1", validFrom: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (HourlyEntry) -> Void) {
        let words = loadHourlyWords()
        let current = currentWord(from: words)
        completion(HourlyEntry(date: Date(), snapshot: current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HourlyEntry>) -> Void) {
        let now = Date()
        let words = loadHourlyWords()

        if words.isEmpty {
            let entry = HourlyEntry(date: now, snapshot: nil)
            let later = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: now) ?? now
            completion(Timeline(entries: [entry], policy: .after(later)))
            return
        }

        var entries: [HourlyEntry] = []
        let upcoming = words.filter { $0.validFrom >= now.addingTimeInterval(-3600) }

        for snap in upcoming {
            entries.append(HourlyEntry(date: snap.validFrom, snapshot: snap))
        }

        if entries.isEmpty {
            if let last = words.last {
                entries.append(HourlyEntry(date: now, snapshot: last))
            }
        }

        let tomorrow = Calendar.autoupdatingCurrent.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: now)!

        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }

    private func loadHourlyWords() -> [WHourlyWordSnapshot] {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId) ?? .standard
        guard let data = defaults.data(forKey: WidgetConstants.hourlyWordsKey) else { return [] }
        return (try? JSONDecoder().decode([WHourlyWordSnapshot].self, from: data)) ?? []
    }

    private func currentWord(from words: [WHourlyWordSnapshot]) -> WHourlyWordSnapshot? {
        let now = Date()
        return words.last(where: { $0.validFrom <= now })
    }
}

struct HourlyEntry: TimelineEntry {
    let date: Date
    let snapshot: WHourlyWordSnapshot?
}

struct HourlyWidgetView: View {
    var entry: HourlyProvider.Entry
    @Environment(\.widgetFamily) var family

    private var hourLabel: String {
        let cal = Calendar.autoupdatingCurrent
        let hour = cal.component(.hour, from: entry.date)
        return "\(hour)h"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.55, blue: 0.60), Color(red: 0.05, green: 0.38, blue: 0.50)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let snap = entry.snapshot {
                if family == .systemSmall {
                    smallLayout(snap: snap)
                } else {
                    mediumLayout(snap: snap)
                }
            } else {
                emptyLayout
            }
        }
    }

    private func smallLayout(snap: WHourlyWordSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Mot de \(hourLabel)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(snap.level)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Spacer()
            Text(snap.en)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(snap.fr)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .padding(14)
    }

    private func mediumLayout(snap: WHourlyWordSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Mot de \(hourLabel)", systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(snap.en)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(snap.fr)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            Spacer()
            Text(snap.level)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .padding(16)
    }

    private var emptyLayout: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))
            Text("Ouvre l'app")
                .font(.callout.bold())
                .foregroundStyle(.white)
            Text("Pour activer les mots horaires")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(14)
    }
}

struct hourlyVocabulary: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetConstants.hourlyKind, provider: HourlyProvider()) { entry in
            HourlyWidgetView(entry: entry)
                .widgetURL(URL(string: "vocabulary://home"))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Mot de l'heure")
        .description("Un nouveau mot anglais toutes les heures, selon ton niveau.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Daily Small", as: .systemSmall) {
    dailyVocabulary()
} timeline: {
    DailyEntry(date: .now, snapshot: WWidgetSnapshot(day: .now, wordId: 1, en: "hello", fr: "bonjour", level: "A1", state: .learned))
}

#Preview("Hourly Medium", as: .systemMedium) {
    hourlyVocabulary()
} timeline: {
    HourlyEntry(date: .now, snapshot: WHourlyWordSnapshot(wordId: 2, en: "apple", fr: "pomme", level: "B1", validFrom: .now))
}
