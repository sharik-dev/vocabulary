# CI/CD → TestFlight

Pipeline : tu codes sur le **VPS Ubuntu** (Claude Code en SSH depuis ton tel) →
`git push` → **GitHub Actions** build sur un runner **macOS** → upload **TestFlight**.

> ⚠️ Le build iOS ne peut PAS tourner sur Linux. Le VPS sert uniquement à coder.
> La compilation se fait sur le runner macOS de GitHub Actions.

```
VPS Ubuntu (code)  →  git push  →  GitHub Actions (macOS: build+sign+upload)  →  TestFlight
```

---

## Fichiers de la pipeline (déjà committés)

| Fichier | Rôle |
|---|---|
| `fastlane/Appfile` | bundle id + team id |
| `fastlane/Matchfile` | config du stockage des certifs (repo match) |
| `fastlane/Fastfile` | lanes `beta` (CI) et `certificates` (bootstrap) |
| `Gemfile` | fige fastlane via bundler |
| `.github/workflows/testflight.yml` | workflow GitHub Actions (push sur `main` ou manuel) |
| `scripts/bootstrap-match.sh` | génère/pousse les certifs (à lancer 1x sur le Mac) |

---

## Étapes de configuration (une seule fois)

### 1. App Store Connect API Key
appstoreconnect.apple.com → **Users and Access** → **Integrations** → **App Store Connect API** → **+**
- Rôle : **App Manager** (ou Admin)
- Télécharge le fichier **`AuthKey_XXXXXXXXXX.p8`** (⚠️ téléchargeable une seule fois)
- Note le **Key ID** et l'**Issuer ID** (en haut de la page)

### 2. Repo privé pour les certificats (match)
Crée un repo **privé vide** (ex. `sharik-dev/certificates`) :
```bash
gh repo create sharik-dev/certificates --private
```

### 3. Bootstrap des certifs (sur le Mac, une fois)
```bash
cd vocabulary
# place le .p8 à la racine, puis édite les variables en haut du script :
nano scripts/bootstrap-match.sh    # MATCH_GIT_URL, MATCH_PASSWORD, ASC_KEY_ID, ASC_ISSUER_ID, P8_PATH
brew install fastlane              # si pas déjà installé
bash scripts/bootstrap-match.sh
```
Ça crée le certificat de distribution + les 2 profils et les pousse (chiffrés) dans le repo `certificates`.

### 4. Secrets GitHub Actions
Token d'accès au repo match pour la CI — un **PAT** (classic, scope `repo`) ou fine-grained sur `certificates` en lecture :
```bash
# remplace les valeurs ; ISSUER/KEY_ID viennent de l'étape 1, MATCH_PASSWORD de l'étape 3
gh secret set ASC_KEY_ID            --repo sharik-dev/vocabulary --body "XXXXXXXXXX"
gh secret set ASC_ISSUER_ID         --repo sharik-dev/vocabulary --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
gh secret set ASC_KEY_CONTENT       --repo sharik-dev/vocabulary --body "$(base64 -i AuthKey_XXXXXXXXXX.p8)"
gh secret set MATCH_GIT_URL         --repo sharik-dev/vocabulary --body "https://github.com/sharik-dev/certificates.git"
gh secret set MATCH_PASSWORD        --repo sharik-dev/vocabulary --body "ta-passphrase-match"

# auth HTTPS au repo match : base64 de "user:PAT"
gh secret set MATCH_GIT_BASIC_AUTHORIZATION --repo sharik-dev/vocabulary \
  --body "$(printf 'sharik-dev:ghp_XXXXXXXXXXXX' | base64)"
```

> Note : `MATCH_GIT_URL` en **HTTPS** ici (la CI s'authentifie via `MATCH_GIT_BASIC_AUTHORIZATION`).
> Pour le bootstrap local, le script utilise l'URL **SSH** car ta clé GitHub est déjà chargée.

### 5. App existante sur App Store Connect
- La fiche `com.vocabularyBySharik` doit exister (✅ déjà fait).
- Si l'app utilise des **App Groups / capabilities** sur l'extension, active-les sur les **App IDs** (Certificates, Identifiers & Profiles) avant le bootstrap, sinon les profils seront incomplets.

---

## Déclencher un build

- **Auto** : chaque `git push` sur `main`.
- **Manuel** : onglet **Actions** → workflow **TestFlight** → **Run workflow**.

Le build apparaît dans TestFlight après quelques minutes de traitement Apple.
Installe **TestFlight** sur ton iPhone, ajoute-toi comme testeur interne → tu reçois les builds.

---

## Workflow quotidien (depuis le tel via Terminus)
```bash
ssh vps-ubuntu          # clé github_new, passphrase vvvv
cd ~/vocabulary
claude                  # vibe-code
git add -A && git commit -m "..." && git push   # → déclenche la pipeline → TestFlight
```

---

## Dépannage
- **`No profiles for ... were found`** → relance le bootstrap (étape 3), ou capability manquante (étape 5).
- **`Authentication failed` sur match en CI** → `MATCH_GIT_BASIC_AUTHORIZATION` mal encodé (doit être `base64("user:PAT")`).
- **`Invalid API key`** → `ASC_KEY_CONTENT` doit être le `.p8` en base64 (la pipeline décode avec `is_key_content_base64: true`).
- **Build number rejeté** → géré automatiquement (dernier build TestFlight + 1).
