# k3s-nas-template

Template pour déployer un projet (front + back + DB + S3) sur un cluster K3s
avec Harbor (registry) et Portainer (orchestration).

> **Prérequis** : K3s + Traefik + Portainer + Longhorn + Harbor déjà installés sur le NAS.

---

## Secrets — inventaire complet

### GitHub Variables (`vars.*`)
| Variable | Valeur | Créé par |
|----------|--------|----------|
| `PORTAINER_URL` | `https://portainer.sty.ovh` | Script 02 |
| `PORTAINER_ENDPOINT_ID` | `1` | Script 02 |
| `HARBOR_REGISTRY` | `registry.sty.ovh` | Script 02 (via 01) |
| `HARBOR_USERNAME` | `robot$gh-monapp` | Script 02 (via 01) |

### GitHub Secrets (`secrets.*`)
| Secret | Description | Créé par |
|--------|-------------|----------|
| `PORTAINER_TOKEN` | Clé API Portainer | ⚠️ Manuel → Portainer UI → User settings → API key |
| `HARBOR_PASSWORD` | Mot de passe robot Harbor | ✅ Script 01 → Script 02 |
| `GH_PAT` | GitHub PAT (repo + workflow) | ⚠️ Manuel → github.com/settings/tokens |
| `APP_MONGODB_ROOT_USERNAME` | Username MongoDB | ✅ Script 02 |
| `APP_MONGODB_ROOT_PASSWORD` | Password MongoDB | ✅ Script 02 |
| `APP_MONGODB_URI` | URI de connexion MongoDB | ✅ Script 02 |
| `APP_JWT_SECRET` | Secret JWT (min 32 chars) | ✅ Script 02 |
| `APP_MINIO_ACCESS_KEY` | Access key MinIO | ✅ Script 02 |
| `APP_MINIO_SECRET_KEY` | Secret key MinIO | ✅ Script 02 |

### Seulement 2 choses manuelles
- **`PORTAINER_TOKEN`** → Portainer UI → ton compte → API keys → Generate
- **`GH_PAT`** → github.com/settings/tokens → repo + workflow + read:org

---

## Deploy order — de zéro à prod

```
01-setup-harbor.sh          # Harbor : projet + robot account
02-setup-github-secrets.sh  # GitHub : tous les secrets + variables
↓
GitHub Actions : setup-secrets.yml   # K8s Secrets poussés via Portainer API
GitHub Actions : stack-deploy.yml    # Stack déployée via Portainer Git mode
```

### Étape 1 — Créer projet Harbor + robot account
```bash
./scripts/01-setup-harbor.sh
# Saisir : nom du projet, mot de passe admin Harbor
# Génère : .harbor-credentials (ignoré par git)
```

### Étape 2 — Configurer tous les secrets GitHub
```bash
./scripts/02-setup-github-secrets.sh
# Saisir : org GH, repos, URL Portainer, PORTAINER_TOKEN, GH_PAT, secrets DB/JWT/S3
# Configure : variables + secrets dans GitHub via gh CLI
```

### Étape 3 — Adapter le stack manifest
```bash
cp stacks/app-stack.yml stacks/mon-app-stack.yml
# Remplacer APP_NAME, APP_DOMAIN, APP_REGISTRY, APP_REGISTRY_PROJECT
```

### Étape 4 — Pousser les secrets K8s via Portainer API
```
GitHub Actions → setup-secrets.yml → Run workflow
# Crée dans K8s : APP_NAME-secrets + harbor-credentials
# Via : Portainer API → pas besoin de kubeconfig
```

### Étape 5 — Déployer la stack via Portainer
```
GitHub Actions → stack-deploy.yml → Run workflow
# Portainer suit le repo Git IAC → pull + déploie
# Mode Git repository : visible dans Portainer UI → Stacks
```

### Étape 6 — DNS
Pointer les sous-domaines vers l'IP du nœud K3s :
```
api.MON_DOMAINE   → IP_K3S
app.MON_DOMAINE   → IP_K3S
minio.MON_DOMAINE → IP_K3S
s3.MON_DOMAINE    → IP_K3S
```

---

## Structure du template

```
k3s-nas-template/
├── stacks/
│   ├── app-stack.yml               # K8s manifests (back, front, MongoDB, MinIO + ingresses)
│   └── app-secrets.yaml.example    # Référence des clés (valeurs dans GitHub secrets)
├── scripts/
│   ├── 01-setup-harbor.sh          # Crée projet + robot account Harbor (API)
│   └── 02-setup-github-secrets.sh  # Configure tous les secrets/vars GitHub (gh CLI)
└── .github/workflows/
    ├── setup-secrets.yml           # Push K8s Secrets via Portainer API (workflow_dispatch)
    ├── stack-deploy.yml            # Déploie stack via Portainer Git mode
    ├── docker-build-push.yml       # Réutilisable : build & push Harbor
    ├── ci-nextjs.yml               # Réutilisable : lint + build Next.js
    ├── ci-kotlin.yml               # Réutilisable : lint + build Kotlin
    └── app-ci-example.yml          # Exemple CI complet à copier dans les repos d'app
```

---

## Comment adapter pour un nouveau projet

1. **Remplacer dans `app-stack.yml`** : `APP_NAME`, `APP_DOMAIN`, `APP_REGISTRY`, `APP_REGISTRY_PROJECT`
2. **Remplacer dans `setup-secrets.yml`** : `APP_NAME` (namespace + nom du secret)
3. **Remplacer dans `stack-deploy.yml`** : `APP_NAME`, `MON_ORG/MON_IAC`, liste des deployments
4. **Lancer les 2 scripts** puis les **2 workflows GitHub Actions**
