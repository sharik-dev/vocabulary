# vocabulary

Application iOS développée en Swift / SwiftUI.

## Prérequis
- Xcode 15+
- iOS 17.0+

## Lancer le projet
Ouvre `vocabulary.xcodeproj` dans Xcode.

## Dataset (2000 mots)
- Fichier : `vocabulary/Resources/words.json`
- Génération (dataset de démo) : `python3 scripts/generate_words_json.py`

## Widget (App Group)
Pour que le widget puisse lire le mot du jour, active **App Groups** sur la target app + widget et utilise le même identifiant que dans `vocabulary/AppConstants.swift:5` et `dailyVocabulary/dailyVocabulary.swift:5`.
