# Script PowerShell pour importer une table BigQuery existante dans le state Terraform

param(
    [string]$ProjectId = "spark-streaming-483317",
    [string]$TableName = "orders",
    [string]$DatasetId = "shopping_dev"
)

Write-Host "📊 Import de la table BigQuery dans Terraform..." -ForegroundColor Cyan
Write-Host "Projet: $ProjectId" -ForegroundColor Yellow
Write-Host "Dataset: $DatasetId" -ForegroundColor Yellow
Write-Host "Table: $TableName" -ForegroundColor Yellow
Write-Host ""

# Vérifier si on est dans le bon répertoire
if (-not (Test-Path "main.tf")) {
    Write-Host "❌ Erreur: Ce script doit être exécuté depuis le répertoire terraform/" -ForegroundColor Red
    exit 1
}

# Vérifier si la table existe dans BigQuery
Write-Host "🔍 Vérification de l'existence de la table..." -ForegroundColor Cyan
$result = bq show --project_id=$ProjectId "$ProjectId:$DatasetId.$TableName" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Table existe dans BigQuery" -ForegroundColor Green
} else {
    Write-Host "  ❌ Table n'existe pas dans BigQuery" -ForegroundColor Red
    exit 1
}

# Vérifier si la table est déjà dans le state
Write-Host "🔍 Vérification du state Terraform..." -ForegroundColor Cyan
$stateResult = terraform state show "module.bigquery.google_bigquery_table.tables[`"$TableName`"]" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ℹ️  Table est déjà dans le state Terraform" -ForegroundColor Yellow
    Write-Host "  📋 Affichage de l'état actuel:" -ForegroundColor Cyan
    terraform state show "module.bigquery.google_bigquery_table.tables[`"$TableName`"]"
    exit 0
}

# Importer la table
Write-Host "📥 Import de la table dans le state Terraform..." -ForegroundColor Cyan
terraform import `
  -var-file=environments/dev/terraform.tfvars `
  "module.bigquery.google_bigquery_table.tables[`"$TableName`"]" `
  "projects/$ProjectId/datasets/$DatasetId/tables/$TableName"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Import réussi !" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Vérification de l'état:" -ForegroundColor Cyan
    terraform state show "module.bigquery.google_bigquery_table.tables[`"$TableName`"]"
} else {
    Write-Host ""
    Write-Host "❌ Import échoué" -ForegroundColor Red
    exit 1
}

