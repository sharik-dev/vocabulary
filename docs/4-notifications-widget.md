# Plan technique — Notifications + Widget (iOS)

## 1) Notifications quotidiennes (UNUserNotificationCenter)

### 1.1 Autorisations
- Moment recommandé : après onboarding (ou première visite de “Réglages > Notifications”).
- API :
  - `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])`
  - Lire le statut via `getNotificationSettings`.

UI attendue :
- Si `authorized` : afficher “Activées”.
- Si `denied` : afficher “Désactivées” + bouton ouvrant les Réglages iOS (`UIApplication.openSettingsURLString`).

### 1.2 Planification
Contenu (volontairement générique) :
- Titre : “Mot du jour”
- Body : “Ton mot du jour est prêt”

Trigger :
- `UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: h, minute: m), repeats: true)`

Règles :
- Toute modification de l’heure dans Réglages → **reschedule**.
- Réinitialisation progression → **clear** des notifications puis reschedule si activées.

Implémentation (service)
- `NotificationScheduler.scheduleDailyReminder(time:)`
  - `removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])`
  - `add(request)`
- `NotificationScheduler.cancelDailyReminder()`

Notes iOS :
- Le texte de la notif est fixe → pas besoin de connaître le mot exact au moment du scheduling.
- Le “mot du jour” est généré à l’ouverture (et/ou au foreground) : la notif sert de rappel.

## 2) Widget “Mot du jour” (WidgetKit)

Le repo contient déjà une target widget `dailyVocabulary/` (WidgetKit). L’objectif est de remplacer l’exemple “emoji/time” par le mot du jour.

### 2.1 Partage App ↔ Widget (App Group)
Pourquoi :
- Le widget doit lire un état minimal sans accéder à la base interne de l’app.

Étapes Xcode :
- Activer **App Groups** sur la target app **et** la target widget.
- Définir un identifiant, ex. `group.com.yourcompany.vocabulary`.

Format “snapshot” partagé (UserDefaults App Group ou petit fichier JSON) :
- `day` (startOfDay)
- `en`, `fr`
- `level`
- `state` (`pending`/`seen`/`learned`)

Écriture côté app :
- À chaque update du mot du jour, écrire le snapshot dans `UserDefaults(suiteName:)`.
- Puis appeler `WidgetCenter.shared.reloadTimelines(ofKind: "dailyVocabulary")`.

Lecture côté widget :
- Dans `TimelineProvider`, lire le snapshot.
- Si absent : afficher un état vide “Ouvre l’app pour choisir ton niveau”.

### 2.2 Timeline & refresh
Objectif :
- Rafraîchir au **changement de jour** (et quand l’app force un refresh).

Politique recommandée :
- Une entrée “now” + prochaine entrée à **demain 00:00** (locale) :
  - `let next = Calendar.autoupdatingCurrent.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)!`
  - `Timeline(entries: [entry], policy: .after(next))`

Ensuite :
- Quand l’app attribue un nouveau mot (ou change de niveau), elle force `reloadTimelines`.

### 2.3 UI du widget (design)
Small (recommandé) :
- EN (headline, 1–2 lignes, ellipsis)
- FR (subheadline, 1–2 lignes, opacity légère)
- Badge niveau (A1/A2/B1/B2)

Medium/Large (optionnel) :
- Même contenu + statut (“Appris” si applicable) + date.

Style :
- Cartes arrondies, fond translucide, contraste suffisant (accessibilité).
- iOS 17 : `containerBackground(.fill.tertiary, for: .widget)` + overlay léger.

### 2.4 Deep link depuis le widget
But :
- Tap widget → ouvre l’app sur l’accueil (mot du jour).

Implémentation :
- Définir une URL (ex. `vocabulary://home`) et la déclarer (URL Types).
- Dans le widget : `.widgetURL(URL(string: "vocabulary://home")!)`
- Dans l’app : router l’URL vers l’écran Accueil.

## 3) Points d’attention (qualité)
- Timezone/DST : toujours normaliser les dates à `startOfDay`.
- Cohérence : le widget affiche **le snapshot** (source unique pour l’UI widget).
- Performance : JSON des 2000 mots chargé une fois côté app (cache), le widget ne charge pas le gros JSON.
- États “niveau terminé” : snapshot peut porter un flag `levelCompleted` pour afficher une UI dédiée (optionnel).

