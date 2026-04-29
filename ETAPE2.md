# Étape 2 — Découplage des composants : RDS + Secrets Manager

## Objectif

Séparer la base de données du serveur web. La DB tourne maintenant sur **Amazon RDS** (service managé) dans un sous-réseau privé. L'application récupère ses credentials depuis **AWS Secrets Manager** au lieu de les avoir en dur. Un environnement **Cloud9** permet d'exécuter les scripts CLI de migration.

---

## Architecture

```
                            INTERNET
                               |
                     (HTTP :80 / SSH :22)
                               |
                    ┌──────────────────────┐
                    │    Internet Gateway   │
                    └──────────┬───────────┘
                               |
          ┌────────────────────────────────────────┐
          │              VPC  10.0.0.0/16          │
          │                                        │
          │  ┌─────────────────────────────────┐   │
          │  │     Sous-réseau PUBLIC           │   │
          │  │  us-east-1a  10.0.1.0/24        │   │
          │  │                                  │   │
          │  │  ┌──────────────┐  ┌──────────┐  │   │
          │  │  │  EC2 POC     │  │  Cloud9  │  │   │
          │  │  │  (migration) │  │          │  │   │
          │  │  └──────────────┘  └──────────┘  │   │
          │  │                                  │   │
          │  │  ┌──────────────────────────┐    │   │
          │  │  │  EC2 App Server (Phase2) │    │   │
          │  │  │  Node.js :80             │    │   │
          │  │  │  IAM Role → Secrets Mgr  │    │   │
          │  │  └──────────────────────────┘    │   │
          │  └─────────────────────────────────┘   │
          │                    │                    │
          │          MySQL :3306 (privé)            │
          │                    │                    │
          │  ┌─────────────────────────────────┐   │
          │  │     Sous-réseau PRIVÉ            │   │
          │  │  us-east-1a  10.0.3.0/24        │   │
          │  │                                  │   │
          │  │  ┌──────────────────────────┐    │   │
          │  │  │    RDS MySQL 8.0          │    │   │
          │  │  │    DB : STUDENTS          │    │   │
          │  │  └──────────────────────────┘    │   │
          │  └─────────────────────────────────┘   │
          │                                        │
          │  ┌─────────────────────────────────┐   │
          │  │     Sous-réseau PRIVÉ            │   │
          │  │  us-east-1b  10.0.4.0/24        │   │
          │  │  (requis par RDS subnet group)   │   │
          │  └─────────────────────────────────┘   │
          └────────────────────────────────────────┘

                    ┌───────────────────────┐
                    │   AWS Secrets Manager  │
                    │   Secret: Mydbsecret   │
                    │   user / password /    │
                    │   host / db            │
                    └───────────────────────┘
```

### Flux de données

1. L'utilisateur accède à `http://<IP_APP_SERVER>` (port 80)
2. L'EC2 App Server démarre et appelle **Secrets Manager** via son IAM Role pour récupérer les credentials DB
3. Node.js se connecte à **RDS MySQL** en sous-réseau privé via le endpoint RDS
4. RDS n'est jamais accessible depuis Internet (sous-réseau privé + security group restrictif)

---

## Nouveaux composants Terraform

### Réseau

| Ressource | CIDR / AZ | Rôle |
|---|---|---|
| `aws_vpc.main` | `10.0.0.0/16` | VPC dédié au projet |
| `aws_internet_gateway.igw` | — | Accès Internet pour les sous-réseaux publics |
| `aws_subnet.public_1` | `10.0.1.0/24` / us-east-1a | EC2 + Cloud9 |
| `aws_subnet.public_2` | `10.0.2.0/24` / us-east-1b | Réservé pour le load balancer (Phase 3) |
| `aws_subnet.private_1` | `10.0.3.0/24` / us-east-1a | RDS |
| `aws_subnet.private_2` | `10.0.4.0/24` / us-east-1b | RDS (2e AZ requise) |
| `aws_route_table.public` | — | Route `0.0.0.0/0` vers l'IGW |

### Security Groups

| Ressource | Règles entrantes | Rôle |
|---|---|---|
| `aws_security_group.app_sg` | 80 (HTTP) + 22 (SSH) depuis Internet | Serveurs web |
| `aws_security_group.rds_sg` | 3306 depuis `app_sg` + 3306 depuis `10.0.0.0/16` (migration) | RDS MySQL |

### RDS

| Ressource | Valeur | Description |
|---|---|---|
| `aws_db_instance.mysql` | `db.t3.micro` / MySQL 8.0 | Base de données managée |
| `aws_db_subnet_group.rds_subnet_group` | private_1 + private_2 | Subnets privés pour RDS |

### Secrets Manager + IAM

| Ressource | Rôle |
|---|---|
| `aws_secretsmanager_secret.db_secret` | Stocke `user/password/host/db` au format JSON |
| `aws_iam_role.ec2_role` | Rôle assumé par l'EC2 App Server |
| `aws_iam_role_policy.secrets_policy` | Autorise `secretsmanager:GetSecretValue` sur le secret |
| `aws_iam_instance_profile.ec2_profile` | Attache le rôle IAM à l'instance EC2 |

### EC2

| Ressource | User Data | Rôle |
|---|---|---|
| `aws_instance.poc_server` | `solution_code_poc.sh` | Serveur POC Phase 1 — conservé pour la migration |
| `aws_instance.app_server` | `code_serveur_app.sh` | Serveur Phase 2 — se connecte à RDS via Secrets Manager |

---

## Déploiement

### 1. Lancer terraform apply

```bash
terraform apply
# Terraform demande : var.db_password → entrer le mot de passe RDS (ex: student12)
```

> RDS met **~10 minutes** à se provisionner. Terraform attend automatiquement.

### 2. Récupérer les outputs

```bash
terraform output
```

Noter :
- `poc_server_private_ip` → utilisé dans Script-3 (mysqldump)
- `rds_endpoint` → utilisé dans Script-1 et Script-3
- `app_url` → URL de l'application Phase 2

### 3. Créer le secret dans Secrets Manager (Script-1)

Dans Cloud9 (AWS Console → Cloud9 → Open IDE) :

```bash
aws secretsmanager create-secret \
    --name Mydbsecret \
    --description "Database secret for web app" \
    --secret-string "{\"user\":\"nodeapp\",\"password\":\"student12\",\"host\":\"<rds_endpoint>\",\"db\":\"STUDENTS\"}"
```

> Remplacer `<rds_endpoint>` par la valeur de `terraform output rds_endpoint`

> **Note** : Terraform crée déjà ce secret automatiquement via `aws_secretsmanager_secret`.
> Script-1 est fourni pour référence — pas besoin de le lancer si Terraform a tourné.

### 4. Migrer les données (Script-3)

Dans Cloud9 :

```bash
# Export depuis le serveur POC (MySQL local)
mysqldump -h <poc_server_private_ip> -u nodeapp -p --databases STUDENTS > data.sql
# Mot de passe : student12

# Import dans RDS
mysql -h <rds_endpoint> -u nodeapp -p STUDENTS < data.sql
# Mot de passe : student12 (ou le mot de passe choisi au terraform apply)
```

### 5. Tester l'application

Ouvrir `terraform output app_url` dans le navigateur.
Vérifier que les données migrées sont bien présentes.

---

## Limites résolues vs étape 1

| Problème Phase 1 | Solution Phase 2 |
|---|---|
| DB locale → perte si instance détruite | RDS managé avec stockage persistant |
| Credentials en clair dans le script | Secrets Manager — plus rien en dur |
| Tout sur une seule machine | App et DB découplées et indépendantes |
| Pas de VPC dédié | VPC custom avec sous-réseaux publics/privés |

## Limites restantes (adressées en Phase 3)

| Problème | Solution à venir |
|---|---|
| Single point of failure sur l'EC2 | Auto Scaling Group |
| Pas de load balancing | Application Load Balancer |
| Une seule instance web | Multi-instances en Phase 3 |
