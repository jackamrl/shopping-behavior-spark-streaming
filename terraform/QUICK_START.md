# Guide Rapide - Premier Test Terraform

## Étape 1 : Installer Terraform

### Option A : Via winget (Windows 10/11)
```powershell
winget install HashiCorp.Terraform
```

### Option B : Téléchargement manuel
1. Aller sur https://www.terraform.io/downloads
2. Télécharger `terraform_<version>_windows_amd64.zip`
3. Extraire `terraform.exe` dans un dossier (ex: `C:\terraform`)
4. Ajouter au PATH :
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\terraform", "User")
   ```
5. Redémarrer PowerShell

### Vérifier l'installation
```powershell
terraform --version
```

## Étape 2 : Vérifier GCP

```powershell
# Vérifier le projet
gcloud config get-value project

# Si différent, configurer :
gcloud config set project neural-cortex-480815-i3

# Vérifier l'authentification
gcloud auth list
```

## Étape 3 : Utiliser le script automatique

```powershell
cd terraform
.\install-and-test.ps1
```

Le script va :
- ✅ Vérifier Terraform
- ✅ Vérifier GCP
- ✅ Initialiser Terraform
- ✅ Valider la configuration
- ✅ Afficher le plan

## Étape 4 : Ou faire manuellement

```powershell
cd terraform

# 1. Initialiser
terraform init

# 2. Valider
terraform validate

# 3. Voir le plan (sans créer)
terraform plan -var-file=environments/dev/terraform.tfvars

# 4. Déployer (quand prêt)
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Ce qui sera créé

- ✅ 3 buckets GCS (data, checkpoints, artifacts)
- ✅ 3 Service Accounts (dataproc, consumer, github-actions)
- ✅ 1 dataset BigQuery (shopping_dev)
- ✅ 1 table BigQuery (orders)
- ✅ Alertes de monitoring

## Après le déploiement

```powershell
# Voir les outputs
terraform output

# Récupérer la clé GitHub Actions
terraform output -raw github_actions_key > github-actions-key.json
```

## Dépannage

### Erreur : "API not enabled"
```powershell
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable dataproc.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable iam.googleapis.com
```

### Erreur : "Permission denied"
Vérifiez que vous avez les permissions `Owner` ou `Editor` sur le projet.

### Erreur : "Bucket name already exists"
Les noms de buckets doivent être uniques globalement. Modifiez `pipeline_name` dans `terraform.tfvars`.



