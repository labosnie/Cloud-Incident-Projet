# Cloud Incident Project

Projet portfolio Cloud/DevOps orienté observabilité : API conteneurisée sur AWS, détection d’incidents applicatifs simulés et alertes automatiques.

Développé dans une logique d’apprentissage pratique (Cloud, DevOps, sécurité), avec infrastructure as code, CI/CD sécurisé et documentation du débogage réel.

Le projet n’est pas considéré comme "production-ready" :

- pas encore de HTTPS (ACM)
- pas encore de RDS PostgreSQL privé
- pas encore de Secrets Manager
- pas encore de smoke tests automatiques post-déploiement
- pas encore de Terraform CI complet

---

## État actuel validé

### Infrastructure

- Terraform modulaire (`infra/modules`, `infra/envs/dev`)
- VPC (subnets publics / privés)
- Amazon ECR
- ECS Fargate
- Application Load Balancer
- CloudWatch Logs
- CloudWatch Alarms
- SNS (alertes e-mail)

### CI/CD

- GitHub Actions
- Trivy
- Push automatique ECR
- Redéploiement ECS
- Authentification AWS via OIDC

### Application

- FastAPI
- Docker
- Docker Compose
- PostgreSQL local
- Pytest

### Documentation

- Architecture
- Debug journal
- Runbook incident
- Post-mortem
- Estimation des coûts

---

## CI/CD

Pipeline GitHub Actions : `.github/workflows/ci.yml`

### Validation code (push + pull request)

```text
Checkout
↓
Python 3.13
↓
Installation dépendances
↓
flake8
↓
black --check
↓
pytest
↓
docker build
↓
Trivy scan
```

| Étape | Détail |
|---------|---------|
| Lint / format | flake8 + black |
| Tests | Pytest |
| Build | Docker image |
| Trivy CRITICAL | bloque le pipeline |
| Trivy HIGH | affiché comme avertissement |

---

### Déploiement AWS (push sur main uniquement)

```text
GitHub Actions
↓
OIDC
↓
AWS STS AssumeRoleWithWebIdentity
↓
Authentification AWS temporaire
↓
Connexion ECR
↓
Push image (:latest + :sha)
↓
ecs update-service
↓
Validation ECS
```

Permissions AWS :

- rôle IAM dédié GitHub Actions
- permissions minimales ECR / ECS
- authentification temporaire via OIDC

Variables GitHub requises :

- AWS_ROLE_ARN
- AWS_REGION
- ECR_REPOSITORY
- ECS_CLUSTER
- ECS_SERVICE

Aucune clé AWS longue durée n'est utilisée.

Notes :

Le déploiement nécessite que l'infrastructure AWS de développement soit active.

Si l'infrastructure est supprimée :

```bash
terraform destroy
```

les étapes CI restent fonctionnelles mais le push ECR et le redéploiement ECS échoueront normalement.

---

## Sécurité actuelle

### Implémenté

- Amazon ECR privé
- IAM Roles ECS
- Security Groups
- GitHub Actions → AWS via OIDC
- Trivy intégré dans la pipeline CI
- authentification AWS temporaire
- séparation des rôles ECS

### Limites actuelles

- pas encore de Secrets Manager
- pas encore HTTPS / ACM
- pas encore Docker non-root
- pas encore Terraform security scan (Checkov)
- pas encore politique IAM très restrictive

---

## Roadmap

### Réalisé

- API FastAPI
- Docker
- Docker Compose
- Pytest
- Terraform modulaire
- VPC
- ECR
- ECS
- ALB
- Monitoring CloudWatch
- SNS
- Trivy
- GitHub Actions
- OIDC
- Documentation architecture
- Debug journal
- Runbook incident
- Post-mortem
- Estimation des coûts

---

### Priorité haute

- Terraform CI

    - terraform fmt
    - terraform validate
    - tflint
    - checkov

- ECS deployment circuit breaker

- Smoke test automatique sur `/health`

- Docker hardening

    - utilisateur non-root
    - HEALTHCHECK

---

### Priorité moyenne

- RDS PostgreSQL privé
- AWS Secrets Manager
- HTTPS avec certificat ACM
- Dashboard CloudWatch
- OpenTelemetry

---

### Priorité future

- Environnements séparés (staging / production)
- WAF
- Observabilité avancée
- SLO
- Tracing distribué

---

## Leçons apprises

Problèmes rencontrés durant le développement :

- différence entre ECS et ECR
- gestion des images Docker privées
- diagnostic erreurs ALB 503
- importance des health checks
- débogage CloudWatch
- dépendances Terraform au destroy
- migration GitHub Actions → OIDC
- intérêt de documenter incidents et post-mortems

Voir :

```text
docs/debug-journal.md
```

---

## Auteur

Projet portfolio orienté Cloud / DevOps / sécurité avec une approche réaliste, progressive et documentée.