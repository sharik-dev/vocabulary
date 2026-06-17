import WidgetKit
import SwiftUI

extension View {
    /// `containerBackground` is iOS 17+. On iOS 16 the widget view draws its own
    /// background (our gradient ZStack fills the whole widget), so this is a no-op.
    @ViewBuilder
    func widgetClearBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}

extension WidgetConfiguration {
    /// Make the widget fill the whole block edge-to-edge (iOS 17 adds inner
    /// content margins; iOS 16 has none, so this is a no-op there).
    func filledBlock() -> some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }
}

private enum WidgetConstants {
    static let appGroupId = "group.vocabularyBySharik"
    static let snapshotKey = "widgetSnapshotV1"
    static let hourlyWordsKey = "hourlyWordsV1"
    static let dailyKind = "dailyVocabulary"
    static let hourlyKind = "hourlyVocabulary"
}

// Palette shared with the app (editorial warm theme).
private enum WTheme {
    static let clay      = Color(red: 0.722, green: 0.361, blue: 0.220) // #B85C38
    static let clayDeep  = Color(red: 0.541, green: 0.247, blue: 0.133) // #8A3F22
    static let espresso  = Color(red: 0.231, green: 0.196, blue: 0.165) // #3B322A
    static let ink       = Color(red: 0.133, green: 0.122, blue: 0.106) // #221F1B

    static let daily  = LinearGradient(colors: [clay, clayDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let hourly = LinearGradient(colors: [espresso, ink], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
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

// MARK: - Lock screen (accessory) layouts
//
// Lock-screen widgets are rendered monochrome/vibrant by the system, so we
// drop the gradient and rely on type hierarchy + an accentable label.

struct AccessoryRectView: View {
    let label: String
    let icon: String
    let en: String?
    let fr: String?
    let level: String?

    var body: some View {
        if let en, let fr {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.caption2)
                    Text("\(label)\(level.map { " · \($0)" } ?? "")")
                        .font(.caption2.weight(.semibold))
                }
                .widgetAccentable()
                Text(en)
                    .font(.system(.headline, design: .serif))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(fr)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label(label, systemImage: icon).font(.caption2.weight(.semibold)).widgetAccentable()
                Text("Ouvre l'app").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct AccessoryInlineView: View {
    let prefix: String
    let en: String?
    let fr: String?
    var body: some View {
        if let en, let fr {
            Text("\(prefix) \(en) — \(fr)")
        } else {
            Text("\(prefix) Vocabulary")
        }
    }
}

// MARK: - Daily Widget

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: Date(), snapshot: WWidgetSnapshot(day: Date(), wordId: 1, en: "hello", fr: "bonjour", level: "A1", state: .pending))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        let words = loadHourlyWords()
        let current = words.last(where: { $0.validFrom <= Date() }) ?? words.first
        completion(DailyEntry(date: Date(), snapshot: current.map(snapshot(from:)) ?? loadSnapshot()))
    }

    // The word rotates every hour (shares the same hourly word list as the
    // "Mot de l'heure" widget) so every widget changes throughout the day.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let now = Date()
        let words = loadHourlyWords()

        let nextMidnight = Calendar.autoupdatingCurrent.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: now)!

        guard !words.isEmpty else {
            let entry = DailyEntry(date: now, snapshot: loadSnapshot())
            let later = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: now) ?? now
            completion(Timeline(entries: [entry], policy: .after(later)))
            return
        }

        var entries: [DailyEntry] = words
            .filter { $0.validFrom >= now.addingTimeInterval(-3600) }
            .map { DailyEntry(date: $0.validFrom, snapshot: snapshot(from: $0)) }

        if entries.isEmpty, let last = words.last {
            entries = [DailyEntry(date: now, snapshot: snapshot(from: last))]
        }
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    private func snapshot(from w: WHourlyWordSnapshot) -> WWidgetSnapshot {
        WWidgetSnapshot(day: w.validFrom, wordId: w.wordId, en: w.en, fr: w.fr, level: w.level, state: .pending)
    }

    private func loadSnapshot() -> WWidgetSnapshot? {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId) ?? .standard
        guard let data = defaults.data(forKey: WidgetConstants.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WWidgetSnapshot.self, from: data)
    }

    private func loadHourlyWords() -> [WHourlyWordSnapshot] {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId) ?? .standard
        guard let data = defaults.data(forKey: WidgetConstants.hourlyWordsKey) else { return [] }
        return (try? JSONDecoder().decode([WHourlyWordSnapshot].self, from: data)) ?? []
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
        switch family {
        case .accessoryRectangular:
            AccessoryRectView(label: "Mot du jour", icon: "text.book.closed.fill",
                              en: entry.snapshot?.en, fr: entry.snapshot?.fr, level: entry.snapshot?.level)
        case .accessoryInline:
            AccessoryInlineView(prefix: "📖", en: entry.snapshot?.en, fr: entry.snapshot?.fr)
        default:
            ZStack {
                WTheme.daily
                if let snap = entry.snapshot {
                    if family == .systemSmall { smallLayout(snap: snap) }
                    else { mediumLayout(snap: snap) }
                } else {
                    emptyLayout
                }
            }
        }
    }

    private func smallLayout(snap: WWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Text(snap.level)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.22))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 8)
            Text(snap.en)
                .font(WTheme.serif(28))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
            Rectangle()
                .fill(.white.opacity(0.30))
                .frame(width: 26, height: 1.5)
                .padding(.vertical, 6)
            Text(snap.fr)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private func mediumLayout(snap: WWidgetSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)
                Text(snap.en)
                    .font(WTheme.serif(36))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(snap.fr)
                    .font(WTheme.serif(22, .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 0)
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(18)
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
}

struct dailyVocabulary: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetConstants.dailyKind, provider: DailyProvider()) { entry in
            DailyWidgetView(entry: entry)
                .widgetURL(URL(string: "vocabulary://home"))
                .widgetClearBackground()
        }
        .configurationDisplayName("Mot du jour")
        .description("Un mot qui change chaque heure, selon ton niveau.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        .filledBlock()
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
        switch family {
        case .accessoryRectangular:
            AccessoryRectView(label: "Mot de \(hourLabel)", icon: "clock.fill",
                              en: entry.snapshot?.en, fr: entry.snapshot?.fr, level: entry.snapshot?.level)
        case .accessoryInline:
            AccessoryInlineView(prefix: "⏰", en: entry.snapshot?.en, fr: entry.snapshot?.fr)
        default:
            ZStack {
                WTheme.hourly
                if let snap = entry.snapshot {
                    if family == .systemSmall { smallLayout(snap: snap) }
                    else { mediumLayout(snap: snap) }
                } else {
                    emptyLayout
                }
            }
        }
    }

    private func smallLayout(snap: WHourlyWordSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill").font(.caption2).foregroundStyle(WTheme.clay)
                Text(hourLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text(snap.level)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.22))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 8)
            Text(snap.en)
                .font(WTheme.serif(26))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Rectangle()
                .fill(WTheme.clay.opacity(0.8))
                .frame(width: 26, height: 1.5)
                .padding(.vertical, 5)
            Text(snap.fr)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private func mediumLayout(snap: WHourlyWordSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)
                Label("Mot de \(hourLabel)", systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WTheme.clay)
                Text(snap.en)
                    .font(WTheme.serif(36))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(snap.fr)
                    .font(WTheme.serif(22, .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer()
            VStack {
                Text(snap.level)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(18)
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
                .widgetClearBackground()
        }
        .configurationDisplayName("Mot de l'heure")
        .description("Un nouveau mot anglais toutes les heures, selon ton niveau.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        .filledBlock()
    }
}

// Widget #Preview macros require iOS 17 — omitted so the extension can target
// iOS 16. Use the Xcode canvas with a real timeline entry to preview if needed.
