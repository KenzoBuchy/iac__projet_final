# Étape 4 — Packaging de l'application : Docker + ECR

## Objectif

Conteneuriser l'application Node.js dans une image **Docker** et la stocker dans **Amazon Elastic Container Registry (ECR)**. L'image devient un artefact versionné, reproductible, et déployable indépendamment de l'infrastructure.

---

## Architecture

```
  ┌──────────────────────────────────────────┐
  │              Poste développeur            │
  │                                           │
  │   docker build → image student-app        │
  │   docker run   → test local (port 80)     │
  └───────────────────┬──────────────────────┘
                      │ docker push
                      ▼
  ┌──────────────────────────────────────────┐
  │         Amazon ECR                        │
  │         Repository : student-app          │
  │         Tags : :latest  :<git-sha>        │
  └──────────────────────────────────────────┘
                      │ pull (Phase 5/6)
                      ▼
  ┌──────────────────────────────────────────┐
  │         EC2 / ECS / EKS                   │
  │         (déploiement Phase 5+)            │
  └──────────────────────────────────────────┘
```

---

## Composants

### `ecr.tf`

| Ressource | Valeur | Description |
|---|---|---|
| `aws_ecr_repository.app` | `student-app` | Repository ECR, tags mutables, suppression forcée autorisée |

### `Dockerfile`

| Instruction | Rôle |
|---|---|
| `FROM node:18-slim` | Image de base Node.js légère |
| `wget` / `unzip` | Télécharge le code source depuis S3 (même URL que le user data) |
| `npm install aws aws-sdk` | Installe les dépendances de l'application |
| `EXPOSE 80` | Documente le port d'écoute |
| `ENV APP_PORT=80` | Port utilisé par l'application Node.js |
| `CMD ["npm", "start"]` | Démarre l'application |

> L'application lit ses credentials DB depuis **Secrets Manager** au démarrage via l'AWS SDK.
> Le conteneur a donc besoin d'un IAM Role (sur EC2) ou de variables AWS au runtime — aucun credential dans l'image.

---

## Déploiement

### 1. Créer le repository ECR via Terraform

```bash
terraform apply
# Le repository ECR est créé avec les autres ressources
terraform output ecr_repository_url
# → <account_id>.dkr.ecr.us-east-1.amazonaws.com/student-app
```

### 2. Construire l'image Docker en local

```bash
docker build -t student-app .
```

### 3. Tester l'image en local

```bash
docker run -p 8080:80 \
  -e AWS_ACCESS_KEY_ID=<votre_key> \
  -e AWS_SECRET_ACCESS_KEY=<votre_secret> \
  -e AWS_SESSION_TOKEN=<votre_token> \
  -e AWS_DEFAULT_REGION=us-east-1 \
  student-app
```

Ouvrir `http://localhost:8080` pour vérifier que l'application répond.

### 4. Pousser l'image vers ECR

```bash
# Récupérer les URLs
# ecr_repository_url retourne : <account_id>.dkr.ecr.us-east-1.amazonaws.com/student-app
ECR_URL=$(terraform output -raw ecr_repository_url)

# docker login attend le registry seul (sans /student-app)
ECR_REGISTRY=$(echo $ECR_URL | cut -d/ -f1)

# S'authentifier auprès du registry ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin $ECR_REGISTRY

# Tagger et pousser
docker tag student-app:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

### 5. Tester sur une instance EC2

Sur une instance EC2 avec `LabInstanceProfile` :

```bash
# Installer Docker
sudo apt-get update && sudo apt-get install -y docker.io
sudo systemctl start docker

# Récupérer les coordonnées ECR (le rôle IAM de l'instance authentifie automatiquement)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
ECR_URL="${ECR_REGISTRY}/student-app"

# S'authentifier auprès du registry (registry seul, pas l'URL du repo)
aws ecr get-login-password --region us-east-1 \
  | sudo docker login --username AWS --password-stdin $ECR_REGISTRY

# Lancer le conteneur
sudo docker run -d -p 80:80 $ECR_URL:latest
```

---

## Améliorations vs étape 3

| Avant | Après Phase 4 |
|---|---|
| Déploiement via user data (long, non versionné) | Image Docker versionnée et reproductible |
| Dépendances téléchargées à chaque démarrage | Dépendances embarquées dans l'image |
| Impossible de rollback rapide | `docker pull :sha` pour revenir à une version précise |

## Limites restantes

- Le build et le push de l'image sont manuels
- Aucune automatisation du déploiement vers l'ASG
