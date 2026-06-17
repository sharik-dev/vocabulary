import SwiftData
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design tokens

private enum DS {
    static let bg        = Color(red: 0.97, green: 0.96, blue: 0.94)   // warm cream
    static let surface   = Color.white
    static let accent    = Color(red: 0.58, green: 0.47, blue: 0.35)   // warm caramel
    static let border    = Color(red: 0.90, green: 0.88, blue: 0.84)   // barely-there
    static let textMuted = Color(red: 0.60, green: 0.58, blue: 0.55)
    static let success   = Color(red: 0.25, green: 0.55, blue: 0.35)
    static let radius: CGFloat = 20
}

// MARK: - Root

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            if let err = wordStore.loadError {
                ErrorStateView(message: err) { wordStore.load() }
            } else if !settings.onboardingCompleted {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: settings.onboardingCompleted)
        .task {
            guard settings.onboardingCompleted else { return }
            sync()
        }
        .onChange(of: scenePhase) { _, p in
            guard p == .active, settings.onboardingCompleted else { return }
            sync()
        }
        .onChange(of: settings.selectedLevelRaw) { _, _ in
            guard settings.onboardingCompleted else { return }
            sync()
        }
    }

    private func sync() {
        DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, context: context)
        DailyWordService.updateHourlyWords(level: settings.selectedLevel, wordStore: wordStore)
    }
}

// MARK: - Onboarding

private struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var page = 0
    @State private var selected: CEFRLevel? = nil

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if page == 0 { welcomePage } else { levelPage }
            }
            .animation(.spring(duration: 0.4), value: page)
        }
    }

    // ── Page 1 ────────────────────────────────────────────────────────────────

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Logo mark
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(DS.surface)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
                    Text("Aa")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(DS.accent)
                }

                VStack(spacing: 12) {
                    Text("Vocabulary")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Un mot anglais par jour,\nadapté à ton niveau.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DS.textMuted)
                        .lineSpacing(4)
                }
            }

            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    OnboardingFeatureRow(icon: "sun.horizon", text: "Un mot chaque matin selon ton niveau")
                    Divider().padding(.horizontal, 4)
                    OnboardingFeatureRow(icon: "clock", text: "Widget horaire : un nouveau mot par heure")
                    Divider().padding(.horizontal, 4)
                    OnboardingFeatureRow(icon: "chart.bar", text: "Suivi de progression détaillé")
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
                        .stroke(DS.border, lineWidth: 1)
                )

                PrimaryButton(label: "Commencer") {
                    withAnimation { page = 1 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }

    // ── Page 2 ────────────────────────────────────────────────────────────────

    private var levelPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("Ton niveau")
                    .font(.system(size: 32, weight: .bold))
                Text("On adapte le vocabulaire pour toi.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textMuted)
            }
            .padding(.bottom, 32)

            VStack(spacing: 10) {
                ForEach(CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { level in
                    LevelPickerRow(level: level, isSelected: selected == level) {
                        withAnimation(.spring(duration: 0.2)) { selected = level }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(DS.border).frame(width: 6, height: 6)
                    Circle().fill(DS.accent).frame(width: 6, height: 6)
                }

                PrimaryButton(label: "C'est parti", disabled: selected == nil) {
                    guard let selected else { return }
                    settings.selectedLevel = selected
                    settings.onboardingCompleted = true
                    DailyWordService.syncUpToToday(level: selected, wordStore: wordStore, settings: settings, context: context)
                    DailyWordService.updateHourlyWords(level: selected, wordStore: wordStore)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(DS.accent)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct LevelPickerRow: View {
    let level: CEFRLevel
    let isSelected: Bool
    let action: () -> Void

    private var info: (label: String, desc: String) {
        switch level {
        case .a1: ("A1  ·  Débutant",     "Les bases : saluer, compter, nommer")
        case .a2: ("A2  ·  Élémentaire",  "Vie quotidienne, voyages, famille")
        case .b1: ("B1  ·  Intermédiaire","Discussions, actualités, opinions")
        case .b2: ("B2  ·  Avancé",       "Vocabulaire riche et nuancé")
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.label)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(info.desc)
                        .font(.caption)
                        .foregroundStyle(DS.textMuted)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? DS.accent : DS.border, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(DS.accent).frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(isSelected ? DS.accent.opacity(0.06) : DS.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? DS.accent.opacity(0.4) : DS.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main Tab

private struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Accueil",     systemImage: "house") }
            HistoryView()
                .tabItem { Label("Historique",  systemImage: "clock") }
            ProgressScreen()
                .tabItem { Label("Progression", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Réglages",    systemImage: "gearshape") }
        }
        .tint(DS.accent)
    }
}

// MARK: - Home

private struct HomeView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var revealed = false

    var body: some View {
        let today = Date().startOfDay
        let level = settings.selectedLevel
        let entry = fetchEntry(day: today, level: level)
        let word  = entry.flatMap { wordStore.word(id: $0.wordId) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Date + level
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(today, format: .dateTime.weekday(.wide))
                                .font(.caption.weight(.semibold))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundStyle(DS.textMuted)
                            Text(today, format: .dateTime.day().month(.wide))
                                .font(.title2.weight(.bold))
                        }
                        Spacer()
                        Chip(label: level.rawValue)
                    }

                    // Word card
                    if let word, let entry {
                        WordCard(word: word, entry: entry, level: level,
                                 revealed: revealed || entry.state != .pending,
                                 onReveal: {
                                     withAnimation(.spring(duration: 0.3)) { revealed = true }
                                     DailyWordService.markSeen(entry: entry, level: level, wordStore: wordStore, context: context)
                                 },
                                 onLearned: {
                                     DailyWordService.markLearned(entry: entry, level: level, wordStore: wordStore, context: context)
                                 },
                                 onReview: {
                                     DailyWordService.markReview(entry: entry, level: level, wordStore: wordStore, context: context)
                                 })
                        .onAppear { if entry.state != .pending { revealed = true } }
                        .onChange(of: entry.stateRaw) { _, _ in if entry.state != .pending { revealed = true } }
                    } else if wordStore.totalCount(for: level) == 0 {
                        InfoCard(title: "Aucun mot", subtitle: "Aucun mot pour le niveau \(level.rawValue).")
                    } else {
                        InfoCard(title: "Chargement…", subtitle: "Préparation de ton mot du jour.")
                            .onAppear {
                                DailyWordService.syncUpToToday(level: level, wordStore: wordStore, settings: settings, context: context)
                            }
                    }
                }
                .padding(24)
            }
            .navigationBarHidden(true)
            .background(DS.bg)
            .scrollContentBackground(.hidden)
        }
    }

    private func fetchEntry(day: Date, level: CEFRLevel) -> DailyEntryModel? {
        let d   = day.startOfDay
        let lv  = level.rawValue
        var desc = FetchDescriptor<DailyEntryModel>(
            predicate: #Predicate { $0.day == d && $0.levelRaw == lv },
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        desc.fetchLimit = 1
        return try? context.fetch(desc).first
    }
}

private struct WordCard: View {
    let word: Word
    let entry: DailyEntryModel
    let level: CEFRLevel
    let revealed: Bool
    let onReveal: () -> Void
    let onLearned: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            VStack(alignment: .leading, spacing: 20) {
                // EN
                VStack(alignment: .leading, spacing: 6) {
                    Label("anglais", systemImage: "")
                        .labelStyle(.titleOnly)
                        .font(.caption.weight(.medium))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.textMuted)

                    Text(word.en)
                        .font(.system(size: 44, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                }

                Divider().overlay(DS.border)

                // FR
                VStack(alignment: .leading, spacing: 6) {
                    Text("français")
                        .font(.caption.weight(.medium))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.textMuted)

                    if revealed {
                        Text(word.fr)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.primary)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Text("· · · · ·")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(DS.border)
                    }
                }
            }
            .padding(24)

            // State footer
            if entry.state != .pending {
                Divider().overlay(DS.border)
                HStack {
                    StateTag(state: entry.state)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.radius, style: .continuous).stroke(DS.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)

        // Actions
        VStack(spacing: 10) {
            if revealed {
                HStack(spacing: 10) {
                    GhostButton(label: "À revoir", action: onReview)
                    PrimaryButton(
                        label: entry.state == .learned ? "Appris ✓" : "Je l'ai appris",
                        tint: entry.state == .learned ? DS.success : .primary,
                        action: onLearned
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                PrimaryButton(label: "Voir la traduction", action: onReveal)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.3), value: revealed)
    }
}

// MARK: - History

private struct HistoryView: View {
    @EnvironmentObject private var wordStore: WordStore
    @Query(sort: \DailyEntryModel.day, order: .reverse) private var entries: [DailyEntryModel]
    @State private var searchText = ""

    var body: some View {
        let filtered = entries.filter { entry in
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let word = wordStore.word(id: entry.wordId) else { return false }
            return q.isEmpty || word.en.lowercased().contains(q) || word.fr.lowercased().contains(q)
        }
        let today   = Date().startOfDay
        let catchUp = filtered.filter { $0.day < today && $0.state == .pending }
        let rest    = filtered.filter { !($0.day < today && $0.state == .pending) }

        NavigationStack {
            List {
                if !catchUp.isEmpty {
                    Section {
                        ForEach(catchUp) { HistoryRow(entry: $0) }
                    } header: {
                        SectionHeader(title: "À rattraper  ·  \(catchUp.count)")
                    }
                }
                Section {
                    if rest.isEmpty {
                        ContentUnavailableView("Aucun historique", systemImage: "clock")
                    } else {
                        ForEach(rest) { HistoryRow(entry: $0) }
                    }
                } header: {
                    SectionHeader(title: "Historique")
                }
            }
            .listStyle(.plain)
            .background(DS.bg)
            .scrollContentBackground(.hidden)
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Anglais ou français…")
        }
    }

    private struct HistoryRow: View {
        @Environment(\.modelContext) private var context
        @EnvironmentObject private var wordStore: WordStore
        @EnvironmentObject private var settings: SettingsStore
        let entry: DailyEntryModel

        var body: some View {
            if let word = wordStore.word(id: entry.wordId) {
                NavigationLink { WordDetailView(entry: entry, word: word) } label: {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(stateColor)
                            .frame(width: 3, height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(word.en)
                                .font(.callout.weight(.semibold))
                            Text(word.fr)
                                .font(.subheadline)
                                .foregroundStyle(DS.textMuted)
                        }

                        Spacer()

                        Text(entry.day, format: .dateTime.day().month())
                            .font(.caption)
                            .foregroundStyle(DS.textMuted)
                    }
                    .padding(.vertical, 6)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        DailyWordService.markLearned(entry: entry, level: entry.level, wordStore: wordStore, context: context)
                    } label: { Label("Appris", systemImage: "checkmark") }
                    .tint(DS.success)
                }
            }
        }

        private var stateColor: Color {
            switch entry.state {
            case .learned: DS.success
            case .seen:    DS.accent
            case .pending: DS.border
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Card
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(entry.day, format: .dateTime.weekday(.wide).day().month().year())
                            .font(.caption)
                            .foregroundStyle(DS.textMuted)
                        Spacer()
                        Chip(label: entry.levelRaw)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(word.en)
                            .font(.system(size: 38, weight: .bold))
                        Text(word.fr)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(DS.textMuted)
                    }

                    StateTag(state: entry.state)
                }
                .padding(24)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.radius, style: .continuous).stroke(DS.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)

                // Actions
                HStack(spacing: 10) {
                    GhostButton(label: "À revoir") {
                        DailyWordService.markReview(entry: entry, level: entry.level, wordStore: wordStore, context: context)
                    }
                    PrimaryButton(label: "Appris") {
                        DailyWordService.markLearned(entry: entry, level: entry.level, wordStore: wordStore, context: context)
                    }
                }
            }
            .padding(24)
        }
        .background(DS.bg)
        .scrollContentBackground(.hidden)
        .navigationTitle(word.en)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Progress

private struct ProgressScreen: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        let g = ProgressService.stats(wordStore: wordStore, context: context)
        let pct = g.total > 0 ? Double(g.learned) / Double(g.total) : 0
        let levels = CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { ($0, ProgressService.stats(level: $0, wordStore: wordStore, context: context)) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Global ring-ish + stats
                    Surface {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(Int(pct * 100))%")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                    Text("des mots appris")
                                        .font(.subheadline)
                                        .foregroundStyle(DS.textMuted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 10) {
                                    StatLine(value: g.learned, label: "appris",   color: DS.success)
                                    StatLine(value: g.seen,    label: "vus",      color: DS.accent)
                                    StatLine(value: g.remaining, label: "restants", color: DS.textMuted)
                                }
                            }

                            ProgressBar(value: pct, tint: DS.accent)
                        }
                    }

                    // Per level
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Par niveau")
                                .font(.callout.weight(.semibold))
                                .tracking(0.5)
                                .foregroundStyle(DS.textMuted)

                            ForEach(levels, id: \.0) { level, stats in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(level.rawValue)
                                            .font(.callout.weight(.semibold))
                                        Text(levelName(level))
                                            .font(.caption)
                                            .foregroundStyle(DS.textMuted)
                                        Spacer()
                                        Text("\(stats.learned) / \(stats.total)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(DS.textMuted)
                                    }
                                    ProgressBar(
                                        value: stats.total > 0 ? Double(stats.learned) / Double(stats.total) : 0,
                                        tint: DS.accent
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Progression")
            .background(DS.bg)
            .scrollContentBackground(.hidden)
        }
    }

    private func levelName(_ l: CEFRLevel) -> String {
        switch l { case .a1: "Débutant"; case .a2: "Élémentaire"; case .b1: "Intermédiaire"; case .b2: "Avancé" }
    }

    private struct StatLine: View {
        let value: Int; let label: String; let color: Color
        var body: some View {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text("\(value)").font(.callout.weight(.semibold).monospacedDigit())
                Text(label).font(.caption).foregroundStyle(DS.textMuted)
            }
        }
    }
}

// MARK: - Settings

private struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var notifStatus: UNAuthorizationStatus? = nil
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            List {
                // Level
                Section {
                    ForEach(CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { level in
                        Button {
                            settings.selectedLevel = level
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(levelLabel(level))
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(levelDesc(level))
                                        .font(.caption)
                                        .foregroundStyle(DS.textMuted)
                                }
                                Spacer()
                                if settings.selectedLevel == level {
                                    Image(systemName: "checkmark")
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(DS.accent)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: { SectionHeader(title: "Niveau") }
                  footer: { Text("Le mot du jour actuel ne change pas.").font(.caption) }

                // Notifications
                Section {
                    HStack {
                        Text("Statut")
                        Spacer()
                        Text(notifLabel).foregroundStyle(DS.textMuted)
                    }
                    DatePicker("Rappel", selection: settings.notificationDateBinding, displayedComponents: .hourAndMinute)
                    Button("Activer / mettre à jour") {
                        Task {
                            let ok = await NotificationScheduler.requestAuthorization()
                            if ok {
                                await NotificationScheduler.scheduleDailyReminder(hour: settings.notificationHour, minute: settings.notificationMinute)
                            }
                            notifStatus = await NotificationScheduler.currentStatus()
                        }
                    }
                    .foregroundStyle(DS.accent)
                    if notifStatus == .denied {
                        Button("Ouvrir les réglages iOS") { openSettings() }
                            .foregroundStyle(.red)
                    }
                } header: { SectionHeader(title: "Notifications") }

                // Danger
                Section {
                    Button(role: .destructive) { showReset = true } label: {
                        Label("Réinitialiser la progression", systemImage: "trash")
                    }
                } header: { SectionHeader(title: "Données") }
            }
            .listStyle(.insetGrouped)
            .background(DS.bg)
            .scrollContentBackground(.hidden)
            .navigationTitle("Réglages")
        }
        .task { notifStatus = await NotificationScheduler.currentStatus() }
        .onChange(of: settings.notificationHour)   { _, _ in reschedule() }
        .onChange(of: settings.notificationMinute) { _, _ in reschedule() }
        .confirmationDialog("Réinitialiser ?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) {
                DailyWordService.resetProgress(settings: settings, context: context)
                DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, context: context)
                DailyWordService.updateHourlyWords(level: settings.selectedLevel, wordStore: wordStore)
            }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Historique et progression supprimés définitivement.") }
    }

    private var notifLabel: String {
        switch notifStatus {
        case .authorized: "Activées"
        case .denied:     "Désactivées"
        case .notDetermined: "Non demandé"
        default: "—"
        }
    }

    private func reschedule() {
        Task {
            let s = await NotificationScheduler.currentStatus()
            notifStatus = s
            guard s == .authorized || s == .provisional else { return }
            await NotificationScheduler.scheduleDailyReminder(hour: settings.notificationHour, minute: settings.notificationMinute)
        }
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func levelLabel(_ l: CEFRLevel) -> String {
        switch l { case .a1: "A1 · Débutant"; case .a2: "A2 · Élémentaire"; case .b1: "B1 · Intermédiaire"; case .b2: "B2 · Avancé" }
    }
    private func levelDesc(_ l: CEFRLevel) -> String {
        switch l { case .a1: "Les bases"; case .a2: "Vie quotidienne"; case .b1: "Discussions"; case .b2: "Vocabulaire avancé" }
    }
}

// MARK: - Shared components

private struct PrimaryButton: View {
    let label: String
    var tint: Color = .primary
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? DS.border : tint)
                .foregroundStyle(disabled ? DS.textMuted : .white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(disabled)
    }
}

private struct GhostButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DS.surface)
                .foregroundStyle(.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct Chip: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(DS.surface)
            .foregroundStyle(DS.textMuted)
            .overlay(Capsule().stroke(DS.border, lineWidth: 1))
            .clipShape(Capsule())
    }
}

private struct StateTag: View {
    let state: DailyState
    var body: some View {
        let (label, color): (String, Color) = {
            switch state {
            case .learned: ("Appris", DS.success)
            case .seen:    ("Vu",     DS.accent)
            case .pending: ("Nouveau", DS.textMuted)
            }
        }()
        Text(label)
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct Surface<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(20)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.radius, style: .continuous).stroke(DS.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

private struct ProgressBar: View {
    let value: Double   // 0…1
    let tint: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DS.border)
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint)
                    .frame(width: g.size.width * CGFloat(max(0, min(1, value))), height: 6)
                    .animation(.spring(duration: 0.5), value: value)
            }
        }
        .frame(height: 6)
    }
}

private struct InfoCard: View {
    let title: String
    let subtitle: String
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.callout.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(DS.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(DS.textMuted)
    }
}

private struct ErrorStateView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(DS.accent)
            Text("Erreur").font(.title2.bold())
            Text(message).font(.subheadline).foregroundStyle(DS.textMuted).multilineTextAlignment(.center)
            PrimaryButton(label: "Réessayer", action: retry)
                .frame(maxWidth: 200)
        }
        .padding(32)
    }
}
