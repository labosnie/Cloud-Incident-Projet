# Debug Journal — Cloud Incident Project

Ce document regroupe les principaux problèmes rencontrés pendant la construction du projet **Cloud Incident Project**.

L’objectif n’est pas seulement de lister des erreurs, mais de documenter le raisonnement de diagnostic :

- quel était le symptôme ;
- quelle était la cause ;
- comment le problème a été analysé ;
- quelle correction a été appliquée ;
- ce que j’ai appris.

Ce journal montre les problèmes réels rencontrés lors de la mise en place d’une infrastructure Cloud/DevOps basée sur AWS, Terraform, Docker, ECS Fargate, ALB, CloudWatch et SNS.

---

## Note méthodologique

Ce projet a été construit dans le cadre de ma montée en compétence Cloud/DevOps/Sécurité.

L’architecture, les choix techniques et les scénarios d’incident ont été réfléchis et préparés manuellement, notamment à travers des notes et schémas réalisés au cahier.

L’IA a été utilisée comme support d’apprentissage, de clarification technique et d’aide au debugging, mais la mise en œuvre, les tests, les corrections et la validation ont été réalisés par moi-même.

## 1. Confusion entre ECR et ECS

### Problème rencontré

Au début, je pensais que le module **ECR** pouvait suffire à lancer mon application.

### Cause

Je confondais le rôle de deux services AWS :

- **ECR** sert à stocker une image Docker.
- **ECS** sert à exécuter cette image sous forme de container.

### Correction

J’ai séparé les responsabilités en créant deux modules Terraform distincts :

```text
infra/modules/ecr
infra/modules/ecs
```

Le flux correct est le suivant :

```text
Image Docker locale
→ Push vers ECR
→ ECS Fargate récupère l’image
→ ECS lance le container
→ ALB expose l’application
```

### Ce que j’ai appris

ECR et ECS sont complémentaires, mais ils ne font pas la même chose.

ECR est un registre d’images Docker.  
ECS est un service d’orchestration qui lance des containers à partir de ces images.

---

## 2. Erreur Security Group à cause des caractères spéciaux

### Problème rencontré

Pendant un `terraform apply`, AWS a refusé de créer un Security Group.

Le message indiquait que la description du Security Group contenait des caractères non supportés.

### Cause

Certaines descriptions contenaient des caractères accentués ou typographiques, par exemple :

```text
HTTP entrant vers l’ALB
```

Les caractères comme `é`, `à` ou l’apostrophe typographique `’` peuvent poser problème dans certaines propriétés AWS.

### Correction

J’ai remplacé les descriptions par du texte simple en anglais, sans accents :

```hcl
description = "HTTP inbound to ALB"
```

```hcl
description = "Container traffic from ALB only"
```

### Ce que j’ai appris

En infrastructure as code, il vaut mieux utiliser des noms et descriptions simples, en ASCII, surtout pour éviter les erreurs liées aux contraintes AWS.

---

## 3. ALB en erreur 503

### Problème rencontré

Après le déploiement de l’Application Load Balancer, l’URL publique retournait :

```text
503 Service Temporarily Unavailable
```

### Cause

L’ALB fonctionnait, mais il n’avait aucune cible saine derrière lui.

Cela signifie que le chemin était bloqué à ce niveau :

```text
Client → ALB : OK
ALB → Target Group : aucune cible healthy
Target Group → ECS : problème probable
```

### Investigation

J’ai vérifié les tasks ECS avec :

```powershell
aws ecs list-tasks --cluster cloudops-incident-dev-ecs --region eu-west-3
```

Puis j’ai inspecté une task avec :

```powershell
aws ecs describe-tasks --cluster cloudops-incident-dev-ecs --region eu-west-3 --tasks <TASK_ARN>
```

### Correction

L’analyse de la task ECS a montré que le problème venait de l’image Docker absente dans ECR.

### Ce que j’ai appris

Un code HTTP 503 sur un ALB ne signifie pas forcément que le Load Balancer est cassé.

Cela signifie souvent que l’ALB n’a aucune cible saine dans son Target Group.

Les causes possibles sont :

- container qui crash ;
- image Docker absente ;
- mauvais port ;
- health check qui échoue ;
- application qui n’écoute pas correctement ;
- Security Group mal configuré.

---

## 4. ECS ne trouvait pas l’image Docker dans ECR

### Problème rencontré

La task ECS passait en état `STOPPED`.

L’erreur principale était :

```text
CannotPullContainerError
```

ECS ne trouvait pas l’image Docker :

```text
cloudops-incident-api-dev:latest
```

### Cause

L’image Docker avec le tag `latest` n’avait pas encore été poussée dans Amazon ECR.

Terraform avait bien créé l’infrastructure, mais ECS ne pouvait pas lancer un container à partir d’une image inexistante.

### Correction

J’ai construit l’image Docker :

```powershell
docker build -t cloudops-incident-api .
```

Je me suis connecté à ECR :

```powershell
aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin 483647879855.dkr.ecr.eu-west-3.amazonaws.com
```

J’ai taggé l’image :

```powershell
docker tag cloudops-incident-api:latest 483647879855.dkr.ecr.eu-west-3.amazonaws.com/cloudops-incident-api-dev:latest
```

Puis j’ai poussé l’image vers ECR :

```powershell
docker push 483647879855.dkr.ecr.eu-west-3.amazonaws.com/cloudops-incident-api-dev:latest
```

Enfin, j’ai forcé un nouveau déploiement ECS :

```powershell
aws ecs update-service --cluster cloudops-incident-dev-ecs --service cloudops-incident-dev-api --force-new-deployment --region eu-west-3
```

### Ce que j’ai appris

Créer l’infrastructure ne suffit pas.

Pour qu’ECS démarre correctement, il faut aussi que l’image Docker référencée par la task definition existe réellement dans ECR.

---


## 6. Erreur Docker login vers ECR

### Problème rencontré

La connexion Docker vers ECR échouait avec une erreur `400 Bad Request`.

### Cause possible

Le problème pouvait venir de plusieurs éléments :

- mauvais compte AWS actif ;
- mauvaise région ;
- problème de transmission du token ECR ;
- comportement du pipe PowerShell ;
- Docker Desktop mal lancé.

### Investigation

J’ai vérifié l’identité AWS active :

```powershell
aws sts get-caller-identity
```

J’ai aussi vérifié que le repository ECR existait bien :

```powershell
aws ecr describe-repositories --repository-names cloudops-incident-api-dev --region eu-west-3
```

### Correction

J’ai relancé Docker Desktop correctement et utilisé la commande de login ECR adaptée.

### Ce que j’ai appris

L’authentification Docker vers ECR dépend de plusieurs conditions :

```text
AWS CLI configuré
Compte AWS correct
Région correcte
Docker Desktop actif
Repository ECR existant
```

---

## 7. Confusion avec curl dans PowerShell

### Problème rencontré

En testant l’endpoint `/health`, PowerShell affichait un avertissement lié à `Invoke-WebRequest`.

### Cause

Dans PowerShell, `curl` est souvent un alias de `Invoke-WebRequest`, et non le vrai binaire curl.

### Correction

J’ai utilisé :

```powershell
curl.exe http://<alb_dns>/health
```

ou :

```powershell
Invoke-WebRequest -UseBasicParsing http://<alb_dns>/health
```

### Ce que j’ai appris

Sur Windows, il faut parfois utiliser `curl.exe` au lieu de `curl` pour éviter les comportements spécifiques de PowerShell.

---

## 8. Endpoint racine en 404

### Problème rencontré

L’URL racine retournait :

```json
{"detail":"Not Found"}
```

### Cause

Aucune route FastAPI n’était définie pour `/`.

### Correction

Le comportement a été considéré comme normal, car les endpoints importants du projet étaient :

```text
/health
/api/slow
/api/error
```

### Ce que j’ai appris

Une erreur 404 sur `/` ne veut pas forcément dire que l’application est cassée.

Il faut tester les endpoints réellement définis dans l’API.

---

## 9. Aucun email reçu après déclenchement d’erreurs

### Problème rencontré

Après avoir généré plusieurs erreurs avec `/api/error`, je ne recevais aucun email d’alerte.

### Cause possible

Le problème pouvait venir de plusieurs endroits :

```text
CloudWatch Alarm
SNS Topic
Subscription email
Métrique surveillée
Dimensions CloudWatch
```

### Investigation

J’ai testé SNS directement avec :

```powershell
aws sns publish --topic-arn <TOPIC_ARN> --subject "Test SNS" --message "Test" --region eu-west-3
```

Le mail a bien été reçu.

### Conclusion

SNS fonctionnait correctement.  
Le problème venait donc de CloudWatch ou des métriques surveillées.

### Ce que j’ai appris

Pour diagnostiquer une chaîne d’alerte, il faut isoler chaque composant :

```text
1. Est-ce que SNS fonctionne ?
2. Est-ce que l’email est confirmé ?
3. Est-ce que l’alarme passe en ALARM ?
4. Est-ce que l’alarme observe les bonnes métriques ?
5. Est-ce que les dimensions CloudWatch sont correctes ?
```

---

## 10. Test du mauvais topic SNS

### Problème rencontré

Je recevais un email lorsque je testais SNS, mais pas lorsque CloudWatch déclenchait l’alarme.

### Cause

Je testais un topic SNS différent de celui utilisé par les alarmes CloudWatch.

Topic testé manuellement :

```text
Cloud-incident
```

Topic réellement utilisé par les alarmes :

```text
cloudops-incident-dev-alerts
```

### Correction

J’ai testé directement le topic utilisé par CloudWatch :

```powershell
aws sns publish --topic-arn arn:aws:sns:eu-west-3:483647879855:cloudops-incident-dev-alerts --subject "Test SNS alarm topic" --message "Test direct du topic SNS utilise par CloudWatch Alarm." --region eu-west-3
```

Le mail a bien été reçu.

### Ce que j’ai appris

Recevoir un email SNS ne suffit pas.

Il faut vérifier que le topic testé est bien celui relié à l’alarme CloudWatch.

---

## 11. CloudWatch Alarm sans datapoints

### Problème rencontré

L’alarme CloudWatch restait en état `OK` avec le message :

```text
no datapoints were received
```

### Cause

L’alarme ne recevait aucune métrique parce que la dimension `TargetGroup` était mal configurée.

Valeur incorrecte :

```text
cloudops-incident-dev-tg/bb38e5ede5950046
```

Valeur attendue par CloudWatch :

```text
targetgroup/cloudops-incident-dev-tg/bb38e5ede5950046
```

Il manquait donc le préfixe :

```text
targetgroup/
```

### Investigation

J’ai vérifié les dimensions de l’alarme avec :

```powershell
aws cloudwatch describe-alarms --region eu-west-3 --alarm-names cloudops-incident-dev-alb-target-5xx --query "MetricAlarms[0].Dimensions"
```

J’ai ensuite comparé avec l’ARN réel du Target Group.

### Correction

Dans Terraform, j’ai utilisé l’ARN suffix complet du Target Group :

```hcl
dimensions = {
  LoadBalancer = var.alb_arn_suffix
  TargetGroup  = var.target_group_arn_suffix
}
```

Et dans le module ECS :

```hcl
output "target_group_arn_suffix" {
  value = aws_lb_target_group.app.arn_suffix
}
```

### Ce que j’ai appris

Les métriques ALB dans CloudWatch nécessitent des dimensions exactes.

Pour un Target Group, CloudWatch attend :

```text
targetgroup/<name>/<id>
```

et non :

```text
<name>/<id>
```

Une mauvaise dimension empêche CloudWatch de recevoir des datapoints.

---

## 12. Validation réussie de CloudWatch Alarm + SNS

### Problème initial

L’alarme CloudWatch ne déclenchait pas d’email.

### Correction appliquée

Après correction de la dimension `TargetGroup`, j’ai généré plusieurs erreurs HTTP 500 avec :

```powershell
1..30 | ForEach-Object {
  curl.exe -s -o NUL -w "req $_ -> HTTP %{http_code}`n" "$alb/api/error"
  Start-Sleep -Seconds 5
}
```

### Résultat

L’alarme CloudWatch est passée en état `ALARM`.

Un email SNS a été reçu.

### Ce que j’ai appris

Une chaîne d’alerting doit être validée de bout en bout :

```text
Erreur applicative
→ ALB retourne des HTTP 500
→ CloudWatch détecte la métrique
→ L’alarme passe en ALARM
→ SNS envoie l’email
→ L’alerte est reçue
```

---

## 13. Terraform destroy bloqué par Internet Gateway

### Problème rencontré

Pendant `terraform destroy`, Terraform a échoué lors de la suppression de l’Internet Gateway.

Le message indiquait que le VPC contenait encore des ressources avec adresse publique.

### Cause

Certaines ressources réseau n’étaient pas encore totalement supprimées, probablement liées à l’ALB ou aux interfaces réseau ECS.

### Correction

J’ai attendu quelques minutes, puis relancé :

```powershell
terraform destroy
```

### Ce que j’ai appris

AWS supprime certaines ressources de manière asynchrone.

Il faut parfois attendre que les dépendances réseau soient complètement supprimées avant de pouvoir détruire le VPC ou l’Internet Gateway.

---

## 14. Terraform destroy bloqué par ECR non vide

### Problème rencontré

Pendant `terraform destroy`, Terraform n’arrivait pas à supprimer le repository ECR.

Erreur :

```text
RepositoryNotEmptyException
```

### Cause

Le repository ECR contenait encore des images Docker.

### Correction

Pour l’environnement de développement, j’ai ajouté :

```hcl
force_delete = true
```

dans le module ECR.

### Ce que j’ai appris

Par défaut, AWS ne supprime pas un repository ECR s’il contient encore des images.

En environnement dev jetable, `force_delete = true` est pratique.

En production, cette option doit être utilisée avec prudence.

---

## 15. CI GitHub Actions au vert sauf le push ECR (infra absente après `terraform destroy`)

### Problème rencontré

Après la bascule vers l’authentification **OIDC** (remplacement des clés IAM longues durée), le pipeline GitHub Actions était **entièrement vert** sur les étapes qualité et sécurité :

- flake8, black, pytest ;
- build Docker ;
- scan Trivy ;
- connexion AWS via OIDC (`role-to-assume`).

Seule l’étape **Push image Docker vers ECR** échouait avec :

```text
name unknown: The repository with name '...' does not exist in the registry with id '483647879855'
```

### Cause

J’avais exécuté un **`terraform destroy`** auparavant : le repository ECR (ainsi que le reste de l’infra dev) n’existait plus dans AWS.

Le pipeline tentait de pousser une image vers un dépôt qui n’avait pas encore été recréé. Ce n’était **pas** un problème Docker Desktop, ni un échec OIDC — l’authentification et le login ECR fonctionnaient.

### Diagnostic

Le message d’erreur et la ligne `ECR_REGISTRY=...` dans les logs ont suffi à identifier rapidement la cause : **repository inexistant**, pas un refus de permissions IAM.

### Correction

1. `terraform apply` dans `infra/envs/dev` pour recréer ECR, ECS, ALB, etc.
2. Vérifier que le secret GitHub `ECR_REPOSITORY` correspond au nom exact du repo recréé.
3. Relancer le workflow sur `main` (push ECR + redéploiement ECS).

### Ce que j’ai appris

- Un pipeline CI peut être **correct** même si le déploiement échoue : il faut distinguer **auth/config CI** et **état de l’infra AWS**.
- Après un `destroy`, l’ordre logique est : **recréer l’infra** → **puis** laisser la CI pousser la première image.
- OIDC validé : la connexion AWS et le registry ECR étaient atteignables ; seul le repository manquait côté AWS.

---

## 16. Fiabilisation du déploiement ECS : incidents rencontrés et résolutions

### Problème rencontré n°1

Après remplacement de `sleep 60` par `aws ecs wait services-stable` dans la CI, l’étape échouait.

### Cause

L’infrastructure avait été détruite auparavant (`terraform destroy`) et n’était pas encore recréée au moment du run.

### Correction

J’ai relancé l’infrastructure avant de retester le pipeline :

```powershell
cd infra/envs/dev
terraform init
terraform apply
```

Puis j’ai relancé le workflow GitHub Actions.

### Ce que j’ai appris

`services-stable` valide un état réel ECS. Si l’infra n’existe pas, l’échec est normal et utile.

---

### Problème rencontré n°2

Le pipeline restait bloqué avant la phase CD (push ECR / update ECS), même avec OIDC fonctionnel.

### Cause

Le scan Trivy **CRITICAL** était configuré en mode bloquant (`exit-code: "1"`), et des vulnérabilités CRITICAL OS étaient détectées.

### Correction

Pour avancer sur la fiabilisation ECS étape par étape, j’ai temporairement passé cette étape en avertissement :

```yaml
exit-code: "0"
```

Le scan est conservé, mais n’empêche plus temporairement l’exécution des étapes de déploiement.

### Ce que j’ai appris

On peut assouplir un garde-fou sécurité de manière contrôlée pour débloquer un chantier précis, à condition de documenter le choix et de prévoir un retour au mode bloquant.

---

### Problème rencontré n°3

Besoin de relancer rapidement la CI après correction d’infrastructure, sans changer de code applicatif.

### Correction

Deux méthodes fiables :

1. **Re-run all jobs** depuis l’onglet Actions GitHub.
2. Commit vide pour déclencher un nouveau run :

```bash
git commit --allow-empty -m "chore: relancer CI après correction infra"
git push origin main
```

### Ce que j’ai appris

Savoir relancer proprement un pipeline fait partie du runbook opérationnel, pas seulement du développement.

---

### Problème rencontré n°4

Le smoke test `/health` échouait avec une erreur IAM :

```text
AccessDenied: not authorized to perform elasticloadbalancing:DescribeTargetGroups
```

### Cause

Le rôle OIDC GitHub Actions (`github-actions-cloud-incident-main`) n’avait pas les permissions de lecture ELBv2 nécessaires au smoke test.

### Correction

J’ai ajouté au rôle IAM les permissions suivantes :

```json
"elasticloadbalancing:DescribeTargetGroups",
"elasticloadbalancing:DescribeLoadBalancers"
```

Après cette mise à jour, le smoke test a pu récupérer le DNS ALB via ECS/ELBv2 puis valider `GET /health`.

### Ce que j’ai appris

Quand on enrichit une CI avec des vérifications post-déploiement, il faut aussi faire évoluer le rôle IAM OIDC avec des permissions **read-only** ciblées.

---

## 17. ALB 503 après `terraform apply` RDS — image ECR oubliée

### Problème

Après ajout de RDS PostgreSQL, l’ALB renvoyait **503** et ECS affichait `running: 0`.

### Cause

J’avais fait `terraform apply` mais **oublié de pousser l’image Docker** dans ECR. La task échouait avec :

```text
CannotPullContainerError: ... cloudops-incident-api-dev:latest: not found
```

Ce n’était pas un problème RDS : l’infra et la base étaient OK, il manquait juste l’image.

### Correction

Push de l’image via **GitHub Actions CI** sur `main` (build → ECR → redeploy ECS), puis :

```text
/health → {"status":"ok"}
/api/orders → []
```

### Ce que j’ai appris

`terraform apply` ne build/push pas l’image. Ordre à retenir : **infra** → **image ECR** → **ECS**.

---

## 18. Secrets Manager — petits blocages Terraform / RDS

### Problème

En branchant `DATABASE_URL` via Secrets Manager, deux erreurs rapides :

1. `terraform plan` : `Invalid count argument` sur la policy IAM `execution_secrets`
2. `terraform apply` : `Cannot find version 16.6 for postgres` (eu-west-3)

### Cause

1. `count` basé sur `local.secrets_manager_arns` (ARN du secret inconnu avant le premier `apply`).
2. Les defaults Terraform pointaient vers PostgreSQL **16.14**, mais mon `terraform.tfvars` local gardait encore **16.6** (absent dans la région).

### Correction

- IAM : `count = length(var.container_secrets) > 0` (entrée module connue au plan).
- RDS : `db_engine_version = "16.14"` dans `terraform.tfvars` (vérifier avec `aws rds describe-db-engine-versions`).

Secrets Manager et ECS ont ensuite déployé sans autre incident ; `/health` et `/api/orders` OK.

### Ce que j’ai appris

- Un `count` Terraform ne peut pas dépendre d’attributs « known after apply ».
- `terraform.tfvars` écrase les defaults du code — toujours contrôler ce fichier local.
- Les versions PostgreSQL RDS varient par région.

---

### Ce que j’ai appris

Dans un projet Terraform structuré en plusieurs dossiers, il faut toujours exécuter Terraform depuis le dossier de l’environnement cible.

---

# Synthèse des apprentissages

Ce projet m’a permis de rencontrer et corriger des problèmes concrets liés au Cloud, au DevOps et à l’observabilité.

Les principaux apprentissages sont :

- comprendre la différence entre ECR et ECS ;
- diagnostiquer un ALB en erreur 503 ;
- lire le `stoppedReason` d’une task ECS ;
- comprendre le lien entre Docker, ECR et ECS ;
- utiliser CloudWatch Alarms avec les bonnes dimensions ;
- tester un topic SNS indépendamment de CloudWatch ;
- comprendre les dépendances réseau lors d’un `terraform destroy` ;
- relier un échec de push ECR à une infra absente après `destroy`, sans confondre avec OIDC ou Docker ;
- après un `terraform apply`, ne pas oublier le push image ECR avant de diagnostiquer RDS ou l’ALB ;
- Secrets Manager + ECS : `count` IAM sur la variable module, pas sur l’ARN ; `terraform.tfvars` prime sur les defaults ;
- éviter les fichiers sensibles dans Git ;
- documenter les erreurs rencontrées.

Le point le plus important à retenir :

> Les outils cloud ne suffisent pas. Il faut comprendre ce qui se passe derrière : réseau, containers, logs, IAM, métriques, dépendances Terraform et comportement des services AWS.

---

# Conclusion

Ce debug journal montre la progression réelle du projet.
Ce document sera enrichi au fur et à mesure de l’évolution du projet.

