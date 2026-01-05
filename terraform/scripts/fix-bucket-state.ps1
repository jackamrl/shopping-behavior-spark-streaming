# Script PowerShell pour supprimer les buckets du state Terraform quand use_existing_buckets = true
# Ce script nettoie le state pour éviter les erreurs 409

Write-Host "🔧 Nettoyage du state Terraform pour les buckets..." -ForegroundColor Cyan
Write-Host ""

# Vérifier si on est dans le bon répertoire
if (-not (Test-Path "main.tf")) {
    Write-Host "❌ Erreur: Ce script doit être exécuté depuis le répertoire terraform/" -ForegroundColor Red
    exit 1
}

# Initialiser Terraform si nécessaire
if (-not (Test-Path ".terraform")) {
    Write-Host "📦 Initialisation de Terraform..." -ForegroundColor Yellow
    terraform init
}

Write-Host "🗑️  Suppression des buckets du state Terraform..." -ForegroundColor Cyan
Write-Host ""

# Supprimer les buckets du state (s'ils existent dans le state)
$resources = @(
    "module.gcs.google_storage_bucket.data[0]",
    "module.gcs.google_storage_bucket.checkpoint[0]",
    "module.gcs.google_storage_bucket.artifacts[0]"
)

foreach ($resource in $resources) {
    Write-Host "  Suppression de $resource..." -ForegroundColor Gray
    $result = terraform state rm $resource 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ Supprimé du state" -ForegroundColor Green
    } else {
        Write-Host "    ℹ️  Ressource non trouvée dans le state (déjà supprimée ou n'existe pas)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Nettoyage terminé !" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Prochaines étapes :" -ForegroundColor Cyan
Write-Host "  1. Vérifiez que use_existing_buckets = true dans terraform.tfvars" -ForegroundColor Yellow
Write-Host "  2. Exécutez: terraform plan" -ForegroundColor Yellow
Write-Host "  3. Si le plan est correct, exécutez: terraform apply" -ForegroundColor Yellow
Write-Host ""

