# Cost Estimation — Cloud Incident Project

## Objectif

Ce document fournit une estimation des coûts de l'architecture actuelle du projet **Cloud Incident Project**.

L'objectif n'est pas de donner un coût exact mais un ordre de grandeur réaliste basé sur :

- l'architecture réellement déployée ;
- une utilisation de type développement / portfolio ;
- un trafic très faible ;
- une utilisation intermittente ;
- les estimations AWS officielles.

Références utilisées :

- AWS Pricing Calculator
- Pages de tarification officielles AWS
- Région AWS : `eu-west-3 (Paris)`

Les coûts réels peuvent varier selon :

- le temps d'exécution des ressources ;
- le volume des logs ;
- le trafic réseau ;
- la durée de fonctionnement ;
- les futures évolutions de l'infrastructure.

---

## Architecture prise en compte

Services actuellement utilisés dans le projet :

- VPC
- Subnets publics / privés
- ECS Fargate
- Application Load Balancer
- Amazon ECR
- CloudWatch Logs
- CloudWatch Alarms
- Amazon SNS
- FastAPI
- Terraform

Services volontairement exclus :

- RDS
- NAT Gateway
- WAF
- Secrets Manager
- Kubernetes
- Lambda

Ces composants ne sont pas encore implémentés dans le projet.

---

## Hypothèses utilisées

Configuration utilisée pour l'estimation :

Région :

```text
eu-west-3 (Paris)
```

ECS :

```text
Nombre de tâches : 1
CPU : 256
Mémoire : 512 MB
```

Trafic :

```text
Très faible
Quelques appels API par jour
```

Logs :

```text
Faible volume
Rétention courte
```

SNS :

```text
Quelques emails par mois
```

Utilisation :

```text
Projet personnel / portfolio
Infrastructure utilisée quelques heures par jour
Suppression régulière via Terraform
```

Commande utilisée :

```powershell
terraform destroy
```

---

## Estimation des coûts mensuels

| Service | Utilisation estimée | Estimation mensuelle | Remarques |
|---|---:|---:|---|
| ECS Fargate | 1 tâche (256 CPU / 512 MB) | ~2–8 € | Dépend du temps actif |
| Application Load Balancer | Faible trafic | ~16–20 € | Principal coût fixe |
| Amazon ECR | Quelques images Docker | ~0–1 € | Faible stockage |
| CloudWatch Logs | Faible volume | ~0–2 € | Dépend des logs et rétention |
| CloudWatch Alarms | 2 alarmes | ~0–1 € | Coût faible |
| Amazon SNS | Quelques emails | ~0 € | Généralement négligeable |
| Réseau sortant | Très faible | ~0–2 € | Dépend du trafic |

---

## Estimation globale

### Développement occasionnel

Infrastructure utilisée quelques heures par jour :

```text
≈ 15–30 €/mois
```

---

### Utilisation moyenne

Infrastructure utilisée régulièrement :

```text
≈ 25–40 €/mois
```

---

### Infrastructure active en continu

Sans suppression Terraform :

```text
≈ 40–70 €/mois
```

---

## Principales sources de coût

Les coûts principaux proviennent généralement de :

### Application Load Balancer

Raison :

- coût fixe
- coût par trafic traité

---

### ECS Fargate

Raison :

- facturation CPU
- facturation mémoire
- durée d'exécution

---

Les composants suivants restent généralement faibles :

- SNS
- CloudWatch Alarms
- ECR

---

## Optimisations déjà mises en place

Mesures actuellement utilisées :

- destruction régulière via Terraform ;
- petite configuration ECS ;
- faible trafic ;
- faible volume de logs ;
- absence de NAT Gateway ;
- environnement unique de développement.

---

## Optimisations futures

Améliorations possibles :

### ECR

- Lifecycle Policy pour supprimer automatiquement les anciennes images Docker.

---

### CloudWatch

- Réduire la durée de rétention des logs.

---

### Infrastructure

- Arrêt automatique de l'environnement hors utilisation.
- Utilisation de VPC Endpoints selon les besoins.
- Optimisation de la taille des tâches ECS.

---

## Méthodologie

Cette estimation est basée sur :

- AWS Pricing Calculator
- Documentation officielle AWS
- Configuration réelle du projet
- Hypothèses explicites décrites ci-dessus

Références :

- AWS Pricing Calculator  
- Amazon ECS Fargate Pricing  
- Elastic Load Balancing Pricing  
- Amazon ECR Pricing  
- Amazon CloudWatch Pricing  
- Amazon SNS Pricing

---

## Conclusion

L'architecture actuelle reste adaptée à un environnement de développement et de portfolio.

Le coût principal provient actuellement de :

```text
Application Load Balancer + ECS Fargate
```

L'utilisation de Terraform avec suppression régulière des ressources permet de maintenir des coûts faibles tout en conservant une architecture proche d'un environnement réel.
