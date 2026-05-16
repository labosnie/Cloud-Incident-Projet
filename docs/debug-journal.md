# Debug Journal — CloudOps Incident Platform

Ce document regroupe les principaux problèmes rencontrés pendant la construction du projet **Cloud Incident Project**.

L’objectif n’est pas seulement de noter les erreurs, mais de documenter le raisonnement de diagnostic : symptôme, cause, investigation, résolution et apprentissage.

Ce journal montre les problèmes réels rencontrés lors de la mise en place d’une infrastructure Cloud/DevOps basée sur AWS, Terraform, Docker, ECS Fargate, ALB, CloudWatch et SNS.

---

## Sommaire

 1.[Confusion entre ECR et ECS](#2-confusion-entre-ecr-et-ecs)
 2.[Erreur AWS Security Group avec caractères non-ASCII](#3-erreur-aws-security-group-avec-caractères-non-ascii)
 3.[ALB en 503 Service Temporarily Unavailable](#4-alb-en-503-service-temporarily-unavailable)
 4.[ECS CannotPullContainerError — image Docker absente dans ECR](#5-ecs-cannotpullcontainererror--image-docker-absente-dans-ecr)
 5.[Docker Desktop non démarré sur Windows](#6-docker-desktop-non-démarré-sur-windows)
 6.[Erreur Docker login vers ECR — 400 Bad Request](#7-erreur-docker-login-vers-ecr--400-bad-request)
 7.[Confusion PowerShell : curl n’est pas toujours le vrai curl](#8-confusion-powershell--curl-nest-pas-toujours-le-vrai-curl)
 8.[Endpoint `/` en 404 Not Found](#9-endpoint--en-404-not-found)
 9.[CloudWatch Alarm ne déclenchait pas d’email](#10-cloudwatch-alarm-ne-déclenchait-pas-demail)
 10.[Test du mauvais topic SNS](#11-test-du-mauvais-topic-sns)
 11.[CloudWatch Alarm sans datapoints](#12-cloudwatch-alarm-sans-datapoints)
 12.[Validation réussie de l’alarme CloudWatch + SNS](#13-validation-réussie-de-lalarme-cloudwatch--sns)
 13.[Terraform destroy bloqué par Internet Gateway](#14-terraform-destroy-bloqué-par-internet-gateway)
 14.[Terraform destroy bloqué par ECR repository non vide](#15-terraform-destroy-bloqué-par-ecr-repository-non-vide)
 15.[Terraform lancé depuis le mauvais dossier](#16-terraform-lancé-depuis-le-mauvais-dossier)
 

1. Je pensais que le module ECR pouvait suffire à lancer mon application. Mauvaise compréhension intial de ma part entre le service ECS et ECR

2.Pendant terraform apply, AWS a refusé de créer un Security Group : La description du Security Group contenait des caractères accentués ou typographiques, par exemple :
HTTP entrant vers l’ALB, Les caractères comme é, à, ou l’apostrophe typographique ’ peuvent poser problème dans certaines propriétés AWS.

3.L’ALB était bien accessible, mais il n’avait aucune target ECS healthy derrière lui. Analyse de la task ECS pour identifier la cause réelle.
La cause finale était liée à l’image Docker absente dans ECR.

4.L'image docker avec le tag latest n'a pas étais poussé vers ECR. Terraform peut créer correctement l’infrastructure ECS, mais ECS ne pourra pas lancer le container si l’image référencée dans la task definition n’existe pas dans ECR.
Le déploiement applicatif nécessite donc deux étapes complémentaires :
- Créer l’infrastructure
- Pousser l’image Docker dans ECR

5.Docker Desktop non démarré sur windows

6.La commande du login vers ECR échouait. Utilisation d’une commande alternative avec cmd /c ou variable PowerShell si nécessaire.

7.En lançant "curl http://<alb_dns>/health" PowerShell affichait un avertissement lié à Invoke-WebRequest.
Sur Windows PowerShell, il faut parfois utiliser curl.exe explicitement pour obtenir le comportement attendu de curl.

8.Une erreur 404 sur / ne signifie pas forcément que l’application est cassée.
Il faut tester les endpoints réellement définis par l’API.

9.Après avoir généré des erreurs avec /api/error, aucun email d’alerte n’était reçu. 
Pour diagnostiquer une alerte CloudWatch/SNS, il faut isoler chaque composant :

- Vérifier que SNS fonctionne.
- Vérifier que l’abonnement email est confirmé.
- Vérifier que l’alarme passe bien en ALARM.
- Vérifier que l’alarme observe les bonnes métriques.
- Vérifier que les dimensions CloudWatch sont correctes.

10.Un email de test SNS était reçu, mais les alarmes CloudWatch n’envoyaient toujours rien. Recevoir un email SNS ne suffit pas.
Il faut vérifier que le topic testé est bien celui utilisé par l’alarme CloudWatch.

11.Les métriques ALB dans CloudWatch nécessitent des dimensions exactes. Pour un Target Group, CloudWatch attend le suffixe complet.

12.Une chaîne d’alerting CloudWatch/SNS doit être validée de bout en bout :
Erreur applicative
- métrique ALB
- alarme CloudWatch
- topic SNS
- email reçu

13.Pendant terraform destroy, Terraform a échoué sur l’Internet Gateway. AWS supprime certaines ressources de façon asynchrone.
Il faut parfois attendre que les dépendances réseau soient complètement supprimées avant que Terraform puisse détruire le VPC ou l’Internet Gateway.

14.Pendant terraform destroy, Terraform a échoué sur ECR. Par défaut, AWS ne supprime pas un repository ECR qui contient encore des images.
En environnement dev jetable, force_delete = true peut simplifier la destruction. Cette option est pratique en développement, mais doit être utilisée avec prudence en production.

