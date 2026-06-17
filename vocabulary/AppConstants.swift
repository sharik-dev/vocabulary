import Foundation

enum AppConstants {
    // IMPORTANT: Must match the App Group declared in BOTH targets' entitlements
    // (vocabulary.entitlements & dailyVocabularyExtension.entitlements).
    static let appGroupId = "group.vocabularyBySharik"

    enum DefaultsKey {
        static let onboardingCompleted = "onboardingCompleted"
        static let selectedLevel = "selectedLevel"
        static let notificationHour = "notificationHour"
        static let notificationMinute = "notificationMinute"
        static let shuffleSeed = "shuffleSeed"
        static let nextIndexA1 = "nextIndexA1"
        static let nextIndexA2 = "nextIndexA2"
        static let nextIndexB1 = "nextIndexB1"
        static let nextIndexB2 = "nextIndexB2"
    }

    enum WidgetKey {
        static let snapshot = "widgetSnapshotV1"
        static let hourlyWords = "hourlyWordsV1"
    }

    enum NotificationId {
        static let dailyReminder = "daily_reminder"
    }
}

