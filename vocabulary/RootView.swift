import SwiftData
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ZStack {
            AppBackground()

            if let loadError = wordStore.loadError {
                ErrorStateView(message: loadError) {
                    wordStore.load()
                }
            } else if !settings.onboardingCompleted {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task {
            if settings.onboardingCompleted {
                DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, context: context)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard settings.onboardingCompleted else { return }
            DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, context: context)
        }
        .onChange(of: settings.selectedLevelRaw) { _, _ in
            guard settings.onboardingCompleted else { return }
            DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, context: context)
        }
    }
}

private struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var selectedLevel: CEFRLevel? = nil

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Bienvenue")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text("Choisis ton niveau pour recevoir 1 mot par jour.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ton niveau")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { level in
                            LevelButton(
                                title: level.title,
                                isSelected: selectedLevel == level
                            ) {
                                selectedLevel = level
                            }
                        }
                    }
                }
            }

            Button {
                guard let selectedLevel else { return }
                settings.selectedLevel = selectedLevel
                settings.onboardingCompleted = true
                DailyWordService.syncUpToToday(level: selectedLevel, wordStore: wordStore, settings: settings, context: context)
            } label: {
                Text("Commencer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedLevel == nil)

            Text("Tu pourras changer de niveau plus tard dans les réglages.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: 520)
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Accueil", systemImage: "sparkles") }

            HistoryView()
                .tabItem { Label("Historique", systemImage: "clock.arrow.circlepath") }

            ProgressScreen()
                .tabItem { Label("Progression", systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
    }
}

private struct HomeView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var isTranslationRevealed = false

    var body: some View {
        let today = Date().startOfDay
        let level = settings.selectedLevel
        let entry = fetchEntry(day: today, level: level)
        let word = entry.flatMap { wordStore.word(id: $0.wordId) }

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mot du jour")
                        .font(.largeTitle.bold())
                    Text(today, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Niveau \(level.title)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            if wordStore.totalCount(for: level) == 0 {
                EmptyCard(title: "Aucun mot", subtitle: "Le fichier JSON ne contient pas de mots pour \(level.title).")
            } else if word == nil || entry == nil {
                EmptyCard(title: "Préparation…", subtitle: "On prépare ton mot du jour.")
                    .onAppear {
                        DailyWordService.syncUpToToday(level: level, wordStore: wordStore, settings: settings, context: context)
                    }
            } else if let word, let entry {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Anglais")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(word.en)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.7)
                                .lineLimit(2)
                        }

                        Divider().opacity(0.4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Français")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if shouldShowTranslation(entry: entry) {
                                Text(word.fr)
                                    .font(.title3.weight(.semibold))
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else {
                                Text("— — —")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 10) {
                            if !shouldShowTranslation(entry: entry) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isTranslationRevealed = true
                                    }
                                    DailyWordService.markSeen(entry: entry, level: level, wordStore: wordStore, context: context)
                                } label: {
                                    Text("Voir la traduction")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button {
                                    DailyWordService.markLearned(entry: entry, level: level, wordStore: wordStore, context: context)
                                } label: {
                                    Text(entry.state == .learned ? "Appris" : "Je l’ai appris")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    DailyWordService.markReview(entry: entry, level: level, wordStore: wordStore, context: context)
                                } label: {
                                    Text("À revoir")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .onAppear {
                    if entry.state != .pending { isTranslationRevealed = true }
                }
                .onChange(of: entry.stateRaw) { _, _ in
                    if entry.state != .pending { isTranslationRevealed = true }
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func shouldShowTranslation(entry: DailyEntryModel) -> Bool {
        isTranslationRevealed || entry.state != .pending
    }

    private func fetchEntry(day: Date, level: CEFRLevel) -> DailyEntryModel? {
        let targetDay = day.startOfDay
        let descriptor = FetchDescriptor<DailyEntryModel>(
            predicate: #Predicate { $0.day == targetDay && $0.levelRaw == level.rawValue },
            fetchLimit: 1
        )
        return try? context.fetch(descriptor).first
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var wordStore: WordStore

    @Query(sort: \DailyEntryModel.day, order: .reverse) private var entries: [DailyEntryModel]

    @State private var searchText: String = ""

    var body: some View {
        let today = Date().startOfDay
        let filtered = entries.filter { entry in
            guard let word = wordStore.word(id: entry.wordId) else { return false }
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            let q = searchText.lowercased()
            return word.en.lowercased().contains(q) || word.fr.lowercased().contains(q)
        }

        let catchUp = filtered.filter { $0.day < today && $0.state == .pending }
        let rest = filtered.filter { !($0.day < today && $0.state == .pending) }

        NavigationStack {
            List {
                if !catchUp.isEmpty {
                    Section("À rattraper") {
                        ForEach(catchUp) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                }

                Section("Historique") {
                    if rest.isEmpty {
                        ContentUnavailableView("Pas encore d’historique", systemImage: "clock", description: Text("Reviens demain pour ton prochain mot."))
                    } else {
                        ForEach(rest) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("Historique")
            .searchable(text: $searchText, prompt: "Rechercher (EN ou FR)")
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }

    private struct HistoryRow: View {
        @Environment(\.modelContext) private var context
        @EnvironmentObject private var wordStore: WordStore
        @EnvironmentObject private var settings: SettingsStore

        let entry: DailyEntryModel

        var body: some View {
            if let word = wordStore.word(id: entry.wordId) {
                NavigationLink {
                    WordDetailView(entry: entry, word: word)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.day, format: .dateTime.day().month().year())
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            LevelBadge(levelRaw: entry.levelRaw)
                        }

                        Text(word.en)
                            .font(.headline)
                        Text(word.fr)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            StateBadge(state: entry.state)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 6)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        DailyWordService.markLearned(entry: entry, level: entry.level, wordStore: wordStore, context: context)
                    } label: {
                        Label("Appris", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            } else {
                Text("Mot introuvable")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WordDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    let entry: DailyEntryModel
    let word: Word

    var body: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(entry.day, format: .dateTime.weekday(.wide).day().month(.wide).year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        LevelBadge(levelRaw: entry.levelRaw)
                    }

                    Text(word.en)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(word.fr)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)

                    StateBadge(state: entry.state)
                        .padding(.top, 4)
                }
            }

            HStack(spacing: 10) {
                Button {
                    DailyWordService.markLearned(entry: entry, level: entry.level, wordStore: wordStore, context: context)
                } label: {
                    Text("Marquer appris")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    DailyWordService.markReview(entry: entry, level: entry.level, wordStore: wordStore, context: context)
                } label: {
                    Text("À revoir")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(20)
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProgressScreen: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        let global = ProgressService.stats(wordStore: wordStore, context: context)
        let byLevel = CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }).map { level in
            (level, ProgressService.stats(level: level, wordStore: wordStore, context: context))
        }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Global")
                                .font(.headline)

                            ProgressRow(title: "Appris", value: global.learned, total: global.total, tint: .green)
                            ProgressRow(title: "Vus", value: global.seen, total: global.total, tint: .orange)
                            ProgressRow(title: "Restants", value: global.remaining, total: global.total, tint: .blue)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Par niveau")
                                .font(.headline)

                            ForEach(byLevel, id: \.0) { level, stats in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(level.title)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("\(stats.learned) / \(stats.total)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    SwiftUI.ProgressView(value: Double(stats.learned), total: Double(max(stats.total, 1)))
                                        .tint(.green)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Progression")
        }
    }

    private struct ProgressRow: View {
        let title: String
        let value: Int
        let total: Int
        let tint: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(value) / \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SwiftUI.ProgressView(value: Double(value), total: Double(max(total, 1)))
                    .tint(tint)
            }
        }
    }
}

private struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var notificationStatus: UNAuthorizationStatus? = nil
    @State private var showingResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Niveau") {
                    Picker("Niveau actuel", selection: $settings.selectedLevelRaw) {
                        ForEach(CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { level in
                            Text(level.title).tag(level.rawValue)
                        }
                    }
                    Text("Le mot déjà attribué aujourd’hui ne change pas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Notifications") {
                    HStack {
                        Text("Statut")
                        Spacer()
                        Text(statusLabel(notificationStatus))
                            .foregroundStyle(.secondary)
                    }

                    DatePicker("Heure du rappel", selection: settings.notificationDateBinding, displayedComponents: .hourAndMinute)

                    Button("Activer / Mettre à jour") {
                        Task {
                            let ok = await NotificationScheduler.requestAuthorization()
                            if ok {
                                await NotificationScheduler.scheduleDailyReminder(hour: settings.notificationHour, minute: settings.notificationMinute)
                            }
                            notificationStatus = await NotificationScheduler.currentStatus()
                        }
                    }

                    if notificationStatus == .denied {
                        Button("Ouvrir les réglages iOS") {
                            openSystemSettings()
                        }
                    }
                }

                Section("Données") {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Text("Réinitialiser la progression")
                    }
                }
            }
            .navigationTitle("Réglages")
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .task {
            notificationStatus = await NotificationScheduler.currentStatus()
        }
        .onChange(of: settings.notificationHour) { _, _ in
            Task {
                let status = await NotificationScheduler.currentStatus()
                notificationStatus = status
                guard status == .authorized || status == .provisional else { return }
                await NotificationScheduler.scheduleDailyReminder(hour: settings.notificationHour, minute: settings.notificationMinute)
            }
        }
        .onChange(of: settings.notificationMinute) { _, _ in
            Task {
                let status = await NotificationScheduler.currentStatus()
                notificationStatus = status
                guard status == .authorized || status == .provisional else { return }
                await NotificationScheduler.scheduleDailyReminder(hour: settings.notificationHour, minute: settings.notificationMinute)
            }
        }
        .confirmationDialog("Réinitialiser ?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) {
                DailyWordService.resetProgress(settings: settings, context: context)
                DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, context: context)
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ton historique et ta progression seront supprimés.")
        }
    }

    private func statusLabel(_ status: UNAuthorizationStatus?) -> String {
        switch status {
        case .authorized: "Activées"
        case .provisional: "Provisoires"
        case .denied: "Désactivées"
        case .notDetermined: "Non demandé"
        case .ephemeral: "Éphémères"
        case nil: "—"
        @unknown default: "—"
        }
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.93, blue: 0.88),
                Color(red: 0.93, green: 0.92, blue: 0.90),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}

private struct LevelButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.black.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.primary.opacity(0.25) : Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Erreur")
                .font(.title2.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Réessayer", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: 520)
    }
}

private struct LevelBadge: View {
    let levelRaw: String
    var body: some View {
        Text(levelRaw)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct StateBadge: View {
    let state: DailyState

    var body: some View {
        let text: String
        let color: Color
        switch state {
        case .pending:
            text = "Non consulté"
            color = .blue
        case .seen:
            text = "Vu"
            color = .orange
        case .learned:
            text = "Appris"
            color = .green
        }

        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}
