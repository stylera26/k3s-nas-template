#!/usr/bin/env bash
# ─── 01 — Création projet Harbor + compte robot ───────────────────────────────
# Crée automatiquement via l'API Harbor :
#   - Un projet privé pour l'application
#   - Un robot account avec push/pull access
#   - Sauvegarde les credentials dans .harbor-credentials (ignoré par git)
#
# Usage :
#   ./scripts/01-setup-harbor.sh

set -euo pipefail

HARBOR_URL="${HARBOR_URL:-https://registry.sty.ovh}"
HARBOR_ADMIN="${HARBOR_ADMIN:-admin}"

echo "┌─────────────────────────────────────────────┐"
echo "│  Setup Harbor — projet + robot account      │"
echo "└─────────────────────────────────────────────┘"
echo ""
echo "  Harbor : $HARBOR_URL"
echo ""

read -rp "  Nom du projet (ex: stylera, orion) : " PROJECT_NAME
read -rsp "  Mot de passe admin Harbor : " HARBOR_ADMIN_PASS
echo ""

ROBOT_NAME="robot\$gh-${PROJECT_NAME}"

# ── 1. Créer le projet Harbor ──────────────────
echo ""
echo "▸ Création du projet '$PROJECT_NAME'..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_ADMIN}:${HARBOR_ADMIN_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_name\": \"${PROJECT_NAME}\",
    \"public\": false,
    \"metadata\": { \"public\": \"false\" }
  }")

if [ "$HTTP_CODE" = "201" ]; then
  echo "  ✅ Projet '$PROJECT_NAME' créé"
elif [ "$HTTP_CODE" = "409" ]; then
  echo "  ℹ️  Projet '$PROJECT_NAME' existe déjà"
else
  echo "  ❌ Erreur HTTP $HTTP_CODE lors de la création du projet"
  exit 1
fi

# ── 2. Créer le robot account ──────────────────
echo ""
echo "▸ Création du robot account '${ROBOT_NAME}'..."

ROBOT_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${HARBOR_URL}/api/v2.0/robots" \
  -u "${HARBOR_ADMIN}:${HARBOR_ADMIN_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"gh-${PROJECT_NAME}\",
    \"description\": \"GitHub Actions CI/CD for ${PROJECT_NAME}\",
    \"duration\": -1,
    \"level\": \"project\",
    \"permissions\": [
      {
        \"kind\": \"project\",
        \"namespace\": \"${PROJECT_NAME}\",
        \"access\": [
          { \"resource\": \"repository\", \"action\": \"push\" },
          { \"resource\": \"repository\", \"action\": \"pull\" },
          { \"resource\": \"artifact\",   \"action\": \"delete\" }
        ]
      }
    ]
  }")

HTTP_CODE=$(echo "$ROBOT_RESPONSE" | tail -1)
ROBOT_BODY=$(echo "$ROBOT_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "201" ]; then
  ROBOT_SECRET=$(echo "$ROBOT_BODY" | grep -o '"secret":"[^"]*"' | cut -d'"' -f4)
  ROBOT_ID=$(echo "$ROBOT_BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

  echo "  ✅ Robot account créé (ID: $ROBOT_ID)"
  echo ""
  echo "  Username : ${ROBOT_NAME}"
  echo "  Password : ${ROBOT_SECRET}"

  # Sauvegarder les credentials
  cat > .harbor-credentials <<EOF
HARBOR_USERNAME=${ROBOT_NAME}
HARBOR_PASSWORD=${ROBOT_SECRET}
HARBOR_REGISTRY=${HARBOR_URL#https://}
HARBOR_PROJECT=${PROJECT_NAME}
EOF

  echo ""
  echo "  ✅ Credentials sauvegardés dans .harbor-credentials"
  echo "     → Lance ensuite : ./scripts/02-setup-github-secrets.sh"

else
  echo "  ❌ Erreur HTTP $HTTP_CODE lors de la création du robot"
  echo "  Réponse : $ROBOT_BODY"
  exit 1
fi

echo ""
echo "┌─────────────────────────────────────────────┐"
echo "│  Harbor configuré !                         │"
echo "│                                             │"
echo "│  Projet  : ${PROJECT_NAME}"
echo "│  Robot   : ${ROBOT_NAME}"
echo "│  Registry: ${HARBOR_URL#https://}/${PROJECT_NAME}/"
echo "└─────────────────────────────────────────────┘"