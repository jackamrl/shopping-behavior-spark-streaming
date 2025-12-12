# Guide de Test - Infrastructure Terraform

## Prérequis

### 1. Installer Terraform

**Sur Windows (PowerShell) :**

```powershell
# Option 1 : Via Chocolatey (si installé)
choco install terraform

# Option 2 : Téléchargement manuel
# 1. Télécharger depuis https://www.terraform.io/downloads
# 2. Extraire terraform.exe
# 3. Ajouter au PATH
```

**Vérifier l'installation :**
```powershell
terraform --version
```

### 2. Authentification GCP

```powershell
# Vérifier que vous êtes authentifié
gcloud auth list

# Si besoin, s'authentifier
gcloud auth login
gcloud auth application-default login

# Configurer le projet
gcloud config set project neural-cortex-480815-i3
```

### 3. Activer les APIs nécessaires (optionnel - Terraform le fera automatiquement)

```powershell
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable dataproc.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable iam.googleapis.com
```

## Étapes de Test

### Étape 1 : Initialiser Terraform

```powershell
cd terraform
terraform init
```

Cette commande va :
- Télécharger les providers Google nécessaires
- Initialiser le backend (local par défaut)

### Étape 2 : Valider la configuration

```powershell
terraform validate
```

### Étape 3 : Voir ce qui sera créé (PLAN)

```powershell
terraform plan -var-file=environments/dev/terraform.tfvars
```

Cette commande affichera :
- Les ressources qui seront créées
- Les Service Accounts
- Les buckets GCS
- Le dataset BigQuery
- Les tables BigQuery
- Les alertes de monitoring

**Résumé attendu :**
- ✅ 3 buckets GCS (data, checkpoints, artifacts)
- ✅ 3 Service Accounts (dataproc, consumer, github-actions)
- ✅ 1 dataset BigQuery (shopping_dev)
- ✅ 1 table BigQuery (orders)
- ✅ Alertes de monitoring

### Étape 4 : Déployer l'infrastructure (APPLY)

⚠️ **ATTENTION** : Cette commande va créer des ressources facturées sur GCP.

```powershell
terraform apply -var-file=environments/dev/terraform.tfvars
```

Terraform vous demandera confirmation. Tapez `yes` pour continuer.

**Durée estimée :** 2-5 minutes

### Étape 5 : Vérifier les outputs

```powershell
terraform output
```

Vous devriez voir :
- Les noms des buckets GCS
- L'ID du dataset BigQuery
- Les emails des Service Accounts
- La clé JSON pour GitHub Actions

### Étape 6 : Vérifier dans la console GCP

1. **Buckets GCS** : https://console.cloud.google.com/storage/browser
   - Chercher les buckets avec le préfixe `spark-streaming-pipeline-dev-`

2. **Service Accounts** : https://console.cloud.google.com/iam-admin/serviceaccounts
   - Chercher les comptes avec le préfixe `spark-streaming-pipeline-`

3. **BigQuery** : https://console.cloud.google.com/bigquery
   - Vérifier le dataset `shopping_dev` et la table `orders`

## Commandes Utiles

### Voir l'état actuel
```powershell
terraform show
```

### Lister les ressources
```powershell
terraform state list
```

### Détruire l'infrastructure (⚠️ ATTENTION)
```powershell
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Dépannage

### Erreur : "API not enabled"
```powershell
# Activer l'API manuellement
gcloud services enable <API_NAME>
```

### Erreur : "Permission denied"
Vérifiez que vous avez les permissions :
- `Owner` ou `Editor` sur le projet
- Ou les rôles IAM spécifiques nécessaires

### Erreur : "Bucket name already exists"
Les noms de buckets doivent être uniques globalement. Modifiez `pipeline_name` dans `terraform.tfvars`.

## Prochaines Étapes

Après le déploiement réussi :

1. **Récupérer la clé GitHub Actions** :
   ```powershell
   terraform output -raw github_actions_key > github-actions-key.json
   ```

2. **Ajouter les secrets dans GitHub** :
   - `GCP_PROJECT_ID` : `neural-cortex-480815-i3`
   - `GCS_ARTIFACTS_BUCKET` : (voir output `gcs_buckets.artifacts_bucket`)
   - `GCP_SA_KEY` : (contenu du fichier `github-actions-key.json`)

3. **Tester le workflow GitHub Actions** :
   - Push sur la branche `main` ou `develop`
   - Vérifier que le JAR est uploadé automatiquement



