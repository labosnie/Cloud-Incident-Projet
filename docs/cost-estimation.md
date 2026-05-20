# Estimation des coûts AWS — Cloud Incident Project

Région : **eu-west-3 (Paris)**  
Périmètre : services réellement déployés par le Terraform du dépôt (VPC, ECS Fargate, ALB, ECR, CloudWatch Logs, alarmes CloudWatch, SNS).

---

# Objectif

Ce document fournit une **estimation indicative** des coûts AWS pour un **environnement de développement et de portfolio**, pas pour une charge de production.

Il sert à :

- comprendre l’ordre de grandeur de la facture ;
- identifier les postes les plus sensibles ;
- justifier auprès d’un recruteur ou d’un pair les choix d’architecture **low-cost** (pas de NAT Gateway, petite tâche Fargate, destruction régulière de l’infra).

Les montants sont exprimés en **EUR** (euros), arrondis. AWS facture en **USD** sur la facture ; les valeurs ci-dessous utilisent une **conversion indicative : 1 USD ≈ 0,93 EUR** (à ajuster selon le taux du jour et la TVA éventuelle sur votre compte). Les tarifs AWS évoluent ; pour une valeur exacte, utiliser la [calculatrice de prix AWS](https://calculator.aws/) puis convertir, ou **AWS Cost Explorer** en affichage EUR si disponible.

---

# Hypothèses

Les chiffres ci-dessous supposent :

| Hypothèse | Détail |
|---|---|
| **Trafic** | Très faible : tests manuels, health checks ALB, quelques appels `/health`, `/api/error`, `/api/slow`. |
| **Utilisation** | Intermittente : quelques heures par jour ou quelques jours par mois, typique d’un apprentissage. |
| **Cycle de vie** | L’infrastructure applicative (`infra/envs/dev`) est **souvent détruite** avec `terraform destroy` après les sessions de test, ce qui **coupe** la facturation ALB, ECS, logs applicatifs, alarmes et SNS **liés à cet environnement**. |
| **ECS Fargate** | Une seule tâche : **256 unités CPU** (0,25 vCPU) et **512 Mo** de mémoire (`ecs_task_cpu` / `ecs_task_memory` par défaut dans `infra/envs/dev/variables.tf`). |
| **Rétention des logs** | **3 jours** (`ecs_log_retention_days` par défaut). |
| **Réseau** | Pas de **NAT Gateway** dans le module VPC du projet (pas de coût fixe NAT). Les tâches ECS utilisent des **subnets publics** avec `assign_public_ip` pour le pull ECR et les logs, comme prévu dans la configuration. |
| **Précision** | Ordre de grandeur **±30 %** selon le mois, les pics de test, le taux de change et les ajustements de tarifs AWS. |

---

# Tableau détaillé

| Service | Utilisation (projet réel) | Estimation mensuelle | Remarques |
|---|---|---:|---|
| **ECS Fargate** | 1 service, `desired_count = 1`, 0,25 vCPU + 512 Mo, sans Container Insights (`containerInsights` désactivé sur le cluster). | **~7–11 EUR** si la tâche tourne **24 h/24** tout le mois ; **~1–3 EUR** si elle n’est active qu’environ **25 %** du temps ; **~0 EUR** si l’environnement est détruit. | Facturation à la seconde quand la tâche est en état **RUNNING**. Pas de coût Fargate pour les seules définitions de tâche / cluster vides après `destroy`. |
| **Application Load Balancer** | 1 ALB internet-facing, HTTP port 80, réparti sur **2 AZ** (subnets publics). | **~15–20 EUR** de **coût fixe** type par mois si l’ALB existe tout le mois, **+** quelques centimes à quelques euros de **LCU** (capacité de charge) selon le nombre de requêtes et de règles. | C’est souvent le **premier poste** en environnement laissé allumé. **0 EUR** une fois `terraform destroy` (plus d’ALB). |
| **Amazon ECR** | 1 repository (`ecr_repository_name`), images légères (couche Python slim + app). | **< 1 EUR** en stockage (ordre de grandeur **0,10–0,50 EUR** pour une ou deux images de quelques centaines de Mo). Scan à la poussée : impact négligeable à ce volume. | Coût principalement **stockage**. Après `destroy` avec `force_delete` sur le repo ECR du module, le stockage applicatif disparaît avec le repo (sauf si d’autres images existent ailleurs). |
| **CloudWatch Logs** | 1 log group `/ecs/<prefix>/api`, rétention **3 jours**. | **< 1 EUR** avec faible volume de logs (quelques Mo à quelques dizaines de Mo ingérés par mois). | Ingestion + stockage court = très bon marché en dev. |
| **CloudWatch Alarms** | **2** alarmes métriques (5XX cible + latence cible), période 60 s, 2 périodes d’évaluation. | **~0,20 EUR** (ordre **0,10 EUR par alarme** standard en résolution classique, selon région et type). | Négligeable par rapport à l’ALB si l’infra tourne H24. |
| **Amazon SNS** | 1 topic + abonnement email ; quelques publications (tests + alarmes). | **~0 EUR** (souvent **< 0,01 EUR** au-delà du gratuit si trafic minimal). | La facturation SNS reste faible pour des dizaines / centaines de notifications. |
| **Réseau (transfert de données)** | Trafic sortant Internet limité (réponses HTTP via ALB, quelques tests). | **~0–2 EUR** en usage portfolio ; peut monter si gros téléchargements ou beaucoup de clients. | Pas de NAT Gateway dans ce projet = **pas** de ~30 EUR/mois de NAT. Coût data transfer sortant classique au-delà des tranches gratuites éventuelles. |
| **VPC** | VPC, subnets publics/privés, IGW, tables de routage (sans NAT). | **0 EUR** | Pas de frais horaires pour ces ressources seules ; seul le trafic peut être facturé. |
| **IAM** | Rôles ECS execution / task. | **0 EUR** | Pas de coût IAM direct. |
| **Backend Terraform (optionnel)** | Si vous avez déployé `infra/bootstrap` : bucket S3 + table DynamoDB en **PAY_PER_REQUEST** pour l’état distant. | **< 1 EUR** typiquement (stockage S3 minimal + peu d’opérations DynamoDB). | Reste souvent actif même quand `envs/dev` est détruit ; à inclure dans une vision « coût total compte » si applicable. |

---

# Coût mensuel total estimé

Synthèse pour l’environnement **applicatif** `infra/envs/dev` (ALB + ECS + monitoring + ECR + logs), **hors** backend state éventuel.

| Scénario | Description | Fourchette indicative (EUR / mois) |
|---|---|---:|
| **Estimation basse** | Infra déployée **quelques jours** dans le mois (ex. 4–8 jours de tests), puis `terraform destroy` le reste du temps. | **~5–14** |
| **Estimation moyenne** | Infra présente **environ la moitié du mois** ou quelques heures par jour en moyenne (tâche + ALB actifs sur une fraction notable du mois). | **~14–33** |
| **Si tout est laissé tourner 24/7** | 1 ALB + 1 tâche Fargate 0,25 vCPU / 512 Mo en continu, trafic toujours faible. | **~26–42** |

Ajouter **~0–1 EUR** si le bootstrap S3 + DynamoDB reste actif pour l’état Terraform.

> **Rappel** : la facture AWS arrive en USD ; ces fourchettes EUR sont des **approximations** (taux indicatif **1 USD ≈ 0,93 EUR**). Vérifier dans **Billing → Cost Explorer** (devise EUR si activée).

---

# Principales sources de coût

1. **Application Load Balancer** — Dès qu’il existe, il y a un **coût horaire** quasi fixe par mois, **indépendant** du fait que l’API reçoive 10 ou 10 000 requêtes (tant que les LCU restent faibles). C’est le poste dominant en mode « stack allumée H24 ».

2. **ECS Fargate** — Coût **proportionnel au temps** où la tâche est en **RUNNING**. Avec 0,25 vCPU et 512 Mo, c’est le **minimum courant** Fargate ; reste significatif sur un mois entier, mais maîtrisable si vous détruisez l’environnement ou réduisez `desired_count` à 0 quand vous ne testez pas (si vous gardez l’ALB, le coût ALB reste toutefois présent).

3. **Transfert de données** — Généralement **faible** pour ce projet ; à surveiller seulement si vous multipliez les gros téléchargements ou les tests intensifs depuis l’extérieur.

4. **ECR, logs, alarmes, SNS** — Souvent **secondaires** par rapport à l’ALB + Fargate pour ce type d’usage.

---

# Optimisations déjà appliquées

Ces choix sont **déjà** reflétés dans le Terraform / la doc du projet :

- **Pas de NAT Gateway** — Évite un coût fixe élevé (~30 EUR/mois) ; les tâches en subnet public avec IP publique pour le pull d’images et les logs (compromis assumé pour un labo / portfolio).
- **Taille minimale Fargate** — 256 CPU / 512 Mo pour une seule tâche.
- **Rétention logs courte** — 3 jours pour limiter le stockage CloudWatch Logs.
- **Container Insights désactivé** sur le cluster ECS — Pas de métriques additionnelles facturées via cette option.
- **Destruction régulière** avec `terraform destroy` — Supprime ALB, cibles, tâches, et la majeure partie de la facture récurrente liée à cet environnement.
- **ECR `force_delete` en dev** — Facilite le nettoyage du repository lors du destroy (évite des blocages et des oublis de coût de stockage « orphelin » sur un repo qu’on croyait supprimé).

---

# Optimisations futures

Pistes **réalistes** pour la suite du projet, sans introduire de services non listés dans votre stack actuelle :

| Piste | Intérêt coût |
|---|---|
| **Lifecycle policy ECR** | Supprimer automatiquement les anciennes images (tags non utilisés) pour limiter le stockage si vous poussez souvent des builds. |
| **Réduire encore la rétention des logs** | Passer de 3 à 1 jour en pur labo si la conformité / le debug le permet. |
| **Arrêt « logique » de l’environnement** | Mettre `ecs_desired_count = 0` quand vous ne testez pas **réduit** le coût Fargate, mais **l’ALB reste facturé** tant qu’il existe — seul `destroy` ou une évolution d’architecture supprime ce poste. |
| **Automatisation** | Pipeline ou script planifié (`destroy` en fin de journée / fin de semaine) pour les sessions d’apprentissage — discipline > outil coûteux. |
| **VPC Endpoints** | À n’envisager que si vous changez d’architecture (ex. tâches sans IP publique) ; **ajoute** un coût endpoint mais peut **réduire** le transfert de données vers Internet pour ECR/Logs — à modéliser au cas par cas ; **pas** dans votre infra actuelle. |

---

# Synthèse pour un entretien

> « Mon projet tourne en **eu-west-3** avec un **ALB**, une **tâche Fargate minimale**, **ECR**, **CloudWatch** et **SNS**. Je sais que le **ALB** et le **temps de run Fargate** sont les principaux coûts si je laisse tout allumé. En pratique je **détruis l’environnement** avec Terraform après les sessions, ce qui ramène la facture à **quelques euros par mois** en usage typique d’apprentissage. J’ai documenté des fourchettes en EUR et je vérifie la facture réelle dans **AWS Billing / Cost Explorer**. »

---

# Références

- [AWS Pricing Calculator](https://calculator.aws/)
- Tarifs par service (rechercher « Amazon EC2 Pricing » pour Fargate en pratique via la page Fargate, « Elastic Load Balancing », « Amazon ECR », « Amazon CloudWatch », « Amazon SNS ») — toujours filtrer sur **eu-west-3**, puis convertir en EUR si besoin.

---

