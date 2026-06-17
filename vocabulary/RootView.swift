import SwiftUI
import UserNotifications
import WidgetKit

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design system
//
// Editorial / cahier aesthetic — one cohesive warm palette.
// Type pairing : New York (serif) for words & numbers, SF Pro for UI chrome.
// Both system fonts → crisp, free, Dynamic-Type friendly, no bundled .ttf.

enum DS {
    static let bg        = Color(red: 0.957, green: 0.937, blue: 0.906) // #F4EFE7 paper
    static let surface   = Color(red: 1.000, green: 0.992, blue: 0.980) // #FFFDFA warm white
    static let ink       = Color(red: 0.133, green: 0.122, blue: 0.106) // #221F1B near-black
    static let accent    = Color(red: 0.722, green: 0.361, blue: 0.220) // #B85C38 clay
    static let accentDeep = Color(red: 0.541, green: 0.247, blue: 0.133) // #8A3F22
    static let espresso  = Color(red: 0.231, green: 0.196, blue: 0.165) // #3B322A
    static let sage      = Color(red: 0.373, green: 0.478, blue: 0.322) // #5F7A52 learned
    static let muted     = Color(red: 0.549, green: 0.522, blue: 0.471) // #8C8578
    static let border    = Color(red: 0.906, green: 0.878, blue: 0.831) // #E7E0D4
    static let ruleLine  = Color(red: 0.55,  green: 0.66,  blue: 0.80)  // faint notebook blue
    static let tape      = Color(red: 0.95,  green: 0.80,  blue: 0.45)  // washi yellow
    static let radius: CGFloat = 22

    /// Fixed-size serif — for compact, layout-constrained spots (widget tiles…).
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Dynamic-Type serif — scales with the user's text-size setting (accessibility).
    static func serif(_ style: Font.TextStyle, _ weight: Font.Weight = .bold) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

// MARK: - Decorations (cahier / student-2000s vibe)

struct NotebookBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                DS.bg
                Path { p in
                    let spacing: CGFloat = 34
                    var y = spacing
                    while y < geo.size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += spacing
                    }
                }
                .stroke(DS.ruleLine.opacity(0.22), lineWidth: 1)
                Path { p in
                    p.move(to: CGPoint(x: 30, y: 0))
                    p.addLine(to: CGPoint(x: 30, y: geo.size.height))
                }
                .stroke(DS.accent.opacity(0.30), lineWidth: 1.5)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct Sticker: View {
    let emoji: String
    var rotation: Double = 0
    var size: CGFloat = 30
    init(_ emoji: String, rotation: Double = 0, size: CGFloat = 30) {
        self.emoji = emoji; self.rotation = rotation; self.size = size
    }
    var body: some View {
        Text(emoji)
            .font(.system(size: size))
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.18), radius: 2, x: 1, y: 2)
            .accessibilityHidden(true)
    }
}

struct WashiTape: View {
    var tint: Color = DS.tape
    var body: some View {
        Rectangle()
            .fill(tint.opacity(0.55))
            .frame(width: 116, height: 26)
            .overlay(
                GeometryReader { g in
                    Path { p in
                        var x: CGFloat = -20
                        while x < g.size.width {
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x + 14, y: g.size.height))
                            x += 12
                        }
                    }
                    .stroke(.white.opacity(0.35), lineWidth: 4)
                }
            )
            .rotationEffect(.degrees(-3))
            .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}

// MARK: - Root

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: EntryStore

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            if let err = wordStore.loadError {
                ErrorStateView(message: err) { wordStore.load() }
            } else if !settings.onboardingCompleted {
                OnboardingView().transition(.opacity)
            } else {
                MainTabView().transition(.opacity)
            }
        }
        .tint(DS.accent)
        // Support large text sizes (accessibility) while protecting the layout.
        .dynamicTypeSize(.xSmall ... .accessibility2)
        .animation(.easeInOut(duration: 0.3), value: settings.onboardingCompleted)
        .onAppear { UITestSupport.seedIfNeeded(wordStore: wordStore, settings: settings, store: store) }
        .task {
            guard settings.onboardingCompleted else { return }
            sync()
        }
        .onChange(of: scenePhase) { p in
            guard p == .active, settings.onboardingCompleted else { return }
            sync()
        }
        .onChange(of: settings.selectedLevelRaw) { _ in
            guard settings.onboardingCompleted else { return }
            sync()
        }
    }

    private func sync() {
        DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, store: store)
        DailyWordService.updateHourlyWords(level: settings.selectedLevel, wordStore: wordStore)
    }
}

// MARK: - Onboarding (3 pages, cahier style, teaches the widget)

private struct OnboardingView: View {
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: EntryStore

    @State private var page = UITestSupport.onboardingStartPage
    @State private var selected: CEFRLevel? = UITestSupport.isActive ? .b1 : nil

    var body: some View {
        ZStack {
            NotebookBackground()
            Group {
                switch page {
                case 0: welcomePage
                case 1: levelPage
                default: widgetPage
                }
            }
            .animation(.spring(duration: 0.4), value: page)
        }
    }

    // ── Page 1 : Welcome ──────────────────────────────────────────────
    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 26) {
                ZStack(alignment: .topTrailing) {
                    LogoMark(size: 84)
                    Sticker("⭐️", rotation: 16, size: 30).offset(x: 14, y: -12)
                }
                VStack(spacing: 12) {
                    Text("Vocabulaire")
                        .font(DS.serif(.largeTitle))
                        .foregroundStyle(DS.ink)
                    Text("Un mot anglais par jour,\ndirectement sur ton écran d'accueil.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DS.muted)
                        .lineSpacing(4)
                }
            }
            Spacer()
            VStack(spacing: 0) {
                OnboardingFeatureRow(icon: "rectangle.stack.fill", text: "Des widgets élégants, le cœur de l'app")
                Divider().padding(.horizontal, 4)
                OnboardingFeatureRow(icon: "rectangle.portrait.on.rectangle.portrait.slash", text: "Swipe pour découvrir d'autres mots")
                Divider().padding(.horizontal, 4)
                OnboardingFeatureRow(icon: "chart.bar.fill", text: "Ta progression, simplement")
            }
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.radius, style: .continuous).stroke(DS.border, lineWidth: 1))
            .padding(.horizontal, 24)

            footer(primary: "Commencer", primaryEnabled: true) { withAnimation { page = 1 } }
        }
        .transition(pageTransition)
    }

    // ── Page 2 : Level (= adequate words) ─────────────────────────────
    private var levelPage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Ton niveau").font(DS.serif(.title)).foregroundStyle(DS.ink)
                    Sticker("📚", rotation: -8, size: 24)
                }
                Text("On choisit des mots adaptés à toi —\ntu pourras changer à tout moment.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DS.muted)
            }
            .padding(.bottom, 26)

            VStack(spacing: 10) {
                ForEach(CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { level in
                    LevelPickerRow(level: level, isSelected: selected == level) {
                        withAnimation(.spring(duration: 0.2)) { selected = level }
                    }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
            footer(primary: "Continuer", primaryEnabled: selected != nil, back: { withAnimation { page = 0 } }) {
                withAnimation { page = 2 }
            }
        }
        .transition(pageTransition)
    }

    // ── Page 3 : Widget how-to ────────────────────────────────────────
    private var widgetPage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Ajoute le widget").font(DS.serif(.title)).foregroundStyle(DS.ink)
                    Sticker("📌", rotation: 8, size: 22)
                }
                Text("C'est là que la magie opère.")
                    .font(.subheadline).foregroundStyle(DS.muted)
            }
            .padding(.bottom, 22)

            HStack(spacing: 14) {
                WidgetPreviewTile(style: .daily, en: "serene", fr: "serein", level: (selected ?? .a1).rawValue)
                WidgetPreviewTile(style: .hourly, en: "vivid", fr: "éclatant", level: (selected ?? .a1).rawValue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)

            VStack(spacing: 0) {
                HowToStep(num: "1", text: "Reste appuyé sur l'écran d'accueil")
                Divider().padding(.horizontal, 4)
                HowToStep(num: "2", text: "Touche **+** en haut à gauche")
                Divider().padding(.horizontal, 4)
                HowToStep(num: "3", text: "Cherche **Vocabulaire** et ajoute-le")
            }
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.radius, style: .continuous).stroke(DS.border, lineWidth: 1))
            .padding(.horizontal, 24)

            Spacer()
            footer(primary: "C'est parti", primaryEnabled: true, back: { withAnimation { page = 1 } }) {
                guard let selected else { return }
                settings.selectedLevel = selected
                settings.onboardingCompleted = true
                DailyWordService.syncUpToToday(level: selected, wordStore: wordStore, settings: settings, store: store)
                DailyWordService.updateHourlyWords(level: selected, wordStore: wordStore)
            }
        }
        .transition(pageTransition)
    }

    private var pageTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity))
    }

    @ViewBuilder
    private func footer(primary: String, primaryEnabled: Bool, back: (() -> Void)? = nil, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            PageDots(count: 3, index: page)
            HStack(spacing: 10) {
                if let back {
                    GhostButton(label: "Retour", action: back).frame(width: 120)
                }
                PrimaryButton(label: primary, disabled: !primaryEnabled, action: action)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 48)
    }
}

private struct LogoMark: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(DS.ink)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
            Text("Aa")
                .font(DS.serif(size * 0.36, .semibold))
                .foregroundStyle(DS.bg)
        }
        .accessibilityHidden(true)
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.callout).foregroundStyle(DS.accent).frame(width: 22)
            Text(text).font(.subheadline).foregroundStyle(DS.ink)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }
}

private struct HowToStep: View {
    let num: String
    let text: LocalizedStringKey
    var body: some View {
        HStack(spacing: 14) {
            Text(num)
                .font(.callout.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(DS.accent, in: Circle())
            Text(text).font(.subheadline).foregroundStyle(DS.ink)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

private struct LevelPickerRow: View {
    let level: CEFRLevel
    let isSelected: Bool
    let action: () -> Void

    private var info: (label: String, desc: String) {
        switch level {
        case .a1: ("A1 · Débutant",      "Les bases : saluer, compter, nommer")
        case .a2: ("A2 · Élémentaire",   "Vie quotidienne, voyages, famille")
        case .b1: ("B1 · Intermédiaire", "Discussions, actualités, opinions")
        case .b2: ("B2 · Avancé",        "Vocabulaire riche et nuancé")
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.label).font(.callout.weight(.semibold)).foregroundStyle(DS.ink)
                    Text(info.desc).font(.caption).foregroundStyle(DS.muted)
                }
                Spacer()
                ZStack {
                    Circle().stroke(isSelected ? DS.accent : DS.border, lineWidth: 1.5).frame(width: 22, height: 22)
                    if isSelected { Circle().fill(DS.accent).frame(width: 12, height: 12) }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(isSelected ? DS.accent.opacity(0.07) : DS.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? DS.accent.opacity(0.45) : DS.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("level_\(level.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Main Tab (2 tabs — Settings lives in the nav bar)

private struct MainTabView: View {
    @State private var selection = UITestSupport.initialTab
    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Aujourd'hui", systemImage: "sun.max.fill") }
                .tag(0)
            ProgressScreen()
                .tabItem { Label("Progrès", systemImage: "chart.bar.fill") }
                .tag(1)
        }
        .tint(DS.accent)
    }
}

// MARK: - Home (swipeable word deck + widget showcase)

private struct HomeView: View {
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: EntryStore

    @State private var deckIndex = 0
    @State private var revealedIds: Set<Int> = []
    @State private var learnedLocal: Set<Int> = []
    @State private var showSettings = false

    private let cardHeight: CGFloat = 300

    var body: some View {
        let today = Date().startOfDay
        let level = settings.selectedLevel
        let entry = store.entry(day: today, level: level)
        let todayWord = entry.flatMap { wordStore.word(id: $0.wordId) }
        let deck = buildDeck(level: level, todayWordId: todayWord?.id)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {

                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(today, format: .dateTime.weekday(.wide))
                                    .font(.caption.weight(.semibold))
                                    .tracking(1.5).textCase(.uppercase)
                                    .foregroundStyle(DS.muted)
                                Sticker("✏️", rotation: -8, size: 16)
                            }
                            Text(today, format: .dateTime.day().month(.wide))
                                .font(DS.serif(.title2))
                                .foregroundStyle(DS.ink)
                        }
                        Spacer()
                        Chip(label: level.rawValue)
                    }

                    if deck.isEmpty {
                        if wordStore.totalCount(for: level) == 0 {
                            InfoCard(title: "Aucun mot", subtitle: "Aucun mot pour le niveau \(level.rawValue).")
                        } else {
                            InfoCard(title: "Chargement…", subtitle: "Préparation de ton mot du jour.")
                                .onAppear {
                                    if let entry, wordStore.word(id: entry.wordId) == nil { store.removeEntry(id: entry.id) }
                                    DailyWordService.syncUpToToday(level: level, wordStore: wordStore, settings: settings, store: store)
                                }
                        }
                    } else {
                        deckView(deck: deck, entry: entry, todayWordId: todayWord?.id, level: level)
                    }

                    WidgetShowcase(word: todayWord ?? deck.first, level: level)

                    HStack(spacing: 18) {
                        Spacer()
                        Sticker("📚", rotation: -10, size: 26)
                        Sticker("✨", rotation: 8, size: 22)
                        Sticker("🌸", rotation: -6, size: 24)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .padding(24)
            }
            .navigationTitle("Aujourd'hui")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(DS.accent)
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .background { NotebookBackground() }
            .scrollContentBackground(.hidden)
            .sheet(isPresented: $showSettings) { SettingsSheet() }
            .onAppear {
                guard UITestSupport.autoReveal,
                      let e = store.entry(day: Date().startOfDay, level: settings.selectedLevel) else { return }
                revealedIds.insert(e.wordId)
            }
        }
    }

    // ── Deck ──────────────────────────────────────────────────────────
    @ViewBuilder
    private func deckView(deck: [Word], entry: DailyEntryModel?, todayWordId: Int?, level: CEFRLevel) -> some View {
        let safeIndex = min(deckIndex, deck.count - 1)

        VStack(spacing: 14) {
            TabView(selection: $deckIndex) {
                ForEach(Array(deck.enumerated()), id: \.element.id) { i, word in
                    DeckCard(
                        word: word,
                        revealed: revealedIds.contains(word.id) || isLearned(word, entry: entry, todayWordId: todayWordId),
                        isToday: word.id == todayWordId,
                        state: cardState(word, entry: entry, todayWordId: todayWordId)
                    )
                    .padding(.horizontal, 2)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: cardHeight)

            PageDots(count: deck.count, index: safeIndex)

            actions(for: deck[safeIndex], entry: entry, todayWordId: todayWordId, level: level)
        }
    }

    @ViewBuilder
    private func actions(for word: Word, entry: DailyEntryModel?, todayWordId: Int?, level: CEFRLevel) -> some View {
        let isToday = word.id == todayWordId
        let revealed = revealedIds.contains(word.id) || isLearned(word, entry: entry, todayWordId: todayWordId)
        let learned  = isLearned(word, entry: entry, todayWordId: todayWordId)

        VStack(spacing: 10) {
            if revealed {
                HStack(spacing: 10) {
                    GhostButton(label: "À revoir") {
                        if isToday, let entry {
                            DailyWordService.markReview(entry: entry, level: level, wordStore: wordStore, store: store)
                        } else {
                            DailyWordService.setWordState(wordId: word.id, level: level, state: .seen, store: store)
                        }
                        learnedLocal.remove(word.id)
                    }
                    PrimaryButton(label: learned ? "Appris ✓" : "Je l'ai appris",
                                  tint: learned ? DS.sage : DS.ink) {
                        if isToday, let entry {
                            DailyWordService.markLearned(entry: entry, level: level, wordStore: wordStore, store: store)
                        } else {
                            DailyWordService.setWordState(wordId: word.id, level: level, state: .learned, store: store)
                        }
                        learnedLocal.insert(word.id)
                    }
                }
                .transition(.opacity)
            } else {
                PrimaryButton(label: "Voir la traduction") {
                    _ = withAnimation(.spring(duration: 0.3)) { revealedIds.insert(word.id) }
                    if isToday, let entry {
                        DailyWordService.markSeen(entry: entry, level: level, wordStore: wordStore, store: store)
                    } else {
                        DailyWordService.setWordState(wordId: word.id, level: level, state: .seen, store: store)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: revealedIds)
    }

    private func isLearned(_ word: Word, entry: DailyEntryModel?, todayWordId: Int?) -> Bool {
        if word.id == todayWordId, let entry { return entry.state == .learned }
        return learnedLocal.contains(word.id)
    }

    private func cardState(_ word: Word, entry: DailyEntryModel?, todayWordId: Int?) -> DailyState {
        if word.id == todayWordId, let entry { return entry.state }
        if learnedLocal.contains(word.id) { return .learned }
        return revealedIds.contains(word.id) ? .seen : .pending
    }

    private func buildDeck(level: CEFRLevel, todayWordId: Int?) -> [Word] {
        var result: [Word] = []
        if let id = todayWordId, let w = wordStore.word(id: id) { result.append(w) }
        let learned = store.learnedWordIds(level: level)
        let others = wordStore.words(for: level)
            .filter { $0.id != todayWordId && !learned.contains($0.id) }
        result += Array(others.prefix(30))
        return result
    }
}

private struct DeckCard: View {
    let word: Word
    let revealed: Bool
    let isToday: Bool
    let state: DailyState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("anglais")
                        .font(.caption.weight(.medium)).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(DS.muted)
                    Spacer()
                    if isToday {
                        Text("mot du jour")
                            .font(.caption2.weight(.semibold)).tracking(0.5).textCase(.uppercase)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(DS.accent.opacity(0.12))
                            .foregroundStyle(DS.accent)
                            .clipShape(Capsule())
                    }
                }
                Text(word.en)
                    .font(DS.serif(.largeTitle))
                    .foregroundStyle(DS.ink)
                    .minimumScaleFactor(0.5).lineLimit(2)

                Divider().overlay(DS.border)

                VStack(alignment: .leading, spacing: 6) {
                    Text("français")
                        .font(.caption.weight(.medium)).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(DS.muted)
                    if revealed {
                        Text(word.fr)
                            .font(DS.serif(.title, .semibold))
                            .foregroundStyle(DS.ink)
                            .minimumScaleFactor(0.6).lineLimit(2)
                    } else {
                        Text("• • • • •")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(DS.border)
                    }
                }
            }
            .padding(24)
            Spacer(minLength: 0)
            if state != .pending {
                Divider().overlay(DS.border)
                HStack { StateTag(state: state); Spacer() }
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.radius, style: .continuous).stroke(DS.border, lineWidth: 1))
        .overlay(alignment: .top) { WashiTape().offset(y: -9) }
        .overlay(alignment: .topTrailing) {
            if isToday { Sticker("⭐️", rotation: 14, size: 28).offset(x: 6, y: -14) }
        }
        .shadow(color: .black.opacity(0.05), radius: 14, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(revealed ? "\(word.en), \(word.fr)" : "\(word.en), traduction masquée")
    }
}

// MARK: - Widget showcase

private struct WidgetShowcase: View {
    let word: Word?
    let level: CEFRLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Tes widgets").font(DS.serif(.title3)).foregroundStyle(DS.ink)
                Sticker("📌", rotation: 6, size: 18)
                Spacer()
                Text("aperçu")
                    .font(.caption.weight(.semibold)).tracking(1).textCase(.uppercase)
                    .foregroundStyle(DS.muted)
            }

            HStack(spacing: 14) {
                WidgetPreviewTile(style: .daily, en: word?.en ?? "serene", fr: word?.fr ?? "serein", level: level.rawValue)
                WidgetPreviewTile(style: .hourly, en: word?.en ?? "vivid", fr: word?.fr ?? "éclatant", level: level.rawValue)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.tap.fill").font(.callout).foregroundStyle(DS.accent).frame(width: 22)
                Text("Reste appuyé sur l'écran d'accueil → **+** → cherche **Vocabulaire**. Fonctionne aussi sur l'écran verrouillé.")
                    .font(.footnote).foregroundStyle(DS.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.border, lineWidth: 1))
        }
    }
}

enum PreviewStyle { case daily, hourly }

struct WidgetPreviewTile: View {
    let style: PreviewStyle
    let en: String
    let fr: String
    let level: String

    private var gradient: LinearGradient {
        switch style {
        case .daily:  LinearGradient(colors: [DS.accent, DS.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .hourly: LinearGradient(colors: [DS.espresso, DS.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    private var label: String { style == .daily ? "Mot du jour" : "Mot de l'heure" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text(level)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.white.opacity(0.22)).foregroundStyle(.white).clipShape(Capsule())
            }
            Spacer()
            Text(en).font(DS.serif(22)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(fr).font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
        }
        .padding(14)
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aperçu widget \(label)")
    }
}

// MARK: - Progress

private struct ProgressScreen: View {
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: EntryStore

    var body: some View {
        let g = ProgressService.stats(wordStore: wordStore, store: store)
        let pct = g.total > 0 ? Double(g.learned) / Double(g.total) : 0
        let recent = Array(store.entries.sorted { $0.day > $1.day }.prefix(12))

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Surface {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(Int(pct * 100))%").font(DS.serif(.largeTitle)).foregroundStyle(DS.ink)
                                    Text("des mots appris").font(.subheadline).foregroundStyle(DS.muted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 10) {
                                    StatLine(value: g.learned, label: "appris",   color: DS.sage)
                                    StatLine(value: g.seen,    label: "vus",      color: DS.accent)
                                    StatLine(value: g.remaining, label: "restants", color: DS.muted)
                                }
                            }
                            ProgressBar(value: pct, tint: DS.accent)
                        }
                    }

                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Par niveau")
                            ForEach(levelStats, id: \.0) { level, stats in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(level.rawValue).font(.callout.weight(.semibold)).foregroundStyle(DS.ink)
                                        Text(levelName(level)).font(.caption).foregroundStyle(DS.muted)
                                        Spacer()
                                        Text("\(stats.learned) / \(stats.total)")
                                            .font(.caption.monospacedDigit()).foregroundStyle(DS.muted)
                                    }
                                    ProgressBar(value: stats.total > 0 ? Double(stats.learned) / Double(stats.total) : 0, tint: DS.accent)
                                }
                            }
                        }
                    }

                    if !recent.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Derniers mots")
                            VStack(spacing: 0) {
                                ForEach(Array(recent.enumerated()), id: \.element.id) { idx, entry in
                                    if let word = wordStore.word(id: entry.wordId) {
                                        RecentRow(word: word, entry: entry)
                                        if idx < recent.count - 1 { Divider().overlay(DS.border).padding(.leading, 18) }
                                    }
                                }
                            }
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.radius, style: .continuous).stroke(DS.border, lineWidth: 1))
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Progrès")
            .background { NotebookBackground() }
            .scrollContentBackground(.hidden)
        }
    }

    private var levelStats: [(CEFRLevel, ProgressService.Stats)] {
        CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { ($0, ProgressService.stats(level: $0, wordStore: wordStore, store: store)) }
    }
    private func levelName(_ l: CEFRLevel) -> String {
        switch l { case .a1: "Débutant"; case .a2: "Élémentaire"; case .b1: "Intermédiaire"; case .b2: "Avancé" }
    }

    private struct StatLine: View {
        let value: Int; let label: String; let color: Color
        var body: some View {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text("\(value)").font(.callout.weight(.semibold).monospacedDigit()).foregroundStyle(DS.ink)
                Text(label).font(.caption).foregroundStyle(DS.muted)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private struct RecentRow: View {
        let word: Word
        let entry: DailyEntryModel
        var body: some View {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3).fill(stateColor).frame(width: 3, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(word.en).font(.callout.weight(.semibold)).foregroundStyle(DS.ink)
                    Text(word.fr).font(.subheadline).foregroundStyle(DS.muted)
                }
                Spacer()
                Text(entry.day, format: .dateTime.day().month()).font(.caption).foregroundStyle(DS.muted)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        }
        private var stateColor: Color {
            switch entry.state { case .learned: DS.sage; case .seen: DS.accent; case .pending: DS.border }
        }
    }
}

// MARK: - Settings (nav-bar sheet, restyled like the home)

private struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var wordStore: WordStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: EntryStore

    @State private var notifStatus: UNAuthorizationStatus? = nil
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Niveau
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Ton niveau")
                        VStack(spacing: 10) {
                            ForEach(CEFRLevel.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { level in
                                LevelPickerRow(level: level, isSelected: settings.selectedLevel == level) {
                                    withAnimation(.spring(duration: 0.2)) { settings.selectedLevel = level }
                                }
                            }
                        }
                        Text("Le mot du jour actuel ne change pas.")
                            .font(.caption).foregroundStyle(DS.muted).padding(.leading, 4)
                    }

                    // Notifications
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Rappel quotidien")
                        Surface {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Statut").foregroundStyle(DS.ink)
                                    Spacer()
                                    Text(notifLabel).foregroundStyle(DS.muted)
                                }
                                Divider().overlay(DS.border)
                                DatePicker("Heure du rappel", selection: settings.notificationDateBinding, displayedComponents: .hourAndMinute)
                                    .tint(DS.accent)
                                PrimaryButton(label: "Activer / mettre à jour") {
                                    Task {
                                        let ok = await NotificationScheduler.requestAuthorization()
                                        if ok {
                                            await NotificationScheduler.scheduleDailyReminder(hour: settings.notificationHour, minute: settings.notificationMinute)
                                        }
                                        notifStatus = await NotificationScheduler.currentStatus()
                                    }
                                }
                                if notifStatus == .denied {
                                    GhostButton(label: "Ouvrir les réglages iOS") { openSettings() }
                                }
                            }
                        }
                    }

                    // Données
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Données")
                        Button { showReset = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash").foregroundStyle(.red)
                                Text("Réinitialiser la progression").foregroundStyle(.red)
                                Spacer()
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.border, lineWidth: 1))
                        }
                    }
                }
                .padding(24)
            }
            .background { NotebookBackground() }
            .scrollContentBackground(.hidden)
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(.body.weight(.semibold))
                }
            }
        }
        .tint(DS.accent)
        .task { notifStatus = await NotificationScheduler.currentStatus() }
        .onChange(of: settings.notificationHour)   { _ in reschedule() }
        .onChange(of: settings.notificationMinute) { _ in reschedule() }
        .confirmationDialog("Réinitialiser ?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) {
                DailyWordService.resetProgress(settings: settings, store: store)
                DailyWordService.syncUpToToday(level: settings.selectedLevel, wordStore: wordStore, settings: settings, store: store)
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
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        #endif
    }
}

// MARK: - Shared components

private struct PrimaryButton: View {
    let label: String
    var tint: Color = DS.ink
    var disabled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? DS.border : tint)
                .foregroundStyle(disabled ? DS.muted : Color.white)
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
                .foregroundStyle(DS.ink)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                Capsule()
                    .fill(i == index ? DS.accent : DS.border)
                    .frame(width: i == index ? 16 : 6, height: 6)
                    .animation(.spring(duration: 0.25), value: index)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct Chip: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold)).tracking(0.5)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(DS.surface).foregroundStyle(DS.accent)
            .overlay(Capsule().stroke(DS.border, lineWidth: 1)).clipShape(Capsule())
            .accessibilityLabel("Niveau \(label)")
    }
}

private struct StateTag: View {
    let state: DailyState
    var body: some View {
        let (label, color): (String, Color) = {
            switch state {
            case .learned: ("Appris", DS.sage)
            case .seen:    ("Vu",     DS.accent)
            case .pending: ("Nouveau", DS.muted)
            }
        }()
        Text(label)
            .font(.caption.weight(.semibold)).tracking(0.5)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.12)).foregroundStyle(color).clipShape(Capsule())
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
    let value: Double
    let tint: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(DS.border).frame(height: 6)
                RoundedRectangle(cornerRadius: 4).fill(tint)
                    .frame(width: g.size.width * CGFloat(max(0, min(1, value))), height: 6)
                    .animation(.spring(duration: 0.5), value: value)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

private struct InfoCard: View {
    let title: String
    let subtitle: String
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.callout.weight(.semibold)).foregroundStyle(DS.ink)
                Text(subtitle).font(.subheadline).foregroundStyle(DS.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold)).tracking(1).textCase(.uppercase)
            .foregroundStyle(DS.muted)
    }
}

private struct ErrorStateView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(DS.accent)
            Text("Erreur").font(DS.serif(.title)).foregroundStyle(DS.ink)
            Text(message).font(.subheadline).foregroundStyle(DS.muted).multilineTextAlignment(.center)
            PrimaryButton(label: "Réessayer", action: retry).frame(maxWidth: 200)
        }
        .padding(32)
    }
}
