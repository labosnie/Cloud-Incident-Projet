# CloudOps Incident Platform v1

Plateforme de **démonstration** Cloud / DevOps : petite API conteneurisée, observabilité et scénarios d’incident, visant un portfolio **production-style** (pas une production complète).

**État du projet :** en cours — application locale validée (FastAPI, PostgreSQL, Docker Compose, tests). L’infra AWS (Terraform, CI/CD, monitoring) arrive dans les prochaines itérations.

Ce projet me permet de mettre en pratique une architecture cloud complète : API conteneurisée, infrastructure AWS, automatisation du déploiement, sécurité de base, monitoring et documentation d’incidents.

---

## Objectif

Montrer de façon défendable en entretien :

- application **conteneurisée** et reproductible en local ;
- bonnes habitudes (**secrets hors du dépôt**, tests, documentation) ;
- plus tard : **IaC (Terraform)**, déploiement **AWS** (ECS Fargate, ALB, RDS, etc.), **CI/CD**, **alerting**.

---

## Fonctionnalités actuelles (API)

| Méthode | Chemin | Description |
|--------|--------|-------------|
| `GET` | `/health` | Santé de l’application |
| `GET` | `/api/orders` | Liste des commandes fictives |
| `POST` | `/api/orders` | Création d’une commande fictive |
| `GET` | `/api/error` | Erreur **500** simulée (démo alerting) |
| `GET` | `/api/slow` | Latence simulée (~5 s) |

Documentation interactive : `/docs` (Swagger UI).

---

## Structure du dépôt

```
├── app/                 # Code FastAPI (routes, modèles, config, DB)
├── tests/               # Tests Pytest
├── Dockerfile
├── docker-compose.yml   # API + PostgreSQL en local
├── requirements.txt
├── .env.example         # Modèle de configuration (copier vers .env)
└── README.md
```

---

## Prérequis

- **Python** 3.11+ (validé en local avec Python **3.13**)
- **Docker Desktop** installé et **démarré** pour Compose
- Compte **GitHub** (pour pousser le dépôt quand tu es prêt)

---

## Démarrage rapide

### 1. Configuration

Ne jamais committer de secrets. Copier le modèle d’environnement :

```powershell
Copy-Item .env.example .env
```

Adapter `DATABASE_URL` si besoin (local vs conteneur).

### 2. Environnement Python et tests

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m pytest tests -v
```

### 3. API sans Docker (PostgreSQL requis sur la machine)

```powershell
.\.venv\Scripts\uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Puis : http://127.0.0.1:8000/docs

### 4. API + Postgres avec Docker Compose

```powershell
docker compose up --build
```

Puis : http://localhost:8000/docs  

Les données PostgreSQL sont dans le volume Docker `pgdata`. Pour **effacer la base** :

```powershell
docker compose down -v
```

Pour **arrêter** sans supprimer les données :

```powershell
docker compose down
```

---

## Git : commits et GitHub

- Faire des **commits petits et lisibles** (une amélioration logique par commit : ex. « feat: endpoint health », « chore: docker compose », « docs: readme »).
- Vérifier avant chaque push : **aucun fichier `.env`**, aucun mot de passe ou clé AWS dans le dépôt.
- Créer un dépôt vide sur GitHub, puis :

```powershell
git init
git add .
git commit -m "chore: initial import CloudOps Incident Platform"
git branch -M main
git remote add origin https://github.com/<ton-user>/<ton-repo>.git
git push -u origin main
```

(Adapter l’URL si tu utilises SSH.)

---

## Roadmap (à venir)

- [X] Terraform — VPC (subnets publics / privés, routage)
- [ ] RDS PostgreSQL (subnet privé) + secrets (Secrets Manager / SSM)
- [X] ECR + ECS Fargate + ALB + health check `/health`
- [ ] GitHub Actions (build, push image, déploiement)
- [ ] CloudWatch (logs, alarmes) + SNS (email)
- [ ] Documentation : schéma d’architecture, sécurité, estimation des coûts, runbook, post-mortem d’exemple

---

## Limites assumées (v1 applicative)

- Schéma SQL créé au démarrage (`create_all`), **sans migrations Alembic** pour l’instant.
- Données et endpoints **fictifs** ; l’objectif est l’**ingénierie** (cloud, ops, doc), pas un produit métier.

---

## Améliorations futures vers une architecture production
- Ajouter WAF et HTTPS avec ACM
- Ajouter plusieurs environnements dev/staging/prod
- Ajouter blue/green deployment
- Ajouter scan sécurité des images Docker
- Ajouter OpenTelemetry
- Ajouter backups automatisés
- Ajouter VPC endpoints
- Ajouter autoscaling avancé
- Ajouter tests d’intégration en CI

## Licence

À définir selon ton choix (souvent MIT ou « usage portfolio personnel »).
