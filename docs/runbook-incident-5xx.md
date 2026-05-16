# Runbook — Incident HTTP 5XX sur ALB / ECS

## Objectif

Ce runbook décrit la procédure à suivre lorsqu’une alarme CloudWatch détecte une augmentation des erreurs HTTP 5XX sur l’Application Load Balancer.

L’objectif est d’identifier rapidement si le problème vient :

- de l’application FastAPI ;
- d’une task ECS arrêtée ou unhealthy ;
- d’une image Docker absente ou incorrecte ;
- d’un problème de health check ;
- d’un problème réseau ou Security Group ;
- d’une mauvaise configuration CloudWatch ;
- d’un problème de notification SNS.

Ce document est lié au projet **Cloud Incident Project** et sert à documenter une procédure d’investigation simple, claire et reproductible.

---

## Contexte technique

L’application est déployée sur **AWS ECS Fargate** derrière un **Application Load Balancer**.

La détection d’incident repose sur la métrique CloudWatch suivante :

```text
HTTPCode_Target_5XX_Count
```

Lorsqu’un seuil d’erreurs 5XX est dépassé, une alarme CloudWatch passe en état `ALARM` et déclenche une notification email via Amazon SNS.

Architecture simplifiée :

```text
Utilisateur
   |
   v
Application Load Balancer
   |
   v
ECS Fargate - API FastAPI
   |
   v
CloudWatch Logs

Application Load Balancer
   |
   v
CloudWatch Metrics
   |
   v
CloudWatch Alarm
   |
   v
SNS Topic
   |
   v
Email Alert
```

---

## Symptômes possibles

Un incident 5XX peut se manifester par un ou plusieurs des symptômes suivants :

- email SNS reçu ;
- alarme CloudWatch en état `ALARM` ;
- erreurs HTTP 500 sur l’API ;
- endpoint `/health` indisponible ;
- ALB qui retourne `503 Service Temporarily Unavailable` ;
- ECS task en état `STOPPED` ;
- aucune target healthy dans le Target Group ;
- logs applicatifs contenant des exceptions ;
- absence de datapoints dans CloudWatch ;
- notification SNS non reçue malgré la génération d’erreurs.

---

## Étape 1 — Vérifier l’état de l’alarme CloudWatch

### Commande

```powershell
aws cloudwatch describe-alarms `
  --region eu-west-3 `
  --alarm-names cloudops-incident-dev-alb-target-5xx `
  --query "MetricAlarms[0].{State:StateValue,Reason:StateReason}"
```

### Résultat attendu en cas d’incident

```text
State = ALARM
```

### Interprétation

| État | Signification |
|---|---|
| `OK` | Le seuil d’alerte n’est pas dépassé |
| `ALARM` | L’incident est détecté |
| `INSUFFICIENT_DATA` | CloudWatch ne reçoit pas assez de données |

### Points à vérifier

Si l’alarme reste en `OK` ou `INSUFFICIENT_DATA`, vérifier :

- que des erreurs HTTP 500 sont réellement générées ;
- que les dimensions CloudWatch sont correctes ;
- que l’alarme observe bien le bon ALB et le bon Target Group ;
- que la période d’évaluation de l’alarme est suffisante.

---

## Étape 2 — Vérifier que l’ALB répond

### Récupérer le DNS de l’ALB

```powershell
$albDns = aws elbv2 describe-load-balancers `
  --names cloudops-incident-dev-alb `
  --region eu-west-3 `
  --query "LoadBalancers[0].DNSName" `
  --output text

$alb = "http://$albDns"
```

### Tester le health check

```powershell
curl.exe -i "$alb/health"
```

### Résultat attendu

```text
HTTP/1.1 200 OK
```

### Interprétation

| Résultat | Signification possible |
|---|---|
| `200 OK` | L’application répond correctement sur `/health` |
| `404 Not Found` | Mauvais endpoint testé |
| `500 Internal Server Error` | Erreur applicative |
| `503 Service Temporarily Unavailable` | L’ALB n’a aucune target healthy |
| Timeout | Problème réseau, ALB, Security Group ou service indisponible |

### Point important

Un `503` sur l’ALB ne signifie pas forcément que l’ALB est cassé.

Cela signifie souvent :

```text
Client → ALB : OK
ALB → Target Group : aucune cible healthy
Target Group → ECS : problème probable
```

---

## Étape 3 — Vérifier le service ECS

### Commande

```powershell
aws ecs describe-services `
  --cluster cloudops-incident-dev-ecs `
  --services cloudops-incident-dev-api `
  --region eu-west-3 `
  --query "services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Events:events[0:5]}"
```

### Points à vérifier

- `status`
- `desiredCount`
- `runningCount`
- `pendingCount`
- derniers événements ECS

### Interprétation

| Observation | Signification possible |
|---|---|
| `desiredCount = 1`, `runningCount = 1` | Une task tourne |
| `desiredCount = 1`, `runningCount = 0` | ECS n’arrive pas à maintenir la task |
| `pendingCount > 0` | ECS essaie de démarrer une task |
| Événement `CannotPullContainerError` | Problème d’image Docker / ECR |
| Événement `health checks failed` | Le health check ALB échoue |
| Événement `service reached steady state` | Le service est stable |

---

## Étape 4 — Lister les tasks ECS

### Commande

```powershell
aws ecs list-tasks `
  --cluster cloudops-incident-dev-ecs `
  --region eu-west-3
```

### Si une task existe

Récupérer son ARN, puis lancer :

```powershell
aws ecs describe-tasks `
  --cluster cloudops-incident-dev-ecs `
  --region eu-west-3 `
  --tasks <TASK_ARN> `
  --query "tasks[0].{lastStatus:lastStatus,desiredStatus:desiredStatus,stopCode:stopCode,stoppedReason:stoppedReason,containers:containers[*].{name:name,lastStatus:lastStatus,exitCode:exitCode,reason:reason}}"
```

### Points à vérifier

- `lastStatus`
- `desiredStatus`
- `stopCode`
- `stoppedReason`
- `exitCode`
- `containers.reason`

### Exemple de problème possible

```text
CannotPullContainerError
```

Cela indique qu’ECS n’arrive pas à récupérer l’image Docker depuis ECR.

### Exemple d’interprétation

| Valeur | Interprétation |
|---|---|
| `RUNNING` | La task tourne |
| `STOPPED` | La task s’est arrêtée |
| `TaskFailedToStart` | ECS n’a pas réussi à démarrer la task |
| `Essential container in task exited` | Le container principal a crash |
| `CannotPullContainerError` | ECS ne peut pas récupérer l’image Docker |

---

## Étape 5 — Vérifier les logs CloudWatch

Les logs de l’application ECS sont envoyés dans CloudWatch Logs.

### Log group

```text
/ecs/cloudops-incident-dev/api
```

### Lister les log streams récents

```powershell
aws logs describe-log-streams `
  --log-group-name "/ecs/cloudops-incident-dev/api" `
  --region eu-west-3 `
  --order-by LastEventTime `
  --descending `
  --max-items 5
```

### Lire les logs d’un stream

```powershell
aws logs get-log-events `
  --log-group-name "/ecs/cloudops-incident-dev/api" `
  --log-stream-name "<LOG_STREAM_NAME>" `
  --region eu-west-3
```

### Ce qu’il faut chercher

- exception Python ;
- erreur FastAPI ;
- erreur Uvicorn ;
- problème de variable d’environnement ;
- problème de connexion à la base de données ;
- problème de port ;
- crash applicatif ;
- stack trace.

### Interprétation

Les logs permettent de savoir si l’incident vient du code applicatif ou de l’infrastructure.

---

## Étape 6 — Vérifier le Target Group

### Récupérer l’ARN du Target Group

```powershell
$tgArn = aws elbv2 describe-target-groups `
  --names cloudops-incident-dev-tg `
  --region eu-west-3 `
  --query "TargetGroups[0].TargetGroupArn" `
  --output text
```

### Vérifier la santé des targets

```powershell
aws elbv2 describe-target-health `
  --target-group-arn $tgArn `
  --region eu-west-3
```

### États possibles

| État | Signification |
|---|---|
| `healthy` | La target répond correctement |
| `unhealthy` | La target ne passe pas le health check |
| `initial` | La target est en cours d’enregistrement |
| `draining` | La target est en cours de suppression |
| `unused` | La target n’est pas utilisée par le Load Balancer |

### Si la target est unhealthy

Vérifier :

- que l’application écoute bien sur le port attendu ;
- que le health check pointe vers `/health` ;
- que `/health` retourne bien HTTP 200 ;
- que le Security Group ECS autorise le trafic depuis l’ALB ;
- que la task ECS est bien en état `RUNNING`.

---

## Étape 7 — Vérifier l’image Docker dans ECR

### Commande

```powershell
aws ecr describe-images `
  --repository-name cloudops-incident-api-dev `
  --region eu-west-3 `
  --query "imageDetails[*].imageTags"
```

### Résultat attendu

Le tag utilisé par ECS doit être présent.

Exemple :

```text
latest
```

### Si l’image est absente

Reconstruire l’image :

```powershell
docker build -t cloudops-incident-api .
```

Se connecter à ECR :

```powershell
aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin 483647879855.dkr.ecr.eu-west-3.amazonaws.com
```

Tagger l’image :

```powershell
docker tag cloudops-incident-api:latest 483647879855.dkr.ecr.eu-west-3.amazonaws.com/cloudops-incident-api-dev:latest
```

Pousser l’image :

```powershell
docker push 483647879855.dkr.ecr.eu-west-3.amazonaws.com/cloudops-incident-api-dev:latest
```

Forcer un redéploiement ECS :

```powershell
aws ecs update-service `
  --cluster cloudops-incident-dev-ecs `
  --service cloudops-incident-dev-api `
  --force-new-deployment `
  --region eu-west-3
```

---

## Étape 8 — Vérifier les dimensions CloudWatch

Si l’alarme reste en `OK` ou affiche :

```text
no datapoints were received
```

il faut vérifier les dimensions CloudWatch.

### Commande

```powershell
aws cloudwatch describe-alarms `
  --region eu-west-3 `
  --alarm-names cloudops-incident-dev-alb-target-5xx `
  --query "MetricAlarms[0].Dimensions"
```

### Dimensions attendues

```text
LoadBalancer = app/cloudops-incident-dev-alb/<id>
TargetGroup  = targetgroup/cloudops-incident-dev-tg/<id>
```

### Erreur déjà rencontrée

Valeur incorrecte :

```text
TargetGroup = cloudops-incident-dev-tg/<id>
```

Valeur correcte :

```text
TargetGroup = targetgroup/cloudops-incident-dev-tg/<id>
```

### Point important

Pour les métriques ALB, CloudWatch attend le suffixe complet du Target Group :

```text
targetgroup/<name>/<id>
```

Si le préfixe `targetgroup/` manque, CloudWatch ne reçoit aucun datapoint.

---

## Étape 9 — Vérifier SNS

Si l’alarme passe bien en `ALARM` mais qu’aucun email n’est reçu, vérifier SNS.

### Lister les subscriptions

```powershell
aws sns list-subscriptions `
  --region eu-west-3
```

### Tester le topic SNS directement

```powershell
aws sns publish `
  --topic-arn arn:aws:sns:eu-west-3:483647879855:cloudops-incident-dev-alerts `
  --subject "Test SNS alarm topic" `
  --message "Test direct du topic SNS utilise par CloudWatch Alarm." `
  --region eu-west-3
```

### Interprétation

| Résultat | Signification |
|---|---|
| Email reçu | SNS fonctionne |
| Pas d’email | Problème de subscription, email non confirmé, mauvais topic ou spam |
| `PendingConfirmation` | L’abonnement email n’a pas été confirmé |

### Point important

Il faut tester le même topic SNS que celui utilisé par l’alarme CloudWatch.

---

## Étape 10 — Simuler l’incident 5XX

### Récupérer l’ALB

```powershell
$albDns = aws elbv2 describe-load-balancers `
  --names cloudops-incident-dev-alb `
  --region eu-west-3 `
  --query "LoadBalancers[0].DNSName" `
  --output text

$alb = "http://$albDns"
```

### Générer plusieurs erreurs 500

```powershell
1..30 | ForEach-Object {
  curl.exe -s -o NUL -w "req $_ -> HTTP %{http_code}`n" "$alb/api/error"
  Start-Sleep -Seconds 5
}
```

### Résultat attendu

```text
req 1 -> HTTP 500
req 2 -> HTTP 500
req 3 -> HTTP 500
...
```

### Vérifier l’état de l’alarme

```powershell
aws cloudwatch describe-alarms `
  --region eu-west-3 `
  --alarm-names cloudops-incident-dev-alb-target-5xx `
  --query "MetricAlarms[0].{State:StateValue,Reason:StateReason}"
```

### Résultat attendu

```text
State = ALARM
```

Une notification email SNS doit être reçue.

---

## Étape 11 — Causes probables et actions

| Symptôme | Cause probable | Action |
|---|---|---|
| ALB retourne 503 | Aucune target healthy | Vérifier ECS service et Target Group |
| Task ECS STOPPED | Container crash ou image absente | Lire `stoppedReason` |
| `CannotPullContainerError` | Image absente dans ECR | Build, tag et push image |
| `/health` ne répond pas | App crash ou mauvais port | Lire les logs CloudWatch |
| Alarme sans datapoints | Mauvaise dimension CloudWatch | Vérifier `LoadBalancer` et `TargetGroup` |
| SNS ne reçoit rien | Subscription non confirmée ou mauvais topic | Tester `aws sns publish` |
| Target unhealthy | Health check échoue | Vérifier endpoint `/health` et port 8000 |
| Email non reçu | Mauvais topic SNS ou mail non confirmé | Vérifier SNS subscription |
| Timeout | Problème réseau ou Security Group | Vérifier ALB, SG et ECS |

---

## Étape 12 — Résolution de l’incident simulé

Dans le scénario de test actuel :

- l’incident est volontairement déclenché via `/api/error` ;
- l’ALB reçoit des réponses HTTP 500 ;
- CloudWatch détecte les erreurs 5XX ;
- l’alarme passe en état `ALARM` ;
- SNS envoie une notification email.

La résolution consiste à confirmer qu’il s’agit bien d’un endpoint de test et non d’une erreur applicative réelle.

Dans un cas réel, il faudrait ensuite :

- lire les logs applicatifs ;
- identifier la route ou le composant fautif ;
- corriger le code ou la configuration ;
- redéployer proprement ;
- vérifier que l’alarme repasse en `OK` ;
- documenter l’incident.

---

## Étape 13 — Actions préventives

Améliorations possibles :

- ajouter des logs applicatifs plus détaillés ;
- ajouter un dashboard CloudWatch ;
- ajouter une alarme sur le nombre de targets unhealthy ;
- ajouter une alarme sur le CPU ECS ;
- ajouter une alarme sur la mémoire ECS ;
- ajouter une alarme de latence ;
- ajouter un pipeline CI/CD ;
- ajouter une stratégie de rollback ;
- ajouter des tests automatisés avant déploiement ;
- ajouter un post-mortem après chaque incident simulé ;
- ajouter un suivi des erreurs applicatives plus précis ;
- ajouter OpenTelemetry à plus long terme.

---

## Checklist rapide d’investigation

```text
1. Alerte SNS reçue ?
2. Alarme CloudWatch en ALARM ?
3. /health répond en 200 ?
4. ECS service a bien une task RUNNING ?
5. Les logs CloudWatch montrent-ils une erreur ?
6. Le Target Group a-t-il une target healthy ?
7. L’image Docker existe-t-elle dans ECR ?
8. Les dimensions CloudWatch sont-elles correctes ?
9. Le topic SNS est-il le bon ?
10. L’incident est-il applicatif ou infrastructure ?
```

---

## Résumé opérationnel

```text
Alerte SNS reçue
→ Vérifier l’état CloudWatch Alarm
→ Tester /health
→ Vérifier ECS service
→ Vérifier ECS tasks
→ Lire CloudWatch Logs
→ Vérifier Target Group
→ Vérifier image ECR
→ Vérifier dimensions CloudWatch
→ Vérifier SNS
→ Identifier la cause
→ Corriger
→ Documenter l’incident
```

---

## Conclusion

Ce runbook permet de structurer l’investigation d’un incident HTTP 5XX sur une architecture AWS simple basée sur ALB, ECS Fargate, CloudWatch et SNS.

L’objectif n’est pas uniquement de recevoir une alerte, mais de savoir quoi faire après l’alerte.

Ce document sera enrichi au fur et à mesure de l’évolution du projet.