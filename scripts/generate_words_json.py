#!/usr/bin/env python3
import json
from pathlib import Path


LEVELS = ["A1", "A2", "B1", "B2"]

# Small curated set to make the app feel real immediately.
# The remaining entries are placeholders meant to be replaced by your real 2000-word list.
REAL_WORDS = {
    "A1": [
        ("hello", "bonjour"),
        ("goodbye", "au revoir"),
        ("please", "s'il vous plaît"),
        ("thank you", "merci"),
        ("yes", "oui"),
        ("no", "non"),
        ("man", "homme"),
        ("woman", "femme"),
        ("child", "enfant"),
        ("friend", "ami"),
        ("family", "famille"),
        ("mother", "mère"),
        ("father", "père"),
        ("brother", "frère"),
        ("sister", "sœur"),
        ("dog", "chien"),
        ("cat", "chat"),
        ("water", "eau"),
        ("food", "nourriture"),
        ("bread", "pain"),
        ("milk", "lait"),
        ("coffee", "café"),
        ("tea", "thé"),
        ("apple", "pomme"),
        ("banana", "banane"),
        ("orange", "orange"),
        ("car", "voiture"),
        ("bus", "bus"),
        ("train", "train"),
        ("city", "ville"),
        ("school", "école"),
        ("work", "travail"),
        ("home", "maison"),
        ("day", "jour"),
        ("night", "nuit"),
        ("morning", "matin"),
        ("evening", "soir"),
        ("today", "aujourd'hui"),
        ("tomorrow", "demain"),
        ("yesterday", "hier"),
        ("one", "un"),
        ("two", "deux"),
        ("three", "trois"),
        ("red", "rouge"),
        ("blue", "bleu"),
        ("green", "vert"),
        ("black", "noir"),
        ("white", "blanc"),
        ("big", "grand"),
        ("small", "petit"),
        ("hot", "chaud"),
        ("cold", "froid"),
        ("happy", "heureux"),
        ("sad", "triste"),
        ("to go", "aller"),
        ("to come", "venir"),
        ("to eat", "manger"),
        ("to drink", "boire"),
        ("to read", "lire"),
        ("to write", "écrire"),
    ],
    "A2": [
        ("travel", "voyage"),
        ("ticket", "billet"),
        ("airport", "aéroport"),
        ("hotel", "hôtel"),
        ("reservation", "réservation"),
        ("price", "prix"),
        ("cheap", "bon marché"),
        ("expensive", "cher"),
        ("direction", "direction"),
        ("map", "carte"),
        ("street", "rue"),
        ("neighborhood", "quartier"),
        ("question", "question"),
        ("answer", "réponse"),
        ("to buy", "acheter"),
        ("to sell", "vendre"),
        ("to pay", "payer"),
        ("to wait", "attendre"),
        ("to need", "avoir besoin"),
        ("to want", "vouloir"),
        ("to like", "aimer"),
        ("to prefer", "préférer"),
        ("to start", "commencer"),
        ("to finish", "finir"),
        ("to open", "ouvrir"),
        ("to close", "fermer"),
        ("to help", "aider"),
        ("to learn", "apprendre"),
        ("to teach", "enseigner"),
        ("to understand", "comprendre"),
        ("to remember", "se souvenir"),
        ("to forget", "oublier"),
        ("health", "santé"),
        ("doctor", "médecin"),
        ("medicine", "médicament"),
        ("problem", "problème"),
        ("solution", "solution"),
        ("meeting", "réunion"),
        ("appointment", "rendez-vous"),
        ("to cook", "cuisiner"),
        ("to clean", "nettoyer"),
        ("to drive", "conduire"),
        ("to visit", "visiter"),
        ("to arrive", "arriver"),
        ("to leave", "partir"),
        ("message", "message"),
        ("email", "e-mail"),
        ("weather", "météo"),
        ("rain", "pluie"),
        ("sun", "soleil"),
    ],
    "B1": [
        ("environment", "environnement"),
        ("development", "développement"),
        ("decision", "décision"),
        ("experience", "expérience"),
        ("opportunity", "opportunité"),
        ("behavior", "comportement"),
        ("relationship", "relation"),
        ("evidence", "preuve"),
        ("challenge", "défi"),
        ("to achieve", "atteindre"),
        ("to improve", "améliorer"),
        ("to reduce", "réduire"),
        ("to increase", "augmenter"),
        ("to prevent", "empêcher"),
        ("to apply", "appliquer"),
        ("to recommend", "recommander"),
        ("to assume", "supposer"),
        ("to consider", "considérer"),
        ("to expect", "s'attendre à"),
        ("to manage", "gérer"),
        ("to solve", "résoudre"),
        ("to support", "soutenir"),
        ("to depend", "dépendre"),
        ("to recognize", "reconnaître"),
        ("to explain", "expliquer"),
        ("to compare", "comparer"),
        ("to create", "créer"),
        ("to develop", "développer"),
        ("to describe", "décrire"),
        ("to protect", "protéger"),
        ("to prepare", "préparer"),
        ("to organize", "organiser"),
        ("to suggest", "suggérer"),
        ("to decide", "décider"),
        ("goal", "objectif"),
        ("result", "résultat"),
        ("issue", "problème"),
        ("priority", "priorité"),
        ("strategy", "stratégie"),
        ("quality", "qualité"),
    ],
    "B2": [
        ("sustainability", "durabilité"),
        ("accountability", "responsabilité"),
        ("stakeholder", "partie prenante"),
        ("resilience", "résilience"),
        ("comprehensive", "complet"),
        ("to leverage", "exploiter"),
        ("to mitigate", "atténuer"),
        ("to optimize", "optimiser"),
        ("to evaluate", "évaluer"),
        ("to anticipate", "anticiper"),
        ("to advocate", "plaider pour"),
        ("to implement", "mettre en œuvre"),
        ("to negotiate", "négocier"),
        ("to facilitate", "faciliter"),
        ("to allocate", "allouer"),
        ("to prioritize", "prioriser"),
        ("to consolidate", "consolider"),
        ("to reinforce", "renforcer"),
        ("constraint", "contrainte"),
        ("trade-off", "compromis"),
        ("framework", "cadre"),
        ("guideline", "directive"),
        ("benchmark", "référence"),
        ("insight", "éclairage"),
    ],
}


def generate_words(total_per_level: int) -> list[dict]:
    out: list[dict] = []
    next_id = 1
    for level in LEVELS:
        reals = REAL_WORDS.get(level, [])
        count_real = min(len(reals), total_per_level)

        for en, fr in reals[:count_real]:
            out.append({"id": next_id, "en": en, "fr": fr, "level": level})
            next_id += 1

        remaining = total_per_level - count_real
        for i in range(remaining):
            idx = i + 1
            out.append(
                {
                    "id": next_id,
                    "en": f"word_{level.lower()}_{idx:04d}",
                    "fr": f"mot_{level.lower()}_{idx:04d}",
                    "level": level,
                }
            )
            next_id += 1
    return out


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    resources_dir = repo_root / "vocabulary" / "Resources"
    resources_dir.mkdir(parents=True, exist_ok=True)

    words = generate_words(total_per_level=500)  # 4 * 500 = 2000
    out_path = resources_dir / "words.json"
    out_path.write_text(json.dumps(words, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(words)} words to {out_path}")


if __name__ == "__main__":
    main()
