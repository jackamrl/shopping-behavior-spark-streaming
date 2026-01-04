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
    
    $result = gsutil ls -p $Project "gs://$BucketName" 2>&1
    return $LASTEXITCODE -eq 0
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

$dataBucketExists = Test-BucketExists "$bucketPrefix-data" $ProjectId
$checkpointBucketExists = Test-BucketExists "$bucketPrefix-checkpoints" $ProjectId
$artifactsBucketExists = Test-BucketExists "$bucketPrefix-artifacts" $ProjectId

if ($dataBucketExists -and $checkpointBucketExists -and $artifactsBucketExists) {
    Write-Host "  ✅ Buckets existent" -ForegroundColor Green
    $useExistingBuckets = "true"
}
else {
    Write-Host "  ❌ Buckets n'existent pas" -ForegroundColor Yellow
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

