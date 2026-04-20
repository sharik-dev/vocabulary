import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @AppStorage(AppConstants.DefaultsKey.onboardingCompleted) var onboardingCompleted: Bool = false

    @AppStorage(AppConstants.DefaultsKey.selectedLevel) var selectedLevelRaw: String = CEFRLevel.a1.rawValue
    var selectedLevel: CEFRLevel {
        get { CEFRLevel(rawValue: selectedLevelRaw) ?? .a1 }
        set { selectedLevelRaw = newValue.rawValue }
    }

    @AppStorage(AppConstants.DefaultsKey.notificationHour) var notificationHour: Int = 9
    @AppStorage(AppConstants.DefaultsKey.notificationMinute) var notificationMinute: Int = 0

    @AppStorage(AppConstants.DefaultsKey.shuffleSeed) private var shuffleSeedRaw: String = ""
    var shuffleSeed: UInt64 {
        get {
            if let value = UInt64(shuffleSeedRaw) { return value }
            let new = UInt64.random(in: UInt64.min...UInt64.max)
            shuffleSeedRaw = String(new)
            return new
        }
        set { shuffleSeedRaw = String(newValue) }
    }

    @AppStorage(AppConstants.DefaultsKey.nextIndexA1) private var nextIndexA1: Int = 0
    @AppStorage(AppConstants.DefaultsKey.nextIndexA2) private var nextIndexA2: Int = 0
    @AppStorage(AppConstants.DefaultsKey.nextIndexB1) private var nextIndexB1: Int = 0
    @AppStorage(AppConstants.DefaultsKey.nextIndexB2) private var nextIndexB2: Int = 0

    func nextIndex(for level: CEFRLevel) -> Int {
        switch level {
        case .a1: nextIndexA1
        case .a2: nextIndexA2
        case .b1: nextIndexB1
        case .b2: nextIndexB2
        }
    }

    func setNextIndex(_ value: Int, for level: CEFRLevel) {
        switch level {
        case .a1: nextIndexA1 = value
        case .a2: nextIndexA2 = value
        case .b1: nextIndexB1 = value
        case .b2: nextIndexB2 = value
        }
    }

    func resetProgressPointers() {
        nextIndexA1 = 0
        nextIndexA2 = 0
        nextIndexB1 = 0
        nextIndexB2 = 0
        shuffleSeed = UInt64.random(in: UInt64.min...UInt64.max)
    }

    var notificationDateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = notificationHour
                components.minute = notificationMinute
                return Calendar.autoupdatingCurrent.date(from: components) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: newValue)
                notificationHour = comps.hour ?? 9
                notificationMinute = comps.minute ?? 0
            }
        )
    }
}
