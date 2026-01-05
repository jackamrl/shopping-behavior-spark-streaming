#!/bin/bash
# Script pour supprimer les buckets du state Terraform quand use_existing_buckets = true
# Ce script nettoie le state pour éviter les erreurs 409

set -e

echo "🔧 Nettoyage du state Terraform pour les buckets..."
echo ""

# Vérifier si on est dans le bon répertoire
if [ ! -f "main.tf" ]; then
    echo "❌ Erreur: Ce script doit être exécuté depuis le répertoire terraform/"
    exit 1
fi

# Initialiser Terraform si nécessaire
if [ ! -d ".terraform" ]; then
    echo "📦 Initialisation de Terraform..."
    terraform init
fi

echo "🗑️  Suppression des buckets du state Terraform..."
echo ""

# Supprimer les buckets du state (s'ils existent dans le state)
# On utilise || true pour continuer même si la ressource n'existe pas dans le state

echo "  Suppression de module.gcs.google_storage_bucket.data[0]..."
terraform state rm 'module.gcs.google_storage_bucket.data[0]' 2>/dev/null || echo "    ℹ️  Ressource non trouvée dans le state (déjà supprimée ou n'existe pas)"

echo "  Suppression de module.gcs.google_storage_bucket.checkpoint[0]..."
terraform state rm 'module.gcs.google_storage_bucket.checkpoint[0]' 2>/dev/null || echo "    ℹ️  Ressource non trouvée dans le state (déjà supprimée ou n'existe pas)"

echo "  Suppression de module.gcs.google_storage_bucket.artifacts[0]..."
terraform state rm 'module.gcs.google_storage_bucket.artifacts[0]' 2>/dev/null || echo "    ℹ️  Ressource non trouvée dans le state (déjà supprimée ou n'existe pas)"

echo ""
echo "✅ Nettoyage terminé !"
echo ""
echo "📋 Prochaines étapes :"
echo "  1. Vérifiez que use_existing_buckets = true dans terraform.tfvars"
echo "  2. Exécutez: terraform plan"
echo "  3. Si le plan est correct, exécutez: terraform apply"
echo ""

