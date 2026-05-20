# Post-Mortem — ECS Task Failed To Start

## Incident Summary

| Champ | Valeur |
|---|---|
| Incident ID | INC-2026-001 |
| Date | 14 Mai 2026 |
| Durée | ~15 minutes |
| Gravité | SEV-2 |
| Service impacté | API FastAPI |
| Composant principal | ECS Fargate |
| Statut | Résolu |

### Description

L’application FastAPI déployée sur ECS Fargate n’a pas démarré correctement après une tentative de déploiement.

Les tâches ECS se terminaient immédiatement après leur création.

L’application n’était plus accessible derrière l’Application Load Balancer.

---

## Impact

Impact observé :

- API inaccessible
- tâches ECS arrêtées automatiquement
- Target Group sans cible saine
- Application Load Balancer retournant :

```text
HTTP 503 Service Unavailable
```

Impact utilisateur :

```text
Toutes les requêtes vers l’application échouaient.
```

---

## Timeline

| Heure | Événement |
|---|---|
| 12:15 | Déploiement ECS lancé |
| 12:16 | Tâches ECS passent en état STOPPED |
| 12:17 | Vérification ECS Service |
| 12:18 | Analyse des tâches ECS |
| 12:19 | Erreur CannotPullContainerError identifiée |
| 12:21 | Vérification ECR |
| 12:23 | Image Docker absente confirmée |
| 12:25 | Build Docker relancé |
| 12:27 | Push image vers ECR |
| 12:29 | Nouveau déploiement ECS |
| 12:30 | Health checks ALB validés |
| 12:31 | Service opérationnel |

---

## Detection

Le problème a été identifié via plusieurs observations :

### ECS Service

Les tâches ECS passaient immédiatement en état :

```text
STOPPED
```

### ECS Describe Tasks

Erreur retournée :

```text
CannotPullContainerError:
failed to resolve ref:
cloudops-incident-api-dev:latest not found
```

### ALB

L’Application Load Balancer retournait :

```text
HTTP 503
```

---

## Root Cause Analysis

### Cause directe

L’image Docker attendue par ECS n’était pas présente dans Amazon ECR.

La tâche ECS tentait de récupérer :

```text
cloudops-incident-api-dev:latest
```

mais cette image n’existait pas.

---

### Cause profonde

Le processus de déploiement était manuel :

```text
Build Docker
→ Login ECR
→ Push image
→ Déploiement ECS
```

Une étape critique n’avait pas été exécutée :

```text
Push image vers ECR
```

---

### Pourquoi cela est arrivé

Analyse "5 Whys"

Pourquoi ECS a échoué ?

→ Impossible de récupérer l’image.

Pourquoi l’image était absente ?

→ L’image n’avait pas été poussée dans ECR.

Pourquoi ?

→ Processus manuel.

Pourquoi ?

→ Pas encore de pipeline CI/CD automatisé.

Pourquoi ?

→ Fonctionnalité non encore implémentée dans le projet.

---

## Résolution

Actions réalisées :

1.

Build de l’image :

```bash
docker build -t cloudops-incident-api .
```

2.

Authentification ECR :

```bash
aws ecr get-login-password
```

3.

Push image :

```bash
docker push
```

4.

Redéploiement ECS :

```bash
aws ecs update-service --force-new-deployment
```

5.

Validation :

```text
Health checks ALB : OK
Endpoint /health : OK
```

---

## Actions préventives

Actions décidées :

| Action | Priorité |
|---|---:|
| Ajouter CI GitHub Actions | Haute |
| Ajouter Build automatique Docker | Haute |
| Ajouter Push automatique ECR | Haute |
| Ajouter vérification image avant déploiement | Moyenne |
| Ajouter scan sécurité Trivy | Moyenne |

---

## Lessons Learned

Leçons techniques :

- ECS dépend directement des images présentes dans ECR
- Une image absente peut provoquer une indisponibilité complète
- Les logs ECS sont essentiels pour diagnostiquer rapidement
- Les health checks ALB accélèrent le diagnostic
- L’automatisation réduit les erreurs humaines

---

## Conclusion

L’incident n’a pas été causé par une erreur applicative mais par un problème de processus de déploiement.

La résolution a confirmé l’importance :

- de l’automatisation ;
- de la validation avant déploiement ;
- de la documentation des incidents ;
- de l’amélioration continue.

Ce post-mortem sera utilisé comme référence pour les futurs incidents du projet.