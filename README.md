# Cloud Incident Project

Infrastructure Cloud/DevOps orientée observabilité permettant de déployer une API conteneurisée sur AWS, détecter automatiquement des incidents applicatifs et déclencher des alertes en temps réel.

Le projet est développé dans une logique d'apprentissage pratique autour du Cloud, du DevOps et de la sécurité, avec une approche centrée sur le débogage réel et l'infrastructure as code.

---

## Aperçu

Objectifs du projet :

- Déployer une API conteneurisée sur AWS
- Mettre en place une infrastructure modulaire avec Terraform
- Détecter automatiquement les erreurs et anomalies
- Déclencher des alertes en temps réel
- Documenter le troubleshooting et les incidents

---

## Architecture

```mermaid
flowchart TD

User[Utilisateur] --> ALB[Application Load Balancer]

ALB --> ECS[ECS Fargate - FastAPI]

ECR[Amazon ECR] --> ECS

ECS --> CWLogs[CloudWatch Logs]

ALB --> Metrics[CloudWatch Metrics]

Metrics --> Alarm5XX[CloudWatch Alarm - Erreurs 5XX]

Metrics --> AlarmLatency[CloudWatch Alarm - Latence]

Alarm5XX --> SNS[Amazon SNS]

AlarmLatency --> SNS

SNS --> Email[Notification Email]
```

---

## Stack technique

| Catégorie | Technologies |
|---|---|
| Backend | FastAPI |
| Conteneurisation | Docker |
| Tests | Pytest |
| Infrastructure as Code | Terraform |
| Cloud Provider | AWS |
| Registry | Amazon ECR |
| Compute | ECS Fargate |
| Réseau | VPC + ALB |
| Monitoring | CloudWatch |
| Notifications | SNS |
| CI | GitHub Actions |

---

## Fonctionnalités actuelles

### API

Endpoints disponibles :

```http
GET /health
GET /api/error
GET /api/slow
```

Fonctionnement :

- `/health`

Retourne :

```json
{"status":"ok"}
```

- `/api/error`

Simule :

```text
Erreur HTTP 500
```

- `/api/slow`

Simule :

```text
Latence importante
```

---

### Infrastructure AWS

Infrastructure actuellement déployée :

- VPC
- Subnets publics / privés
- Routage réseau
- ECS Fargate
- Application Load Balancer
- ECR privé
- IAM Roles
- CloudWatch Logs
- CloudWatch Alarms
- SNS Email

---

### Observabilité

Métriques surveillées :

- erreurs HTTP 5XX
- temps de réponse

Alertes :

- CloudWatch Alarm erreurs
- CloudWatch Alarm latence
- Notification SNS Email

---

### Validation réelle

Tests réalisés :

- Déploiement ECS validé
- Health checks validés
- Incident 5XX simulé
- Latence simulée
- Réception email SNS validée
- Logs CloudWatch validés
- Destruction Terraform validée

Chaîne validée de bout en bout :

```text
GET /api/error
→ ALB reçoit des réponses HTTP 500
→ CloudWatch détecte les erreurs 5XX
→ L’alarme passe en ALARM
→ SNS envoie une notification email
```

#### 1. Simulation des erreurs HTTP 500

![Requêtes HTTP 500 depuis PowerShell](docs/HTTP%20500%20REQUEST.png)

#### 2. Alarme CloudWatch déclenchée

![Alarme CloudWatch en état ALARM](docs/CLOUDWATCH%20ALARM.png)

#### 3. Alerte email reçue via SNS

![Email SNS reçu](docs/MAIL%20SNS%20ALARM.png)

---

## Structure du projet

```text
Cloud-Incident-Projet/
│
├── app/
│   ├── api/
│   └── models/
│
├── tests/
│
├── docs/
│   ├── architecture.md
│   ├── debug-journal.md
│   ├── runbook-incident-5xx.md
│   ├── postmortem-example.md
│   ├── cost-estimation.md
│   ├── HTTP 500 REQUEST.png
│   ├── CLOUDWATCH ALARM.png
│   └── MAIL SNS ALARM.png
│
├── infra/
│   ├── bootstrap/
│   ├── envs/
│   │   └── dev/
│   │
│   └── modules/
│       ├── vpc/
│       ├── ecr/
│       ├── ecs/
│       └── monitoring/
│
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── README.md
└── .github/
    └── workflows/
```

---

## Documentation

| Document | Description |
|---|---|
| docs/architecture.md | Architecture détaillée |
| docs/debug-journal.md | Journal des problèmes rencontrés et résolutions |
| docs/runbook-incident-5xx.md | Procédure de gestion d'incident |
| docs/postmortem-example.md | Post-mortem — ECS TaskFailedToStart (image ECR absente) |
| docs/cost-estimation.md | Estimation des coûts AWS (dev / portfolio, eu-west-3) |
| docs/*.png | Captures de validation (incident, alarme, email) |

---

## Exécution locale

Cloner le projet :

```bash
git clone https://github.com/labosnie/Cloud-Incident-Projet.git

cd Cloud-Incident-Projet
```

Lancer localement :

```bash
docker-compose up --build
```

Tester :

```bash
curl http://localhost:8000/health
```

Résultat attendu :

```json
{"status":"ok"}
```

---

## Pipeline CI actuel

Pipeline GitHub Actions (fichier [`.github/workflows/ci.yml`](.github/workflows/ci.yml)) :

```text
Push / Pull Request
        ↓
Checkout → Python 3.13 → pip install
        ↓
flake8 → black --check → pytest → docker build → Trivy
```

Étapes exécutées :

1. Checkout repository
2. Installation dépendances (`requirements-dev.txt`)
3. Lint (flake8)
4. Format (black --check)
5. Tests Pytest
6. Build Docker (`cloud-incident-api:ci`)
7. Scan Trivy — **échec** si vulnérabilité **CRITICAL** ; **HIGH** affiché en avertissement (pipeline non bloqué)

Objectif :

Garantir qu'une modification n'introduit pas une régression avant déploiement, et détecter tôt les vulnérabilités critiques dans l'image Docker.

### Scan sécurité (Trivy)

[Trivy](https://github.com/aquasecurity/trivy) analyse l'image Docker construite en CI (OS de base `python:3.13-slim` + dépendances pip). C'est une première étape **DevSecOps** : le scan s'exécute **après** le build, sur l'image locale `cloud-incident-api:ci`, sans push vers ECR.

| Sévérité | Comportement CI |
|---|---|
| **CRITICAL** | Pipeline **rouge** — merge à corriger avant livraison |
| **HIGH** | Rapport dans les logs, pipeline **vert** (avertissement) |
| MEDIUM / LOW | Non bloquants dans cette configuration |

Reproduire en local (installer [Trivy](https://aquasecurity.github.io/trivy/latest/getting-started/installation/) puis) :

```powershell
docker build -t cloud-incident-api:local .
trivy image --severity CRITICAL --exit-code 1 cloud-incident-api:local
trivy image --severity HIGH cloud-incident-api:local
```

Vérifier les runs : [Actions sur GitHub](https://github.com/labosnie/Cloud-Incident-Projet/actions).

> Pour documenter la CI dans le README : ajouter une capture du run vert dans `docs/` (ex. `GITHUB-ACTIONS-CI-SUCCESS.png`) puis l’insérer ici.

---

## Roadmap

Court terme :

- [x] Ajouter un exemple de post-mortem
- [x] Ajouter estimation des coûts
- [x] Ajouter Trivy pour le scan Docker

Moyen terme :

- [ ] Déploiement automatique ECS
- [ ] RDS PostgreSQL privé
- [ ] Secrets Manager
- [ ] HTTPS avec ACM

Long terme :

- [ ] WAF
- [ ] OpenTelemetry
- [ ] Tracing distribué
- [ ] Séparation dev / staging / production

---

## Leçons apprises

Problèmes rencontrés durant le développement :

- Différence entre ECS et ECR
- Gestion des images Docker privées
- Diagnostic d'erreurs ALB 503
- Importance des health checks
- Débogage CloudWatch
- Gestion des métriques ALB
- Dépendances Terraform destroy
- Débogage réseau AWS
- Importance de documenter les incidents

Les détails sont disponibles ici :

`docs/debug-journal.md`

---

## Auteur

Projet développé dans le cadre d'une montée en compétences Cloud / DevOps / Sécurité.

L'objectif est de construire progressivement une architecture réaliste tout en documentant les problèmes rencontrés et les solutions apportées.