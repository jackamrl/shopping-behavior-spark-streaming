# Script PowerShell pour détecter automatiquement les ressources existantes
# et mettre à jour les variables use_existing_* dans terraform.tfvars

param(
    [string]$ProjectId = "spark-streaming-483317",
    [string]$Environment = "dev",
    [string]$TfVarsFile = "environments/dev/terraform.tfvars"
)

Write-Host "🔍 Détection automatique des ressources existantes..." -ForegroundColor Cyan
Write-Host "Projet: $ProjectId" -ForegroundColor Yellow
Write-Host "Environnement: $Environment" -ForegroundColor Yellow
Write-Host ""

# Fonction pour vérifier si un Service Account existe
function Test-ServiceAccountExists {
    param([string]$AccountId, [string]$Project)
    
    $result = gcloud iam service-accounts describe "$AccountId@$Project.iam.gserviceaccount.com" `
        --project=$Project 2>&1
    return $LASTEXITCODE -eq 0
}

# Fonction pour vérifier si un bucket existe
function Test-BucketExists {
    param([string]$BucketName, [string]$Project)
    
    # Essayer plusieurs méthodes pour être plus robuste
    # Méthode 1: gsutil stat (plus fiable)
    $result1 = gsutil stat -p $Project "gs://$BucketName" 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    }
    
    # Méthode 2: gsutil ls -b (lister le bucket)
    $result2 = gsutil ls -b -p $Project "gs://$BucketName" 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    }
    
    # Méthode 3: gcloud storage buckets describe
    $result3 = gcloud storage buckets describe "gs://$BucketName" --project=$Project 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    }
    
    return $false
}

# Fonction pour vérifier si un dataset BigQuery existe
function Test-DatasetExists {
    param([string]$DatasetId, [string]$Project)
    
    $result = bq show --project_id=$Project "$Project:$DatasetId" 2>&1
    return $LASTEXITCODE -eq 0
}

# Détection des Service Accounts
Write-Host "📋 Vérification des Service Accounts..." -ForegroundColor Cyan
$dataprocExists = Test-ServiceAccountExists "spark-dataproc-$Environment" $ProjectId
$consumerExists = Test-ServiceAccountExists "spark-consumer-$Environment" $ProjectId

if ($dataprocExists -and $consumerExists) {
    Write-Host "  ✅ Service Accounts existent" -ForegroundColor Green
    $useExistingServiceAccounts = "true"
}
else {
    Write-Host "  ❌ Service Accounts n'existent pas" -ForegroundColor Yellow
    $useExistingServiceAccounts = "false"
}

# Détection des buckets
Write-Host "📦 Vérification des buckets GCS..." -ForegroundColor Cyan
$pipelineName = "spark-streaming-pipeline"
$bucketPrefix = "$pipelineName-$Environment-$($ProjectId.Replace('.', '-'))"

$dataBucket = "$bucketPrefix-data"
$checkpointBucket = "$bucketPrefix-checkpoints"
$artifactsBucket = "$bucketPrefix-artifacts"

Write-Host "  🔍 Vérification: gs://$dataBucket" -ForegroundColor Gray
$dataBucketExists = Test-BucketExists $dataBucket $ProjectId
Write-Host "  🔍 Vérification: gs://$checkpointBucket" -ForegroundColor Gray
$checkpointBucketExists = Test-BucketExists $checkpointBucket $ProjectId
Write-Host "  🔍 Vérification: gs://$artifactsBucket" -ForegroundColor Gray
$artifactsBucketExists = Test-BucketExists $artifactsBucket $ProjectId

if ($dataBucketExists -and $checkpointBucketExists -and $artifactsBucketExists) {
    Write-Host "  ✅ Tous les buckets existent" -ForegroundColor Green
    $useExistingBuckets = "true"
}
else {
    Write-Host "  ⚠️  Certains buckets n'existent pas ou ne sont pas accessibles:" -ForegroundColor Yellow
    if ($dataBucketExists) {
        Write-Host "    ✅ gs://$dataBucket" -ForegroundColor Green
    } else {
        Write-Host "    ❌ gs://$dataBucket" -ForegroundColor Red
    }
    if ($checkpointBucketExists) {
        Write-Host "    ✅ gs://$checkpointBucket" -ForegroundColor Green
    } else {
        Write-Host "    ❌ gs://$checkpointBucket" -ForegroundColor Red
    }
    if ($artifactsBucketExists) {
        Write-Host "    ✅ gs://$artifactsBucket" -ForegroundColor Green
    } else {
        Write-Host "    ❌ gs://$artifactsBucket" -ForegroundColor Red
    }
    Write-Host "  💡 Astuce: Si les buckets existent mais ne sont pas détectés, vérifiez les permissions IAM" -ForegroundColor Yellow
    $useExistingBuckets = "false"
}

# Détection du dataset BigQuery
Write-Host "🗄️  Vérification du dataset BigQuery..." -ForegroundColor Cyan
$datasetExists = Test-DatasetExists "shopping_$Environment" $ProjectId

if ($datasetExists) {
    Write-Host "  ✅ Dataset existe" -ForegroundColor Green
    $useExistingDataset = "true"
}
else {
    Write-Host "  ❌ Dataset n'existe pas" -ForegroundColor Yellow
    $useExistingDataset = "false"
}

Write-Host ""
Write-Host "📝 Mise à jour de $TfVarsFile..." -ForegroundColor Cyan

# Lire le fichier terraform.tfvars
$content = Get-Content $TfVarsFile -Raw

# Remplacer les valeurs use_existing_*
$content = $content -replace 'use_existing_dataset\s*=\s*(true|false)', "use_existing_dataset = $useExistingDataset"
$content = $content -replace 'use_existing_buckets\s*=\s*(true|false)', "use_existing_buckets = $useExistingBuckets"
$content = $content -replace 'use_existing_service_accounts\s*=\s*(true|false)', "use_existing_service_accounts = $useExistingServiceAccounts"

# Écrire le fichier mis à jour
Set-Content -Path $TfVarsFile -Value $content -NoNewline

Write-Host ""
Write-Host "✅ Configuration mise à jour automatiquement :" -ForegroundColor Green
Write-Host "  use_existing_dataset = $useExistingDataset" -ForegroundColor Yellow
Write-Host "  use_existing_buckets = $useExistingBuckets" -ForegroundColor Yellow
Write-Host "  use_existing_service_accounts = $useExistingServiceAccounts" -ForegroundColor Yellow
Write-Host ""
Write-Host "🚀 Vous pouvez maintenant exécuter terraform plan/apply" -ForegroundColor Cyan

