# Architecture proposée (iOS 17+, SwiftUI + WidgetKit)

## 1) Principes
- **Offline-first** : tout fonctionne sans réseau.
- **JSON immuable** pour la base de 2000 mots (dans le bundle).
- **Persistance légère** pour : niveau, historique journalier, statuts appris/vu, heure de notification.
- **Partage App ↔ Widget** via **App Group** (snapshot minimal pour le widget).

## 2) Modèle de données

### Vocabulaire (bundle)
Fichier `words.json` (exemple de forme logique) :
```json
{ "id": 123, "en": "apple", "fr": "pomme", "level": "A1" }
```

Recommandations :
- `id` unique et stable (int ou string).
- `level` normalisé (`A1`/`A2`/`B1`/`B2`).
- Le JSON peut rester classé par niveau, mais l’app doit surtout pouvoir **filtrer**.

### Paramètres (UserDefaults / AppStorage)
`AppSettings` :
- `selectedLevel: CEFRLevel`
- `notificationTime: DateComponents` (heure/minute)
- `onboardingCompleted: Bool`
- `shuffleSeed: UInt64` (pour un ordre stable des mots)
- `nextIndexByLevel: [CEFRLevel: Int]` (pointeur dans l’ordre mélangé)

### Persistance “métier” (SwiftData recommandé)
Deux entités persistées (store local) :

`DailyEntry`
- `day: Date` (normalisé à `startOfDay`)
- `wordId: Int`
- `level: CEFRLevel` (niveau au moment de l’attribution)
- `state: DailyState` (`pending`, `seen`, `learned`)
- `revealedAt: Date?`
- `learnedAt: Date?`

`WordProgress` (facultatif mais pratique)
- `wordId: Int`
- `state: WordState` (`new`, `seen`, `learned`)
- `firstSeenAt: Date?`
- `learnedAt: Date?`

Notes :
- On peut **dériver** `WordProgress` depuis `DailyEntry`, mais `WordProgress` simplifie recherche/statistiques et actions depuis l’historique.
- On ne persiste pas le mot entier (EN/FR) si le JSON est la source : on persiste **uniquement** `wordId` + timestamps/statuts.

## 3) Services (Domain)

### `WordRepository`
Responsable de :
- Charger `words.json` depuis le bundle.
- Exposer : `words(for level:)`, `word(by id:)`, index/recherche (simple contains sur `en`/`fr`).

### `DailyWordService`
Responsable de :
- Garantir **1 entrée par jour** (par niveau actif) et gérer les jours manqués.
- Sélectionner un mot **non appris** au moment de l’attribution.
- Mettre à jour le snapshot App Group pour le widget.

API indicative :
- `syncUpToToday(selectedLevel:)` (appel au lancement + retour foreground)
- `todayEntry(selectedLevel:) -> DailyEntry`
- `markSeen(entryId:)`, `markLearned(entryId:)`, `markReview(entryId:)`

### `ProgressService`
Responsable de :
- Calculer `appris / vus / restants` global et par niveau à partir de `WordProgress` (ou des `DailyEntry`).

### `NotificationScheduler`
Responsable de :
- Demander l’autorisation.
- Planifier / replanifier la notification quotidienne (locale).

## 4) Logique de sélection du mot (robuste & stable)

### Normalisation “jour”
Toujours utiliser :
- `let day = Calendar.autoupdatingCurrent.startOfDay(for: Date())`
Cela évite les bugs DST et les comparaisons d’heures.

### Stratégie d’ordre des mots
But : ne pas “toujours prendre le 1er mot” et garder un ordre stable dans le temps.

Proposition :
- Pour chaque niveau, construire `orderedWordIds(level)` = liste des ids du niveau, **mélangée** avec `shuffleSeed` (persisté).
- Conserver `nextIndexByLevel[level]`.
- Pour attribuer un mot : avancer `nextIndex` jusqu’à trouver un `wordId` non `learned` et non déjà utilisé dans une `DailyEntry`.

Pseudo :
```swift
func pickNextWordId(level: CEFRLevel) -> Int? {
  let ids = orderedWordIds(level)
  var i = settings.nextIndexByLevel[level, default: 0]
  while i < ids.count {
    let id = ids[i]
    i += 1
    if !isLearned(id) && !isAlreadyAssigned(id, level: level) {
      settings.nextIndexByLevel[level] = i
      return id
    }
  }
  return nil // niveau terminé
}
```

## 5) Gestion des jours manqués (rattrapage)

À chaque lancement / retour foreground :
1. `lastGeneratedDay` = dernier `DailyEntry.day` existant pour le niveau actif (ou nil).
2. Générer `DailyEntry` pour chaque `day` manquant jusqu’à aujourd’hui inclus.
3. Les entrées générées dans le passé sont marquées `pending` (non consultées).

Comportement UI :
- Accueil montre l’entrée de **aujourd’hui**.
- Historique affiche “À rattraper” = entrées `pending` des jours précédents.

## 6) Partage avec le widget (App Group)

### Pourquoi un snapshot
Le widget doit afficher rapidement le mot du jour sans dépendre d’un accès direct au store interne de l’app.

`WidgetSnapshot` (dans `UserDefaults(suiteName:)` ou un petit fichier JSON App Group) :
- `day: Date`
- `wordId: Int`
- `en: String`
- `fr: String`
- `level: String`
- `state: String` (`pending`/`seen`/`learned`)

Mise à jour :
- À chaque création/màj du `DailyEntry` du jour, l’app écrit le snapshot et appelle `WidgetCenter.shared.reloadTimelines(...)`.

## 7) Structure de code (proposition)
- `vocabulary/` (app)
  - `App/` (entry point, routing)
  - `Features/`
    - `Home/` (Mot du jour)
    - `History/`
    - `Progress/`
    - `Settings/`
  - `Data/` (`WordRepository`, JSON loading)
  - `Domain/` (`DailyWordService`, `ProgressService`, `NotificationScheduler`)
  - `Persistence/` (SwiftData models + AppSettings)
- `dailyVocabulary/` (widget)
  - `WidgetSnapshotReader` (App Group)
  - `dailyVocabularyEntryView` (UI)

