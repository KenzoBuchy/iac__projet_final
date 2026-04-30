# Projet Final IaC — Université Exemple : Application de gestion des dossiers étudiants

**Auteurs :** Noa Brevet, Kenzo Buchy  
**Formation :** ESGI Master 2 — Infrastructure as Code  
**Cloud :** AWS (us-east-1)  
**Outil IaC :** Terraform

---

## Contexte

L'Université Exemple fait face à des problèmes de performance et de disponibilité de son application web de gestion des dossiers étudiants lors des pics d'admission. L'objectif est de migrer cette application vers AWS en suivant les bonnes pratiques du **AWS Well-Architected Framework**, en plusieurs phases progressives.

**Exigences clés de la solution :**
- Fonctionnelle (CRUD sur les dossiers étudiants)
- Hautement disponible et scalable
- Sécurisée (DB non accessible depuis Internet, credentials non codés en dur)
- Optimisée en coûts

---

## Évolution de l'architecture

| Phase | Objectif | Statut |
|---|---|---|
| Phase 1 | POC — Application monolithique sur EC2 | ✅ Terminée |
| Phase 2 | Découplage — RDS + Secrets Manager | ✅ Terminée |
| Phase 3 | Haute disponibilité — ALB + Auto Scaling | ✅ Terminée |
| Phase 4 | Packaging de l'application — Docker + ECR | ✅ Terminée |
| Phase 5 | Pipeline CI/CD — GitHub Actions | ✅ Terminée |
| Phase 6 | Orchestrateur de conteneurs | 🔜 À venir |
| Phase 7 | Amélioration et Optimisation | 🔜 À venir |

---

## Phase 1 — POC : Application monolithique sur EC2

### Objectif

Déployer une première version fonctionnelle de l'application sur une seule instance EC2. Node.js et MySQL tournent sur la même machine. C'est la preuve de concept initiale.

### Architecture

```
         INTERNET
            |
     (HTTP:80 / SSH:22)
            |
   [Security Group: app_sg]
            |
   ┌────────────────────┐
   │   EC2 t3.micro     │
   │   Ubuntu 24.04     │
   │                    │
   │  Node.js (port 80) │
   │  MySQL (local)     │
   └────────────────────┘
```

### Infrastructure déployée (Terraform)

- **Security Group** : ports 80 (HTTP) et 22 (SSH) ouverts
- **EC2** `student-poc-server` : Ubuntu, t3.micro, user data = `solution_code_poc.sh`

### Preuves de déploiement

**Instance EC2 en cours d'exécution**

![EC2 Phase 1](images/phase1_ec2.png)

**Application accessible depuis Internet**

![App Phase 1](images/phase1_app.png)

**Security Group configuré**

![Security Group Phase 1](images/phase1_sg.png)

### Améliorations apportées vs situation initiale

| Avant | Après Phase 1 |
|---|---|
| Hébergement on-premise | Hébergé sur AWS (disponibilité du cloud) |
| Infrastructure manuelle | Infrastructure as Code avec Terraform |
| — | Déploiement reproductible en 1 commande |

### Limites identifiées

- Single Point of Failure : si l'EC2 tombe, tout est indisponible
- Base de données locale : données perdues si l'instance est détruite
- Credentials en clair dans le script de démarrage
- Pas de réseau virtuel dédié

---

## Phase 2 — Découplage : RDS + Secrets Manager

### Objectif

Séparer la base de données du serveur web. La DB migre vers **Amazon RDS** (service managé, sous-réseau privé). Les credentials sont stockés dans **AWS Secrets Manager**. Un VPC dédié avec sous-réseaux publics et privés est mis en place.

### Architecture

```
                      INTERNET
                         |
               [Internet Gateway]
                         |
    ┌────────────────────────────────────────┐
    │           VPC  10.0.0.0/16             │
    │                                        │
    │  ┌──────────────────────────────────┐  │
    │  │  Sous-réseau PUBLIC              │  │
    │  │  10.0.1.0/24  (us-east-1a)       │  │
    │  │                                  │  │
    │  │  [EC2 POC]  [Cloud9]             │  │
    │  │  [EC2 App Server → RDS]          │  │
    │  └──────────────────────────────────┘  │
    │                   │ MySQL:3306          │
    │  ┌──────────────────────────────────┐  │
    │  │  Sous-réseau PRIVÉ               │  │
    │  │  10.0.3.0/24  (us-east-1a)       │  │
    │  │  [RDS MySQL 8.0]                 │  │
    │  └──────────────────────────────────┘  │
    │                                        │
    │  ┌──────────────────────────────────┐  │
    │  │  Sous-réseau PRIVÉ               │  │
    │  │  10.0.4.0/24  (us-east-1b)       │  │
    │  │  (réservé RDS subnet group)      │  │
    │  └──────────────────────────────────┘  │
    └────────────────────────────────────────┘

         ┌─────────────────────────┐
         │    Secrets Manager      │
         │    Secret: Mydbsecret   │
         │    user/password/host/db│
         └─────────────────────────┘
```

### Infrastructure déployée (Terraform)

| Ressource | Détail |
|---|---|
| VPC | `10.0.0.0/16`, DNS activé |
| Subnets publics | `10.0.1.0/24` (1a) + `10.0.2.0/24` (1b) |
| Subnets privés | `10.0.3.0/24` (1a) + `10.0.4.0/24` (1b) |
| Internet Gateway | Route `0.0.0.0/0` vers subnets publics |
| Security Group app | HTTP:80 + SSH:22 depuis Internet |
| Security Group RDS | MySQL:3306 depuis `app_sg` uniquement |
| RDS MySQL 8.0 | `db.t3.micro`, sous-réseau privé, non accessible publiquement |
| Secrets Manager | Secret `Mydbsecret` avec credentials DB |
| IAM | `LabInstanceProfile` (pré-existant AWS Academy) |
| Cloud9 | `t3.micro`, Amazon Linux 2023, pour scripts CLI |
| EC2 POC | `student-poc-server` — conservé pour migration des données |
| EC2 App Server | `student-app-server` — se connecte à RDS via Secrets Manager |

### Preuves de déploiement

**VPC et sous-réseaux créés**

![VPC & Subnets](images/phase2_vpc_subnets.png)

**Instance RDS disponible**

![RDS](images/phase2_rds.png)

**Secret créé dans Secrets Manager**

![Secrets Manager](images/phase2_secret_manager.png)

**Environnement Cloud9**

![Cloud9](images/phase2_cloud9.png)

**Instances EC2 (POC + App Server)**

![EC2 Phase 2](images/phase2_ec2.png)

**Application accessible et fonctionnelle**

![App Phase 2](images/phase2_app.png)

### Migration des données (Script-3)

Les données de la base MySQL locale (EC2 POC) ont été exportées puis importées dans RDS via Cloud9 :

```bash
# Export depuis le serveur POC
mysqldump -h <poc_private_ip> -u nodeapp -p --databases STUDENTS > data.sql

# Import dans RDS
mysql -h <rds_endpoint> -u nodeapp -p STUDENTS < data.sql
```

### Améliorations apportées vs Phase 1

| Problème Phase 1 | Solution Phase 2 |
|---|---|
| DB locale, données perdues si EC2 détruite | RDS managé avec stockage persistant |
| Credentials en clair dans le script | Secrets Manager — aucun credential en dur |
| Pas de réseau dédié | VPC custom avec séparation public/privé |
| DB accessible depuis Internet (bind 0.0.0.0) | RDS en sous-réseau privé, inaccessible publiquement |
| App et DB couplées sur la même machine | Composants découplés et indépendants |

### Limites restantes

- Single Point of Failure sur l'EC2 App Server
- Pas de load balancing
- Pas de mise à l'échelle automatique

---

## Phase 3 — Haute disponibilité : ALB + Auto Scaling

### Objectif

Éliminer le Single Point of Failure en déployant un **Application Load Balancer** devant un **Auto Scaling Group**. L'application est désormais multi-AZ, résiliente aux pannes d'instance, et capable de s'adapter automatiquement à la charge.

### Architecture

```
                            INTERNET
                               |
                          (HTTP:80)
                               |
                    ┌──────────────────────┐
                    │    Internet Gateway   │
                    └──────────┬───────────┘
                               |
          ┌────────────────────────────────────────┐
          │              VPC  10.0.0.0/16          │
          │                                        │
          │  [ALB student-app-alb]                 │
          │       /               \                │
          │  ┌──────────────┐  ┌──────────────┐   │
          │  │ PUBLIC 1a    │  │ PUBLIC 1b    │   │
          │  │ 10.0.1.0/24  │  │ 10.0.2.0/24  │   │
          │  │ ASG inst. 1  │  │ ASG inst. 2  │   │
          │  └──────┬───────┘  └──────┬───────┘   │
          │         └────────┬─────────┘           │
          │              MySQL:3306                 │
          │  ┌─────────────────────────────────┐   │
          │  │  PRIVÉ 1a  10.0.3.0/24          │   │
          │  │  [RDS MySQL 8.0]                 │   │
          │  └─────────────────────────────────┘   │
          └────────────────────────────────────────┘

              ┌───────────────────────┐
              │   AWS Secrets Manager  │
              │   Secret: Mydbsecret   │
              └───────────────────────┘
```

### Infrastructure déployée (Terraform)

| Ressource | Détail |
|---|---|
| Security Group ALB | `student-alb-sg` — port 80 depuis Internet |
| ALB | `student-app-alb`, multi-AZ (public_1 + public_2) |
| Target Group | HTTP:80, health check sur `/`, seuil 2/2 |
| Listener HTTP | Port 80 → forward vers le target group |
| Launch Template | AMI Ubuntu t3.micro, user data `code_serveur_app.sh`, `LabInstanceProfile` |
| Auto Scaling Group | min=1 / desired=2 / max=3, health check ELB, grace period 300s |
| Scaling Policy | Target Tracking CPU 50% — scale-out et scale-in automatiques |

### Améliorations apportées vs Phase 2

| Problème Phase 2 | Solution Phase 3 |
|---|---|
| Single Point of Failure sur l'EC2 | ASG — panne d'instance absorbée automatiquement |
| Pas de load balancing | ALB distribue le trafic entre toutes les instances saines |
| Scalabilité manuelle | Target Tracking CPU 50% → scale-out/in automatique |
| Une seule AZ pour le web | Instances réparties sur us-east-1a et us-east-1b |

### Limites restantes

- Application distribuée via user data (non versionné, démarrage ~5 min par instance)
- Pas de pipeline de déploiement continu

---

## Phase 4 — Packaging : Docker + ECR

### Objectif

Conteneuriser l'application dans une **image Docker** versionnée et la stocker dans **Amazon ECR**. L'image devient un artefact reproductible, portable et déployable indépendamment de l'infrastructure.

### Infrastructure déployée (Terraform)

| Ressource | Détail |
|---|---|
| ECR Repository | `student-app`, tags mutables, `force_delete = true` |

### Composants applicatifs

| Fichier | Rôle |
|---|---|
| `Dockerfile` | `node:18-slim`, télécharge l'app depuis S3, installe les dépendances Node.js, expose le port 80 |

> L'image ne contient aucun credential. L'application lit les secrets DB depuis **Secrets Manager** au démarrage via l'AWS SDK — elle a besoin d'un IAM Role (sur EC2) ou de variables AWS en environnement local.

### Améliorations apportées vs Phase 3

| Avant | Après Phase 4 |
|---|---|
| Dépendances téléchargées à chaque démarrage d'instance (~5 min) | Image pré-construite, démarrage en quelques secondes |
| Pas de versioning de l'artefact applicatif | Chaque image taguée `:<sha>` permet un rollback précis |
| Impossible de tester l'app hors AWS | `docker run` local avec credentials AWS injectés |

### Limites restantes

- Build et push manuels
- L'ASG utilise encore le user data (pas l'image Docker directement)

---

## Phase 5 — Pipeline CI/CD : GitHub Actions

N'as pas eu le temps d'être tester. Le dernier run ai fail du à un manque de configuration de secret.

### Objectif

Automatiser le cycle complet : **build → test de charge → déploiement**. À chaque push sur `main`, l'image Docker est reconstruite, poussée sur ECR, un test de charge est exécuté sur l'ALB, puis un instance refresh est déclenché sur l'ASG.

### Pipeline

| Job | Déclencheur | Rôle |
|---|---|---|
| `build` | push sur `main` | Build Docker, push `:sha` + `:latest` sur ECR |
| `load-test` | après `build` (si `ALB_URL` configuré) | Test de charge sur l'ALB via `loadtest` |
| `deploy` | après `build` | Instance refresh ASG — remplacement progressif (min 50% sain) |

### Améliorations apportées vs Phase 4

| Avant | Après Phase 5 |
|---|---|
| Build et push manuels | Déclenchés automatiquement à chaque push sur `main` |
| Déploiement manuel | Instance refresh automatique après succès du build |
| Aucun test de non-régression | Test de charge intégré avant le déploiement |
| Risque de déployer sans vérification | Pipeline séquentiel : build → test → deploy |

### Limites restantes

- Secrets AWS Academy (~4h de validité) à mettre à jour manuellement à chaque session
- Les instances EC2 exécutent le user data (pas le conteneur Docker) — adressé en Phase 6 avec ECS

---

## Commandes Terraform

```bash
# Initialiser le projet
terraform init

# Visualiser les changements
terraform plan

# Déployer l'infrastructure
terraform apply

# Récupérer les outputs (IPs, URL app, endpoint RDS, URL ALB, URL ECR)
terraform output

# Détruire l'infrastructure
terraform destroy
```

---

## Structure du projet

```
projet_final/
├── providers.tf             # Provider AWS ~5.0, région depuis variable
├── variables.tf             # Variables : région, type instance, credentials DB
├── outputs.tf               # Outputs : IPs, URLs app/ALB, endpoint RDS, URL ECR
├── network.tf               # VPC, Internet Gateway, 4 subnets, route table publique
├── security_groups.tf       # app_sg (HTTP+SSH), rds_sg (MySQL depuis app_sg)
├── ec2.tf                   # EC2 poc_server (Phase 1) + app_server (Phase 2)
├── rds.tf                   # RDS MySQL 8.0 db.t3.micro + subnet group
├── secrets.tf               # Secrets Manager : Mydbsecret (user/password/host/db)
├── iam.tf                   # Data source LabInstanceProfile (pré-existant AWS Academy)
├── cloud9.tf                # Cloud9 Amazon Linux 2023 pour scripts CLI
├── alb.tf                   # ALB + alb_sg + Target Group + Listener (Phase 3)
├── asg.tf                   # Launch Template + Auto Scaling Group + Scaling Policy (Phase 3)
├── ecr.tf                   # ECR Repository student-app (Phase 4)
├── Dockerfile               # Image Docker de l'application Node.js (Phase 4)
├── .github/
│   └── workflows/
│       └── ci-cd.yml        # Pipeline CI/CD GitHub Actions (Phase 5)
├── scripts/
│   ├── solution_code_poc.sh # User data Phase 1 : Node.js + MySQL local
│   └── code_serveur_app.sh  # User data Phase 2/3 : Node.js → RDS via Secrets Manager
├── docs/
│   └── cloud9-scripts.yml   # Scripts CLI (Script-1 : secret, Script-2 : load test, Script-3 : migration)
├── ETAPE1.md                # Documentation technique Phase 1
├── ETAPE2.md                # Documentation technique Phase 2
├── ETAPE3.md                # Documentation technique Phase 3
├── ETAPE4.md                # Documentation technique Phase 4
├── ETAPE5.md                # Documentation technique Phase 5
├── README.md                # Ce document — synthèse globale
└── images/                  # Captures d'écran des preuves de déploiement
```
