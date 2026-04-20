# Spécification fonctionnelle — Vocabulaire FR → EN (2000 mots)

## 1) Vision & objectifs

### Objectif produit (North Star)
Faire apprendre **1 nouveau mot par jour** (“Word of the Day”) parmi **2000 mots** (FR → EN), avec **progression** claire et motivante.

### Objectifs secondaires
- Donner un sentiment de continuité (streak léger) sans pression.
- Rendre visible la progression (global + par niveau CEFR).
- Rester **offline-first** et respectueux de la vie privée (données locales).

## 2) Données & règles métier (résumé)

### Source de vérité
- Un fichier **JSON local** embarqué dans l’app (bundle) contient les 2000 mots.
- Chaque entrée contient au minimum : `id`, `en`, `fr`, `level` (`A1`, `A2`, `B1`, `B2`).
- Les mots sont classés par niveau (au minimum filtrables par niveau).

### États d’apprentissage
- **Nouveau** : jamais affiché à l’utilisateur.
- **Vu** : affiché et consulté (ex. traduction révélée).
- **Appris** : marqué appris par l’utilisateur.

### Règle “mot du jour”
- Un **mot unique** par **jour calendaire** (timezone locale de l’appareil).
- Le mot du jour doit appartenir au **niveau actuel** de l’utilisateur.
- Le mot du jour doit être **non appris** au moment de l’attribution.

### Absence d’ouverture plusieurs jours (règle choisie)
**Rattrapage jour par jour** :
- Si l’app n’est pas ouverte pendant X jours, on **crée** les entrées “mot du jour” manquantes (une par jour) avec des mots uniques non appris.
- L’accueil affiche le **mot du jour du jour** (aujourd’hui), mais l’historique expose une section **“À rattraper”** (jours non consultés).

## 3) Parcours utilisateur (high level)

1. Premier lancement → Onboarding (choix niveau + explication rapide).
2. Accueil → Mot du jour (EN) + action “Voir la traduction” → FR.
3. Action “Je l’ai appris” (ou “À revoir”) met à jour la progression.
4. Notification quotidienne “Ton mot du jour est prêt” (heure configurable).
5. Widget → affiche le mot du jour (EN puis FR).

## 4) User stories & critères d’acceptation

### Epic A — Onboarding

**A1 — Choix du niveau au premier lancement**
- En tant que nouvel utilisateur, je choisis mon niveau (A1/A2/B1/B2) pour recevoir des mots adaptés.
**Critères d’acceptation**
- Au premier lancement uniquement, l’écran propose 4 choix : `A1`, `A2`, `B1`, `B2`.
- Tant que le niveau n’est pas choisi, l’utilisateur ne peut pas accéder à l’accueil.
- Le niveau choisi est persisté localement.

**A2 — Explication du fonctionnement**
- En tant que nouvel utilisateur, je comprends qu’il y a 1 mot par jour et que je peux suivre ma progression.
**Critères d’acceptation**
- Un écran/encart d’onboarding explique : “1 mot/jour”, “révèle la traduction”, “marque appris”, “widget + notification”.
- Bouton “Commencer” mène à l’accueil.

### Epic B — Accueil (Mot du jour)

**B1 — Affichage du mot du jour (EN puis FR)**
- En tant qu’utilisateur, je vois le mot du jour en anglais, puis je révèle sa traduction française.
**Critères d’acceptation**
- L’accueil affiche : date du jour, niveau actif, carte “Mot du jour”.
- Par défaut, la carte montre `en` (anglais) en grand.
- Un contrôle “Voir la traduction” révèle `fr` (français).
- Le statut “Vu” est enregistré au moment où la traduction est révélée (ou quand la carte est consultée, selon décision UI — par défaut: à la révélation).

**B2 — Marquer un mot comme appris**
- En tant qu’utilisateur, je peux marquer le mot du jour comme “Appris”.
**Critères d’acceptation**
- Un bouton “Je l’ai appris” met le statut du mot à `Appris`.
- Le mot appris n’est plus sélectionné comme futur mot du jour.
- Un feedback visuel confirme l’action (ex. badge “Appris”).

**B3 — Revenir en arrière (“À revoir”)**
- En tant qu’utilisateur, je peux indiquer que je ne maîtrise pas encore un mot.
**Critères d’acceptation**
- Si un mot est `Vu` ou `Appris`, un bouton “À revoir” le remet en `Vu` (ou `Nouveau` si jamais consulté — recommandé: `Vu`).
- La progression se met à jour immédiatement.

**B4 — Gestion des jours manqués**
- En tant qu’utilisateur, si je reviens après plusieurs jours, je ne perds pas mes mots.
**Critères d’acceptation**
- À l’ouverture, l’app détecte les jours manqués depuis la dernière génération.
- L’app crée une entrée “mot du jour” pour chaque jour manqué, avec un mot unique non appris.
- L’accueil affiche le mot du jour d’aujourd’hui.
- L’historique affiche les jours manqués dans une section “À rattraper”.

### Epic C — Historique & recherche

**C1 — Liste des mots déjà vus**
- En tant qu’utilisateur, je peux consulter les mots déjà vus et leurs traductions.
**Critères d’acceptation**
- L’écran Historique liste les entrées journalières (du plus récent au plus ancien).
- Chaque item affiche : date, `en`, `fr`, badge statut (`Vu` / `Appris`).
- Un item ouvre une fiche (ou un détail) avec actions “Appris” / “À revoir”.

**C2 — Recherche simple**
- En tant qu’utilisateur, je peux rechercher un mot rapidement.
**Critères d’acceptation**
- Une barre de recherche filtre en temps réel sur `en` et `fr` (insensible à la casse).
- Si aucun résultat : état vide clair.

### Epic D — Progression

**D1 — Progression globale et par niveau**
- En tant qu’utilisateur, je vois combien de mots j’ai appris et combien il en reste.
**Critères d’acceptation**
- Afficher : `appris`, `vus`, `restants` (global).
- Afficher la même info par niveau (`A1`, `A2`, `B1`, `B2`).
- Les chiffres se basent sur la source JSON + les statuts persistés localement.

**D2 — Objectif quotidien (1/jour)**
- En tant qu’utilisateur, je sais si j’ai déjà validé le mot du jour.
**Critères d’acceptation**
- L’écran Progression affiche “Mot du jour : vu / appris / non consulté”.
- Optionnel : streak simple (nombre de jours consécutifs où le mot du jour a été vu ou appris).

### Epic E — Réglages

**E1 — Changer de niveau**
- En tant qu’utilisateur, je peux changer mon niveau plus tard.
**Critères d’acceptation**
- Dans Réglages, un sélecteur permet de changer `A1/A2/B1/B2`.
- Le changement prend effet immédiatement pour la génération du prochain mot du jour.
- Le mot du jour déjà attribué pour aujourd’hui reste inchangé (recommandé) pour éviter confusion.

**E2 — Heure de notification**
- En tant qu’utilisateur, je choisis l’heure à laquelle je reçois la notification.
**Critères d’acceptation**
- Un sélecteur d’heure (TimePicker) enregistre l’heure choisie.
- Toute modification reschedule la notification quotidienne.

**E3 — Reset progression**
- En tant qu’utilisateur, je peux remettre à zéro mon apprentissage.
**Critères d’acceptation**
- Un bouton “Réinitialiser la progression” affiche une confirmation (destructive).
- Après confirmation : statuts, historique, mot du jour et préférences (option: garder préférences) sont remis à zéro selon règle explicitée.

### Epic F — Notifications

**F1 — Demande d’autorisation**
- En tant qu’utilisateur, je suis invité à activer les notifications au bon moment.
**Critères d’acceptation**
- L’app demande l’autorisation après onboarding (ou au 1er accès Réglages → Notifications).
- Si refus : UI affiche un état “Notifications désactivées” + raccourci vers Réglages iOS.

**F2 — Notification quotidienne**
- En tant qu’utilisateur, je reçois une notification quotidienne “Ton mot du jour est prêt”.
**Critères d’acceptation**
- Une notification locale est planifiée chaque jour à l’heure choisie.
- Le contenu est générique (pas d’informations sensibles).
- Changement d’heure/timezone met à jour la prochaine occurrence (via trigger calendaire).

### Epic G — Widget

**G1 — Widget “Mot du jour”**
- En tant qu’utilisateur, je vois le mot du jour sur l’écran d’accueil.
**Critères d’acceptation**
- Le widget affiche `en` puis `fr` (layout vertical, hiérarchie typographique).
- Un état “vide” existe si aucun mot n’a encore été généré (ex. avant onboarding).
- Tap sur le widget ouvre l’app directement sur l’accueil (deep link).

## 5) Exigences UI (DA)
- Palette : **beige** (fond) + **gris translucide** (cartes).
- Cartes arrondies + ombre très douce + blur léger (glassmorphism).
- Typo lisible : hiérarchie claire (mot en grand, traduction plus petite).
- Animations discrètes : reveal de traduction (fade/slide).

## 6) Cas limites (à couvrir)
- Changement de niveau en milieu de journée.
- Manque de mots non appris dans un niveau (100% appris) → état “Niveau terminé” + proposition de changer de niveau ou reset.
- Changement de timezone / date (voyage) : baser “jour” sur `Calendar.current.startOfDay(for:)`.
- App installée mais notifications refusées : fonctionnement sans blocage.

