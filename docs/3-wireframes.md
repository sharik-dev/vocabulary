# Wireframes textuels (SwiftUI)

## Navigation (structure recommandée)
- Tab bar (4 onglets) :
  - **Accueil**
  - **Historique**
  - **Progression**
  - **Réglages**

Fond global : beige. Contenus sur cartes gris translucide (glassmorphism léger).

---

## 1) Onboarding — Choix du niveau

**Header**
- Titre : “Bienvenue”
- Sous-titre : “Choisis ton niveau pour recevoir un mot par jour”

**Card: Sélection niveau**
- Segmented / grid buttons :
  - `A1` “Débutant”
  - `A2` “Élémentaire”
  - `B1` “Intermédiaire”
  - `B2` “Avancé”

**Footer**
- Bouton primaire : “Commencer”
- Texte secondaire : “Tu pourras changer de niveau plus tard.”

**États**
- CTA désactivé tant qu’aucun niveau n’est sélectionné.

---

## 2) Accueil — Mot du jour

**Top bar**
- “Mot du jour” + date (ex. “Lun 20 avr.”)
- Chip : “Niveau A2” (tap → ouvre Réglages)

**Card principale (glass)**
- Label : “Anglais”
- Mot EN (très grand, bold)
- (Optionnel) phonétique / mini info (hors scope si pas dans JSON)
- Bouton secondaire : “Voir la traduction”

**Après reveal**
- Label : “Français”
- Traduction FR (medium)
- Actions :
  - Bouton primaire : “Je l’ai appris”
  - Bouton tertiaire : “À revoir”

**Footer**
- Petit lien : “Voir l’historique”

**États**
- Avant onboarding : écran bloquant onboarding.
- Niveau terminé : card “Niveau terminé” + actions “Changer de niveau” / “Reset”.

---

## 3) Historique — Liste + recherche

**Top**
- Titre : “Historique”
- Search bar : “Rechercher un mot (EN ou FR)”

**Section 1 — À rattraper**
- Liste des jours `pending` (date + aperçu EN/FR masqué partiellement)
- Badge “À rattraper”

**Section 2 — Tous les mots vus**
- Liste chronologique :
  - Date (petit)
  - EN (medium/bold)
  - FR (small)
  - Badge statut : `Vu` / `Appris`
- Tap item → écran détail

**États**
- Vide : “Pas encore d’historique. Reviens demain pour ton 1er mot.”
- Recherche sans résultat : “Aucun mot trouvé”.

---

## 4) Détail mot (depuis Historique)

**Header**
- Date + niveau

**Card**
- EN (large)
- FR (medium)
- Statut actuel (chip)

**Actions**
- “Marquer appris” (si pas appris)
- “À revoir” (si appris/vu)

---

## 5) Progression — Global + par niveau

**Top**
- Titre : “Progression”

**Card 1 — Aujourd’hui**
- “Mot du jour”
- Statut : `Non consulté` / `Vu` / `Appris`
- (Optionnel) streak : “Série : 3 jours”

**Card 2 — Global**
- Compteurs :
  - “Appris : X”
  - “Vus : Y”
  - “Restants : Z”
- Progress bar (X / 2000)

**Card 3 — Par niveau**
- 4 lignes (A1, A2, B1, B2) :
  - “A1 — appris X / total N”
  - mini barre de progression

---

## 6) Réglages

**Section — Niveau**
- Row : “Niveau actuel”
- Picker : A1 / A2 / B1 / B2
- Note : “Le mot déjà attribué aujourd’hui ne change pas.”

**Section — Notifications**
- Row : “Notifications”
  - État : Autorisées / Refusées
  - Si refusées : bouton “Ouvrir Réglages iOS”
- Row : “Heure du rappel”
  - Time picker (HH:mm)

**Section — Widget**
- Texte aide : “Ajoute le widget ‘Mot du jour’ sur ton écran d’accueil.”

**Section — Données**
- Bouton destructif : “Réinitialiser la progression”
- Confirmation modale : “Tout effacer ?”

