//
//  dailyVocabulary.swift
//  dailyVocabulary
//
//  Created by Sharik Mohamed on 20/04/2026.
//

import WidgetKit
import SwiftUI

private enum WidgetConstants {
    static let appGroupId = "group.com.vocabulary.shared"
    static let snapshotKey = "widgetSnapshotV1"
    static let kind = "dailyVocabulary"
}

enum DailyState: String, Codable {
    case pending
    case seen
    case learned
}

struct WidgetSnapshot: Codable, Hashable {
    let day: Date
    let wordId: Int
    let en: String
    let fr: String
    let level: String
    let state: DailyState
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), snapshot: WidgetSnapshot(day: Date(), wordId: 1, en: "hello", fr: "bonjour", level: "A1", state: .pending))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let now = Date()
        let entry = SimpleEntry(date: now, snapshot: loadSnapshot())
        let nextMidnight = Calendar.autoupdatingCurrent.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: now)!

        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func loadSnapshot() -> WidgetSnapshot? {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId) ?? .standard
        guard let data = defaults.data(forKey: WidgetConstants.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct dailyVocabularyEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let snapshot = entry.snapshot {
                HStack {
                    Text("Mot du jour")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(snapshot.level)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }

                Text(snapshot.en)
                    .font(.headline)
                    .lineLimit(2)

                Text(snapshot.fr)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Ouvre l’app")
                    .font(.headline)
                Text("Choisis ton niveau pour recevoir ton mot du jour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}

struct dailyVocabulary: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetConstants.kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                dailyVocabularyEntryView(entry: entry)
                    .widgetURL(URL(string: "vocabulary://home"))
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                dailyVocabularyEntryView(entry: entry)
                    .widgetURL(URL(string: "vocabulary://home"))
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Mot du jour")
        .description("Affiche ton mot du jour (anglais + français).")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    dailyVocabulary()
} timeline: {
    SimpleEntry(date: .now, snapshot: WidgetSnapshot(day: .now, wordId: 1, en: "hello", fr: "bonjour", level: "A1", state: .pending))
}
