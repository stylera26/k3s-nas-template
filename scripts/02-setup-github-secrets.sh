#!/usr/bin/env bash
# ─── 02 — Configuration des secrets + variables GitHub ────────────────────────
# Configure via gh CLI tout ce dont la CI a besoin :
#
#  Variables (vars.*) :
#    PORTAINER_URL, PORTAINER_ENDPOINT_ID, HARBOR_REGISTRY, HARBOR_USERNAME
#
#  Secrets (secrets.*) :
#    PORTAINER_TOKEN    clé API Portainer (créer dans Portainer → User settings → API key)
#    HARBOR_PASSWORD    mot de passe robot Harbor (généré par script 01)
#    GH_PAT             GitHub PAT (créer sur github.com/settings/tokens)
#    APP_*              secrets applicatifs (DB, JWT, S3...)
#
# Prérequis :
#   - gh CLI installé et authentifié
#   - Avoir lancé 01-setup-harbor.sh (génère .harbor-credentials)

set -euo pipefail

echo "┌─────────────────────────────────────────────────┐"
echo "│  Setup GitHub Secrets & Variables               │"
echo "└─────────────────────────────────────────────────┘"
echo ""

# ── Charger credentials Harbor ────────────────────
if [ ! -f ".harbor-credentials" ]; then
  echo "❌ .harbor-credentials introuvable — lance 01-setup-harbor.sh d'abord"
  exit 1
fi
source .harbor-credentials

# ── Infos du projet ────────────────────────────────
read -rp "Organisation GitHub (ex: styleran) : " GH_ORG
read -rp "Repo(s) à configurer (space-separated) : " -a REPOS
read -rp "Niveau org [o] ou repo par repo [r] ? [o/r] : " LEVEL

# ── Portainer ──────────────────────────────────────
echo ""
echo "─── Portainer ────────────────────────────────────"
read -rp "URL Portainer (ex: https://portainer.sty.ovh) : " PORTAINER_URL
read -rp "Endpoint ID Portainer (ex: 1) : " ENDPOINT_ID
echo ""
echo "  → Portainer : User settings → API key → Generate"
read -rsp "Clé API Portainer : " PORTAINER_TOKEN
echo ""

# ── GitHub PAT ────────────────────────────────────
echo ""
echo "─── GitHub PAT ───────────────────────────────────"
echo "  → https://github.com/settings/tokens"
echo "  → Scopes : repo, workflow, read:org"
read -rsp "GitHub PAT : " GH_PAT_VALUE
echo ""

# ── Secrets applicatifs ───────────────────────────
echo ""
echo "─── Secrets applicatifs ──────────────────────────"
read -rsp "MongoDB root username : " APP_MONGO_USER; echo ""
read -rsp "MongoDB root password : " APP_MONGO_PASS; echo ""
read -rp  "MongoDB URI (ex: mongodb://user:pass@mongodb:27017/app?authSource=admin) : " APP_MONGO_URI
read -rsp "JWT secret (min 32 chars) : " APP_JWT; echo ""
read -rsp "MinIO access key : " APP_MINIO_AK; echo ""
read -rsp "MinIO secret key : " APP_MINIO_SK; echo ""

# ── Fonctions helper ──────────────────────────────
set_secret() {
  local repo="$1" name="$2" value="$3"
  if [ "$LEVEL" = "o" ]; then
    printf '%s' "$value" | gh secret set "$name" --org "$GH_ORG" --visibility all
    echo "  ✅ org secret: $name"
  else
    printf '%s' "$value" | gh secret set "$name" --repo "$GH_ORG/$repo"
    echo "  ✅ $repo secret: $name"
  fi
}

set_var() {
  local repo="$1" name="$2" value="$3"
  if [ "$LEVEL" = "o" ]; then
    gh variable set "$name" --org "$GH_ORG" --visibility all --body "$value"
    echo "  ✅ org var: $name"
  else
    gh variable set "$name" --repo "$GH_ORG/$repo" --body "$value"
    echo "  ✅ $repo var: $name"
  fi
}

apply_to() {
  local repo="$1"
  echo ""
  echo "▸ Configuration ${LEVEL == 'o' && 'org' || "$GH_ORG/$repo"}..."

  # Variables Portainer + Harbor
  set_var "$repo" "PORTAINER_URL"          "$PORTAINER_URL"
  set_var "$repo" "PORTAINER_ENDPOINT_ID"  "$ENDPOINT_ID"
  set_var "$repo" "HARBOR_REGISTRY"        "$HARBOR_REGISTRY"
  set_var "$repo" "HARBOR_USERNAME"        "$HARBOR_USERNAME"

  # Secrets CI
  set_secret "$repo" "PORTAINER_TOKEN"  "$PORTAINER_TOKEN"
  set_secret "$repo" "HARBOR_PASSWORD"  "$HARBOR_PASSWORD"
  set_secret "$repo" "GH_PAT"           "$GH_PAT_VALUE"

  # Secrets applicatifs
  set_secret "$repo" "APP_MONGODB_ROOT_USERNAME" "$APP_MONGO_USER"
  set_secret "$repo" "APP_MONGODB_ROOT_PASSWORD" "$APP_MONGO_PASS"
  set_secret "$repo" "APP_MONGODB_URI"           "$APP_MONGO_URI"
  set_secret "$repo" "APP_JWT_SECRET"            "$APP_JWT"
  set_secret "$repo" "APP_MINIO_ACCESS_KEY"      "$APP_MINIO_AK"
  set_secret "$repo" "APP_MINIO_SECRET_KEY"      "$APP_MINIO_SK"
}

# ── Appliquer ─────────────────────────────────────
if [ "$LEVEL" = "o" ]; then
  apply_to "org"
else
  for REPO in "${REPOS[@]}"; do
    apply_to "$REPO"
  done
fi

echo ""
echo "┌─────────────────────────────────────────────────┐"
echo "│  Secrets GitHub configurés !                    │"
echo "│                                                 │"
echo "│  Prochaine étape :                              │"
echo "│  → Lancer le workflow setup-secrets.yml         │"
echo "│    (push les secrets K8s via Portainer API)     │"
echo "│  → Lancer le workflow stack-deploy.yml          │"
echo "│    (déploie la stack via Portainer Git mode)    │"
echo "└─────────────────────────────────────────────────┘"
