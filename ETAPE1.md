# Étape 1 — Preuve de Concept (POC) : Application monolithique sur EC2

## Objectif

Déployer une application web Node.js avec sa base de données MySQL sur **une seule instance EC2**.
C'est le point de départ (POC) : tout tourne sur la même machine, sans résilience ni scalabilité.

---

## Architecture

```
                        INTERNET
                           |
                     (HTTP :80 / SSH :22)
                           |
                  ┌────────────────────┐
                  │   Security Group   │
                  │  student-app-sg    │
                  └────────┬───────────┘
                           |
              ┌────────────▼────────────────┐
              │       EC2 Instance          │
              │   (Ubuntu 22.04 - t2.micro) │
              │                             │
              │  ┌─────────────────────┐    │
              │  │  Node.js App        │    │
              │  │  (port 80)          │    │
              │  └──────────┬──────────┘    │
              │             │ localhost     │
              │  ┌──────────▼──────────┐    │
              │  │  MySQL Server       │    │
              │  │  DB : STUDENTS      │    │
              │  │  User : nodeapp     │    │
              │  └─────────────────────┘    │
              └─────────────────────────────┘
```

### Flux de données

1. L'utilisateur accède à l'app via `http://<IP_PUBLIQUE>` (port 80)
2. Node.js reçoit la requête et interroge MySQL **en local** (via l'IP privée de l'instance récupérée depuis l'Instance Metadata Service)
3. MySQL répond avec les données de la table `students`

---

## Composants Terraform

### `main.tf`

| Ressource | Type Terraform | Rôle |
|---|---|---|
| `data.aws_ami.ubuntu` | `aws_ami` | Récupère l'AMI Ubuntu 22.04 LTS la plus récente (Canonical) |
| `aws_security_group.app_sg` | `aws_security_group` | Firewall : ouvre le port 80 (HTTP) et 22 (SSH) depuis Internet |
| `aws_instance.app_server` | `aws_instance` | Instance EC2 qui héberge l'app et la base de données |

### `variables.tf`

| Variable | Valeur par défaut | Description |
|---|---|---|
| `aws_region` | `us-east-1` | Région AWS du déploiement |
| `instance_type` | `t2.micro` | Taille de l'instance EC2 |

### `outputs.tf`

| Output | Description |
|---|---|
| `instance_public_ip` | IP publique de l'instance EC2 |
| `instance_public_dns` | DNS public de l'instance EC2 |
| `app_url` | URL complète pour accéder à l'application |

---

## Le script `solution_code_poc.sh` (User Data)

Ce script est exécuté **automatiquement au premier démarrage** de l'instance EC2. Il réalise les étapes suivantes :

### 1. Installation des dépendances système
```bash
apt update -y
apt install nodejs unzip wget npm mysql-server -y
```
Installe Node.js, npm et MySQL Server sur l'instance.

### 2. Téléchargement et extraction du code source
```bash
wget https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/.../code.zip -P /home/ubuntu
unzip code.zip -x "resources/codebase_partner/node_modules/*"
npm install aws aws-sdk
```
Récupère l'application depuis un bucket S3 AWS et installe ses dépendances Node.js.

### 3. Configuration de MySQL
```bash
mysql -u root -e "CREATE USER 'nodeapp' IDENTIFIED WITH mysql_native_password BY 'student12'"
mysql -u root -e "GRANT all privileges on *.* to 'nodeapp'@'%';"
mysql -u root -e "CREATE DATABASE STUDENTS;"
mysql -u root -e "USE STUDENTS; CREATE TABLE students(id, name, address, city, state, email, phone);"
```
Crée un utilisateur dédié `nodeapp`, une base `STUDENTS` et la table `students`.

### 4. Ouverture du bind MySQL
```bash
sed -i 's/.*bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
```
Permet à MySQL d'écouter sur toutes les interfaces (utile pour les étapes suivantes où la DB sera séparée).

### 5. Démarrage de l'application
```bash
export APP_DB_HOST=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
export APP_DB_USER=nodeapp
export APP_DB_PASSWORD=student12
export APP_DB_NAME=STUDENTS
export APP_PORT=80
npm start &
```
`APP_DB_HOST` est récupéré depuis l'**Instance Metadata Service (IMDS)** d'AWS (`169.254.169.254`) — c'est l'IP privée de l'instance elle-même. L'app se connecte donc à MySQL en local.

### 6. Persistance au redémarrage
```bash
echo '...' > /etc/rc.local
chmod +x /etc/rc.local
```
Crée un script `rc.local` pour relancer l'application Node.js automatiquement après un reboot.

---

## Déploiement

### Prérequis
- Terraform >= 1.0 installé
- AWS CLI configuré (`aws configure`) avec des credentials valides
- Une paire de clés SSH si vous souhaitez accéder à l'instance (à ajouter dans `main.tf`)

### Commandes

```bash
# 1. Initialiser Terraform (télécharge le provider AWS)
terraform init

# 2. Visualiser les ressources qui seront créées
terraform plan

# 3. Déployer l'infrastructure
terraform apply

# 4. Récupérer l'URL de l'application (après ~3-5 minutes le temps que le user data s'exécute)
terraform output app_url

# 5. Détruire l'infrastructure
terraform destroy
```

> **Note** : L'application met environ **3 à 5 minutes** à démarrer après la création de l'instance, le temps que le script `user_data` s'exécute (téléchargement, installation, configuration).

---

## Limites de cette architecture (POC)

| Problème | Impact |
|---|---|
| **Single Point of Failure** | Si l'instance tombe, tout le service est indisponible |
| **Base de données locale** | Les données sont perdues si l'instance est détruite |
| **Pas de scalabilité** | Impossible d'ajouter des instances sans reconfigurer la DB |
| **Sécurité** | MySQL écoute sur `0.0.0.0`, mot de passe en clair dans le script |
| **Pas de VPC dédié** | Utilise le VPC par défaut d'AWS |

Ces limitations seront adressées dans les étapes suivantes (RDS, Auto Scaling, VPC custom, etc.).

---

## Schéma d'architecture pour le rendu

Pour le schéma d'architecture officiel, les éléments à représenter sont :

```
┌─────────────────────────────────────────────────────┐
│                     AWS Cloud                       │
│                                                     │
│   ┌─────────────────────────────────────────────┐   │
│   │              Region us-east-1               │   │
│   │                                             │   │
│   │   ┌─────────────────────────────────────┐   │   │
│   │   │         VPC (default)               │   │   │
│   │   │                                     │   │   │
│   │   │   ┌─────────────────────────────┐   │   │   │
│   │   │   │    Security Group           │   │   │   │
│   │   │   │    [port 80] [port 22]      │   │   │   │
│   │   │   │                             │   │   │   │
│   │   │   │   ┌─────────────────────┐   │   │   │   │
│   │   │   │   │   EC2 t2.micro      │   │   │   │   │
│   │   │   │   │   Ubuntu 22.04      │   │   │   │   │
│   │   │   │   │                     │   │   │   │   │
│   │   │   │   │  [Node.js :80]      │   │   │   │   │
│   │   │   │   │  [MySQL  :3306]     │   │   │   │   │
│   │   │   │   └─────────────────────┘   │   │   │   │
│   │   │   └─────────────────────────────┘   │   │   │
│   │   └─────────────────────────────────────┘   │   │
│   └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
         ▲
         │  HTTP :80
         │
    [Utilisateur]
```
