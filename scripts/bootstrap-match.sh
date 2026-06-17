#!/usr/bin/env bash
# Bootstrap UNIQUE à lancer sur le Mac (pas sur le VPS, pas en CI).
# Génère les certificats de distribution + provisioning profiles et les pousse
# (chiffrés) dans le repo match privé. À ne refaire que si les certifs expirent.
#
# Usage :
#   1) Crée un repo PRIVÉ vide pour les certifs (ex: sharik-dev/certificates)
#   2) Remplis les variables ci-dessous
#   3) bash scripts/bootstrap-match.sh
set -euo pipefail

# === À REMPLIR ===
export MATCH_GIT_URL="git@github.com:sharik-dev/certificates.git"   # repo PRIVÉ dédié aux certifs
export MATCH_PASSWORD="change-moi-passphrase-forte"                 # chiffre le contenu du repo match
export ASC_KEY_ID="XXXXXXXXXX"                                      # App Store Connect API Key ID
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"         # Issuer ID
P8_PATH="AuthKey_XXXXXXXXXX.p8"                                     # chemin vers le .p8 téléchargé
# =================

cd "$(dirname "$0")/.."

command -v fastlane >/dev/null || { echo "fastlane manquant : brew install fastlane"; exit 1; }
[ -f "$P8_PATH" ] || { echo "Fichier .p8 introuvable : $P8_PATH"; exit 1; }

export ASC_KEY_CONTENT="$(base64 -i "$P8_PATH")"

# Réutilise la lane 'certificates' du Fastfile (match readonly:false)
fastlane certificates

echo
echo "✅ Certifs + profils générés et poussés dans $MATCH_GIT_URL"
echo "   Profils créés (attendus par la CI) :"
echo "     - match AppStore com.vocabularyBySharik"
echo "     - match AppStore com.vocabularyBySharik.dailyVocabulary"
