# Script d'installation et test Terraform pour Windows

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation et Test Terraform" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si Terraform est déjà installé
Write-Host "Vérification de Terraform..." -ForegroundColor Yellow
$terraformInstalled = Get-Command terraform -ErrorAction SilentlyContinue

if ($terraformInstalled) {
    Write-Host "✓ Terraform est déjà installé !" -ForegroundColor Green
    terraform --version
    Write-Host ""
} else {
    Write-Host "✗ Terraform n'est pas installé." -ForegroundColor Red
    Write-Host ""
    Write-Host "Options d'installation :" -ForegroundColor Yellow
    Write-Host "1. Via winget (Windows 10/11) : winget install HashiCorp.Terraform" -ForegroundColor White
    Write-Host "2. Téléchargement manuel : https://www.terraform.io/downloads" -ForegroundColor White
    Write-Host ""
    
    $install = Read-Host "Voulez-vous installer via winget maintenant ? (O/N)"
    if ($install -eq "O" -or $install -eq "o") {
        Write-Host "Installation via winget..." -ForegroundColor Yellow
        winget install HashiCorp.Terraform
        Write-Host ""
        Write-Host "Redémarrez PowerShell et relancez ce script." -ForegroundColor Yellow
        exit
    } else {
        Write-Host "Veuillez installer Terraform manuellement, puis relancez ce script." -ForegroundColor Yellow
        exit
    }
}

# Vérifier l'authentification GCP
Write-Host "Vérification de l'authentification GCP..." -ForegroundColor Yellow
$gcloudInstalled = Get-Command gcloud -ErrorAction SilentlyContinue

if (-not $gcloudInstalled) {
    Write-Host "✗ gcloud CLI n'est pas installé." -ForegroundColor Red
    Write-Host "Installez Google Cloud SDK : https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit
}

$currentProject = gcloud config get-value project 2>$null
if ($currentProject) {
    Write-Host "✓ Projet GCP configuré : $currentProject" -ForegroundColor Green
} else {
    Write-Host "✗ Aucun projet GCP configuré." -ForegroundColor Red
    Write-Host "Configurez avec : gcloud config set project YOUR_PROJECT_ID" -ForegroundColor Yellow
    exit
}

Write-Host ""

# Initialiser Terraform
Write-Host "Initialisation de Terraform..." -ForegroundColor Yellow
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Erreur lors de l'initialisation." -ForegroundColor Red
    exit
}

Write-Host "✓ Terraform initialisé avec succès !" -ForegroundColor Green
Write-Host ""

# Valider la configuration
Write-Host "Validation de la configuration..." -ForegroundColor Yellow
terraform validate

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Erreurs dans la configuration." -ForegroundColor Red
    exit
}

Write-Host "✓ Configuration valide !" -ForegroundColor Green
Write-Host ""

# Afficher le plan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Affichage du plan Terraform" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cette commande va afficher ce qui sera créé (sans créer réellement)..." -ForegroundColor Yellow
Write-Host ""

$showPlan = Read-Host "Voulez-vous voir le plan maintenant ? (O/N)"
if ($showPlan -eq "O" -or $showPlan -eq "o") {
    terraform plan -var-file=environments/dev/terraform.tfvars
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Prochaines étapes" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pour déployer l'infrastructure :" -ForegroundColor Yellow
    Write-Host "  terraform apply -var-file=environments/dev/terraform.tfvars" -ForegroundColor White
    Write-Host ""
    Write-Host "Pour voir les outputs après déploiement :" -ForegroundColor Yellow
    Write-Host "  terraform output" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Plan ignoré. Vous pouvez le lancer manuellement avec :" -ForegroundColor Yellow
    Write-Host "  terraform plan -var-file=environments/dev/terraform.tfvars" -ForegroundColor White
}

Write-Host ""
Write-Host "✓ Script terminé !" -ForegroundColor Green



