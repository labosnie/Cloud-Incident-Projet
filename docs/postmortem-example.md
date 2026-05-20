# Post-mortem — ECS TaskFailedToStart (image absente dans ECR)

**Projet :** Cloud Incident Project  
**Environnement :** `dev` — région `eu-west-3`  
**Type :** incident de déploiement (environnement de démonstration / portfolio)  
**Document lié :** [Debug Journal — entrée ALB 503 / ECR](debug-journal.md#3-alb-en-erreur-503)

---

# Incident Summary

| Champ | Valeur |
|---|---|
| **ID incident** | `INC-CLOUDOPS-DEV-2025-ECR-001` |
| **Date** | Session de premier déploiement ECS sur l’environnement `dev` (date calendaire exacte non archivée ; incident documenté dans le debug journal du projet) |
| **Durée** | ~45 minutes (diagnostic + correction manuelle) |
| **Impact** | API FastAPI inaccessible via l’ALB ; endpoint public `/health` indisponible ; aucune cible saine dans le Target Group |
| **Gravité** | **SEV-3 (limité)** — environnement de démonstration sans utilisateurs finaux ; impact fonctionnel total sur le service exposé, sans perte de données ni fuite de secrets |

### Résumé en une phrase

Après un `terraform apply` réussi, ECS n’a pas pu démarrer la tâche Fargate car l’image Docker référencée (`cloudops-incident-api-dev:latest`) n’existait pas encore dans Amazon ECR, ce qui a provoqué un `CannotPullContainerError`, l’arrêt immédiat de la tâche et des réponses **HTTP 503** depuis l’Application Load Balancer.

### Périmètre technique concerné

Composants réellement impliqués dans ce projet :

- Terraform (`infra/envs/dev`) — modules `ecr`, `ecs`, `vpc`, `monitoring`
- Amazon ECR — repository `cloudops-incident-api-dev`
- Amazon ECS Fargate — cluster `cloudops-incident-dev-ecs`, service `cloudops-incident-dev-api`
- Application Load Balancer — health check sur `/health`
- Amazon CloudWatch Logs — groupe de logs ECS (consultation post-incident)

Composants **non** impliqués dans cet incident : alarmes CloudWatch 5XX, SNS, RDS, pipeline CD (non encore en place au moment de l’incident).

---

# Timeline

Chronologie reconstituée à partir des investigations documentées. Les horaires sont indicatifs (session de travail unique).

| Heure (UTC+1) | Événement |
|---|---|
| **11:52** | `terraform apply` terminé avec succès sur `infra/envs/dev`. VPC, ECR (repository vide), ECS, ALB et monitoring créés. |
| **11:53** | Test manuel de l’URL ALB : `curl.exe http://<alb_dns>/health` → réponse **503 Service Temporarily Unavailable**. |
| **11:54** | Vérification du Target Group dans la console AWS : **0 cible healthy**, **0 cible unhealthy** enregistrée comme stable — symptôme typique d’absence de tâche en cours d’exécution. |
| **11:56** | `aws ecs list-tasks --cluster cloudops-incident-dev-ecs --region eu-west-3` — aucune tâche `RUNNING`, ou tâche rapidement passée à `STOPPED`. |
| **11:58** | `aws ecs describe-tasks` sur la dernière tâche arrêtée : statut `STOPPED`, raison **`TaskFailedToStart`**. |
| **12:00** | Lecture du détail ECS : erreur **`CannotPullContainerError`** — référence d’image introuvable dans ECR. |
| **12:02** | `aws ecr describe-images --repository-name cloudops-incident-api-dev --region eu-west-3` — **aucune image** avec le tag `latest`. |
| **12:05** | Hypothèse confirmée : Terraform a provisionné le repository ECR, mais **aucun `docker push`** n’avait été exécuté avant le premier démarrage ECS. |
| **12:10** | `docker build` de l’image locale à partir du `Dockerfile` du projet. |
| **12:15** | `aws ecr get-login-password` + `docker login` vers le registry ECR `eu-west-3`. |
| **12:18** | `docker tag` puis `docker push` vers `…/cloudops-incident-api-dev:latest` (URI alignée sur `module.ecr.repository_url` + `var.ecs_image_tag`). |
| **12:22** | `aws ecs update-service --cluster cloudops-incident-dev-ecs --service cloudops-incident-dev-api --force-new-deployment --region eu-west-3`. |
| **12:28** | Nouvelle tâche ECS en état `RUNNING`. Target Group : **1 healthy**. |
| **12:30** | `curl.exe http://<alb_dns>/health` → **HTTP 200** — `{"status":"ok"}`. Incident clos. |

---

# Detection

## Symptômes observés côté utilisateur / opérateur

- Requête HTTP vers l’ALB : **503** au lieu de **200** sur `/health`.
- Application considérée comme « déployée » après Terraform, mais **inaccessible** depuis Internet.

## Signaux d’infrastructure

| Source | Observation |
|---|---|
| **Application Load Balancer** | Target Group sans cible saine ; pas de trafic routé vers le conteneur. |
| **Amazon ECS** | Événement de service : échec de placement / démarrage de tâche ; `lastStatus: STOPPED`, `stoppedReason` lié au pull d’image. |
| **Amazon ECR** | Repository existant (créé par Terraform) mais **vide** — aucun artefact Docker poussé. |
| **CloudWatch Logs** | Peu ou pas de logs applicatifs utiles : le conteneur n’a jamais démarré suffisamment longtemps pour émettre des logs FastAPI/uvicorn. |
| **CloudWatch Alarms (5XX / latence)** | **Non déclenchées** pour cet incident : l’ALB renvoie un 503 (erreur côté load balancer / absence de cible), pas des 5XX générés par l’application. |

## Pourquoi les alarmes existantes n’ont pas aidé

Le monitoring du projet (alarmes sur `HTTPCode_Target_5XX_Count` et latence) est conçu pour détecter des **incidents applicatifs** une fois le service en ligne. Ici, le service n’a **jamais atteint** l’état « healthy » : il s’agit d’un **échec de déploiement**, pas d’une dégradation runtime.

---

# Root Cause Analysis

## Cause directe (proximate cause)

ECS Fargate n’a pas pu télécharger l’image du conteneur depuis ECR :

```text
CannotPullContainerError: failed to resolve ref:
<account>.dkr.ecr.eu-west-3.amazonaws.com/cloudops-incident-api-dev:latest not found
```

La task definition ECS (définie dans `infra/modules/ecs`) référence une image construite dynamiquement par Terraform :

```hcl
container_image = "${module.ecr.repository_url}:${var.ecs_image_tag}"
```

Avec les valeurs du projet : repository `cloudops-incident-api-dev`, tag par défaut `latest`. **Cette URI était valide syntaxiquement, mais l’artefact n’existait pas dans le registry.**

## Cause profonde (root cause)

Séparation non maîtrisée entre deux pipelines distincts :

1. **Pipeline infrastructure (Terraform)** — crée ECR, ECS, ALB, IAM, logs, alarmes.
2. **Pipeline artefact (Docker)** — build local + `docker push` vers ECR.

Seul le premier avait été exécuté. Le second — indispensable pour qu’ECS démarre — avait été **omis** lors du premier déploiement.

## Facteurs contributifs

| Facteur | Explication |
|---|---|
| **Confusion ECR / ECS** | ECR stocke ; ECS exécute. Créer le repository ≠ publier une image. (Documenté dans le debug journal, section 1.) |
| **Succès trompeur de `terraform apply`** | L’infrastructure apparaît « verte » alors que le runtime applicatif n’est pas prêt. |
| **Absence de CD automatisé** | Aucune étape CI/CD ne poussait l’image vers ECR avant ou après l’apply Terraform. |
| **Health check ALB** | Le check `/health` ne peut pas réussir sans conteneur ; le 503 est une **conséquence**, pas la cause. |

## Chaîne de défaillance

```text
terraform apply (OK)
    → ECR repository créé (vide)
    → ECS service démarre une tâche
    → ECS tente pull cloudops-incident-api-dev:latest
    → ECR : image introuvable
    → TaskFailedToStart / STOPPED
    → Target Group : 0 healthy
    → ALB → HTTP 503
```

---

# Resolution

## Actions correctives (dans l’ordre)

### 1. Confirmer l’état ECS et ECR

```powershell
aws ecs list-tasks --cluster cloudops-incident-dev-ecs --region eu-west-3
aws ecs describe-tasks --cluster cloudops-incident-dev-ecs --region eu-west-3 --tasks <TASK_ARN>
aws ecr describe-images --repository-name cloudops-incident-api-dev --region eu-west-3
```

### 2. Construire l’image Docker (racine du projet)

```powershell
docker build -t cloudops-incident-api .
```

### 3. Authentifier Docker auprès d’ECR

```powershell
aws ecr get-login-password --region eu-west-3 |
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-west-3.amazonaws.com
```

> Remplacer `<ACCOUNT_ID>` par l’identifiant du compte AWS utilisé pour le déploiement.

### 4. Tagger et pousser l’image vers le repository du projet

```powershell
docker tag cloudops-incident-api:latest <ACCOUNT_ID>.dkr.ecr.eu-west-3.amazonaws.com/cloudops-incident-api-dev:latest
docker push <ACCOUNT_ID>.dkr.ecr.eu-west-3.amazonaws.com/cloudops-incident-api-dev:latest
```

### 5. Forcer un nouveau déploiement ECS

```powershell
aws ecs update-service `
  --cluster cloudops-incident-dev-ecs `
  --service cloudops-incident-dev-api `
  --force-new-deployment `
  --region eu-west-3
```

### 6. Valider la résolution

```powershell
# Cible saine
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN> --region eu-west-3

# Santé applicative
curl.exe http://<alb_dns>/health
```

**Résultat attendu :** HTTP 200, corps `{"status":"ok"}`.

## Temps de résolution

- **MTTR (manuel, environnement dev) :** ~45 minutes, incluant la montée en compétence sur la lecture des événements ECS et la chaîne Docker → ECR → ECS.

---

# Preventive Actions

| # | Action | Priorité | Statut projet |
|---|---|---|---|
| 1 | Documenter la séquence obligatoire post-`terraform apply` : **build → push ECR → force-new-deployment ECS** | Haute | Documenté dans [debug-journal.md](debug-journal.md) et ce post-mortem |
| 2 | Checklist de déploiement dans le README / runbook : ne pas tester l’ALB avant vérification `aws ecr describe-images` | Haute | À intégrer au runbook déploiement |
| 3 | **CI GitHub Actions** — valider lint, tests et `docker build` à chaque push | Moyenne | **En place** (`.github/workflows/ci.yml`) |
| 4 | **CD** — étape `docker push` vers ECR + déploiement ECS automatisé après merge sur `main` | Haute | **Non implémenté** (roadmap) |
| 5 | Vérification pré-déploiement : script ou job CI qui échoue si l’image/tag attendu est absent d’ECR avant `update-service` | Moyenne | Proposé |
| 6 | Éviter de déployer le tag `latest` en production ; préférer un tag immuable (commit SHA) via `ecs_image_tag` | Basse (dev) / Haute (prod future) | Variable `ecs_image_tag` déjà prévue dans Terraform |
| 7 | Alarme CloudWatch sur métrique ECS `RunningTaskCount` < desired (absence de tâche healthy) | Moyenne | Non implémenté — complément utile aux alarmes 5XX |

### Séquence de déploiement cible (état souhaité)

```text
Code merge
    → GitHub Actions : pytest + docker build
    → (futur) push image vers ECR avec tag versionné
    → (futur) ecs update-service
    → Vérification /health + describe-target-health
```

---

# Lessons Learned

## Techniques

1. **Un `terraform apply` réussi ne signifie pas une application disponible.** L’IaC provisionne les ressources ; l’artefact applicatif (image Docker) reste une responsabilité séparée.

2. **HTTP 503 sur un ALB pointe souvent vers le Target Group, pas vers l’ALB lui-même.** La première investigation doit porter sur ECS et l’état des cibles, pas sur le code FastAPI.

3. **`TaskFailedToStart` + `CannotPullContainerError` = problème d’artefact ou de permissions ECR**, pas un bug Python dans l’API.

4. **ECR et ECS sont complémentaires** : le module Terraform `ecr` crée le registry ; le module `ecs` consomme une URI d’image qui doit **exister** au moment du `RunTask`.

5. **Les alarmes 5XX ne remplacent pas une supervision de disponibilité** (tâches ECS running, targets healthy).

## Organisationnelles (projet portfolio / junior)

1. Documenter les incidents réels (debug journal + post-mortem) apporte plus de crédibilité qu’une architecture théorique seule.

2. Une checklist post-déploiement courte évite de répéter la même erreur lors du prochain `apply`.

3. La CI actuelle protège la **qualité du code et du Dockerfile** ; elle ne remplace pas encore la **cohérence infra + image** — la prochaine étape logique est le CD vers ECR/ECS.

## Ce qui a bien fonctionné

- Modules Terraform séparés (`ecr`, `ecs`) facilitant l’analyse causale.
- Commandes AWS CLI reproductibles pour diagnostiquer la tâche arrêtée.
- Health check ALB sur `/health` : indicateur clair une fois l’image publiée.

---

# Références

| Document | Lien |
|---|---|
| Debug journal (sections 1, 3, 4) | [debug-journal.md](debug-journal.md) |
| Runbook incident HTTP 5XX | [runbook-incident-5xx.md](runbook-incident-5xx.md) |
| Architecture | [architecture.md](architecture.md) |
| Variables ECS / ECR | `infra/envs/dev/terraform.tfvars.example` |
| Workflow CI | `.github/workflows/ci.yml` |

---

# Sign-off

| Rôle | Nom | Date |
|---|---|---|
| Auteur / opérateur | Projet portfolio — Cloud Incident Project | — |
| Revue | — | — |

> **Note :** Ce document est un **exemple de post-mortem** basé sur un incident **réel** rencontré pendant la construction du projet, en environnement de démonstration `dev`. Il n’est pas issu d’un incident production client. Les horaires sont reconstitués à des fins pédagogiques.
