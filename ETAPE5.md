# Étape 5 — Pipeline CI/CD : GitHub Actions

## Objectif

Automatiser le cycle de vie de l'application : à chaque push sur `main`, le pipeline **build** l'image Docker, la **pousse** sur ECR, exécute un **test de charge** sur l'ALB, puis **déploie** en déclenchant un instance refresh sur l'Auto Scaling Group.

---

## Architecture

```
  ┌──────────────────────────────────────────────────────┐
  │                   GitHub (push → main)                │
  └─────────────────────────┬────────────────────────────┘
                            │ trigger
                            ▼
  ┌──────────────────────────────────────────────────────┐
  │              GitHub Actions Runner                    │
  │                                                       │
  │  Job 1 : build                                        │
  │  ├── docker build                                     │
  │  ├── docker push :sha + :latest → ECR                 │
  │                                                       │
  │  Job 2 : load-test  (si ALB_URL configuré)            │
  │  ├── npm install -g loadtest                          │
  │  └── loadtest --rps 100 -c 10 → ALB                   │
  │                                                       │
  │  Job 3 : deploy  (après build)                        │
  │  └── aws autoscaling start-instance-refresh → ASG     │
  └──────────────────────────────────────────────────────┘
                       |              |
                       ▼              ▼
             ┌─────────────┐   ┌──────────────────┐
             │  Amazon ECR  │   │  Auto Scaling     │
             │  :sha :latest│   │  Instance Refresh │
             └─────────────┘   └──────────────────┘
```

---

## Fichier `.github/workflows/ci-cd.yml`

### Jobs

| Job | Déclencheur | Rôle |
|---|---|---|
| `build` | push sur `main` | Build l'image Docker, pousse `:sha` et `:latest` sur ECR |
| `load-test` | après `build`, si `vars.ALB_URL` défini | Vérifie la performance de l'application via l'ALB |
| `deploy` | après `build` | Déclenche un instance refresh sur l'ASG (remplacement progressif, min 50% sain) |

### Variables d'environnement du workflow

| Variable | Valeur | Description |
|---|---|---|
| `AWS_REGION` | `us-east-1` | Région AWS |
| `ECR_REPOSITORY` | `student-app` | Nom du repository ECR |
| `ASG_NAME` | `student-app-asg` | Nom de l'Auto Scaling Group |

---

## Configuration GitHub

### 1. Secrets à créer (Settings → Secrets → Actions)

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS Academy |
| `AWS_SESSION_TOKEN` | Token de session AWS Academy (temporaire) |

> Dans AWS Academy : AWS Details → Show → copier les trois valeurs.

### 2. Variable à créer (Settings → Variables → Actions) — optionnel

| Variable | Valeur |
|---|---|
| `ALB_URL` | Valeur de `terraform output alb_url` |

Si `ALB_URL` n'est pas définie, le job `load-test` est automatiquement ignoré.

---

## Déploiement

### 1. S'assurer que l'infrastructure est déployée

```bash
terraform apply
terraform output alb_url        # → http://<alb_dns>
terraform output ecr_repository_url  # → <account>.dkr.ecr.us-east-1.amazonaws.com/student-app
```

### 2. Configurer les secrets GitHub

Dans l'interface GitHub → Settings → Secrets and variables → Actions :
- Ajouter `AWS_ACCESS_KEY_ID`
- Ajouter `AWS_SECRET_ACCESS_KEY`
- Ajouter `AWS_SESSION_TOKEN`

### 3. Déclencher le pipeline

```bash
git add .
git commit -m "feat: trigger ci-cd"
git push origin main
```

Le pipeline s'exécute automatiquement. Suivre l'avancement dans l'onglet **Actions** de GitHub.

### 4. Vérifier le déploiement

```bash
# Vérifier que l'instance refresh est en cours
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name student-app-asg \
  --query "InstanceRefreshes[0].Status"
```

---

## Améliorations vs étape 4

| Avant | Après Phase 5 |
|---|---|
| Build et push manuels | Automatisés à chaque push sur `main` |
| Déploiement manuel (terraform apply) | Instance refresh déclenché automatiquement |
| Aucun test de non-régression de performance | Test de charge intégré au pipeline |
| Risque de déployer une image non testée | Pipeline séquentiel : build → test → deploy |

## Limites restantes

- Les secrets AWS Academy expirent (~4h) et doivent être mis à jour manuellement à chaque session
- Le déploiement met à jour les EC2 (re-exécution du user data) mais pas encore les conteneurs Docker directement — adressé en Phase 6 (ECS)
