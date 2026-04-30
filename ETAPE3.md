# Étape 3 — Haute disponibilité et mise à l'échelle : ALB + Auto Scaling

## Objectif

Éliminer le Single Point of Failure de l'EC2 App Server en remplaçant l'instance unique par un **groupe Auto Scaling** derrière un **Application Load Balancer**. L'application devient ainsi hautement disponible, résiliente aux pannes d'instance, et capable de s'adapter automatiquement à la charge.

---

## Architecture

```
                            INTERNET
                               |
                     (HTTP :80)
                               |
                    ┌──────────────────────┐
                    │    Internet Gateway   │
                    └──────────┬───────────┘
                               |
          ┌────────────────────────────────────────┐
          │              VPC  10.0.0.0/16          │
          │                                        │
          │  ┌─────────────────────────────────┐   │
          │  │  Sous-réseau PUBLIC us-east-1a   │   │
          │  │  10.0.1.0/24                     │   │
          │  │  [EC2 POC]  [Cloud9]             │   │
          │  │  [ASG Instance 1]                │   │
          │  └─────────────────────────────────┘   │
          │                                        │
          │  ┌─────────────────────────────────┐   │
          │  │  Sous-réseau PUBLIC us-east-1b   │   │
          │  │  10.0.2.0/24                     │   │
          │  │  [ASG Instance 2]                │   │
          │  └─────────────────────────────────┘   │
          │           |              |              │
          │    MySQL :3306 (vers sous-réseaux privés)│
          │  ┌─────────────────────────────────┐   │
          │  │  Sous-réseau PRIVÉ us-east-1a   │   │
          │  │  10.0.3.0/24                     │   │
          │  │  [RDS MySQL 8.0]                 │   │
          │  └─────────────────────────────────┘   │
          │                                        │
          │  ┌─────────────────────────────────┐   │
          │  │  Sous-réseau PRIVÉ us-east-1b   │   │
          │  │  10.0.4.0/24                     │   │
          │  └─────────────────────────────────┘   │
          └────────────────────────────────────────┘

              ┌───────────────────────┐
              │   AWS Secrets Manager  │
              │   Secret: Mydbsecret   │
              └───────────────────────┘
```

### Flux de données

1. L'utilisateur accède à `http://<ALB_DNS>` (port 80)
2. L'ALB reçoit la requête et la distribue à l'une des instances EC2 saines du groupe Auto Scaling
3. L'instance récupère ses credentials DB depuis **Secrets Manager** via son IAM Role
4. Node.js se connecte à **RDS MySQL** en sous-réseau privé

---

## Nouveaux composants Terraform

### `alb.tf`

| Ressource | Rôle |
|---|---|
| `aws_security_group.alb_sg` | Firewall de l'ALB : port 80 depuis Internet |
| `aws_lb.app` | Application Load Balancer multi-AZ (public_1 + public_2) |
| `aws_lb_target_group.app` | Groupe cible HTTP:80, health check sur `/` |
| `aws_lb_listener.http` | Écoute le port 80, transfère vers le target group |

### `asg.tf`

| Ressource | Rôle |
|---|---|
| `aws_launch_template.app` | Modèle de lancement : AMI Ubuntu, t3.micro, user data = `code_serveur_app.sh`, `LabInstanceProfile` |
| `aws_autoscaling_group.app` | min=1 / desired=2 / max=3, couvre public_1 et public_2, health check ELB |
| `aws_autoscaling_policy.cpu` | Target Tracking : maintient le CPU à 50%, scale automatiquement |

---

## Déploiement

### 1. Lancer terraform apply

```bash
terraform apply
# Entrer le mot de passe RDS quand demandé
```

> L'ALB met environ **2-3 minutes** à être actif. Les instances ASG mettent **3-5 minutes** supplémentaires (user data).

### 2. Récupérer l'URL de l'application

```bash
terraform output alb_url
```

Ouvrir l'URL dans le navigateur et vérifier que l'application répond.

### 3. Test de charge (Script-2)

Dans Cloud9 :

```bash
# Récupérer l'URL de l'ALB (depuis la machine où Terraform est installé)
terraform output alb_url
# Exemple de sortie : http://student-app-alb-1234567890.us-east-1.elb.amazonaws.com

# Dans Cloud9 — remplacer <ALB_URL> par la valeur ci-dessus
npm install -g loadtest
loadtest --rps 1000 -c 500 -k <ALB_URL>
```

Observer dans la console AWS (`EC2 → Auto Scaling Groups → Monitoring`) la montée en charge et le déclenchement du scale-out.

---

## Limites résolues vs étape 2

| Problème Phase 2 | Solution Phase 3 |
|---|---|
| Single Point of Failure sur l'EC2 | Auto Scaling Group — si une instance tombe, les autres prennent le relais |
| Pas de load balancing | ALB distribue le trafic sur plusieurs instances |
| Scalabilité manuelle | Target Tracking CPU 50% → scale automatique |
| Une seule AZ pour le web | Instances réparties sur us-east-1a et us-east-1b |

## Limites restantes

- L'application est distribuée sous forme de script user data (non versionné, long à démarrer)
- Pas de pipeline automatisé pour déployer une nouvelle version
