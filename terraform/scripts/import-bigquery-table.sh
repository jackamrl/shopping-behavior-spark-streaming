#!/bin/bash
# Script pour importer une table BigQuery existante dans le state Terraform

set -e

PROJECT_ID="${1:-spark-streaming-483317}"
TABLE_NAME="${2:-orders}"
DATASET_ID="${3:-shopping_dev}"

echo "📊 Import de la table BigQuery dans Terraform..."
echo "Projet: $PROJECT_ID"
echo "Dataset: $DATASET_ID"
echo "Table: $TABLE_NAME"
echo ""

# Vérifier si on est dans le bon répertoire
if [ ! -f "main.tf" ]; then
    echo "❌ Erreur: Ce script doit être exécuté depuis le répertoire terraform/"
    exit 1
fi

# Vérifier si la table existe dans BigQuery
echo "🔍 Vérification de l'existence de la table..."
if bq show --project_id="$PROJECT_ID" "$PROJECT_ID:$DATASET_ID.$TABLE_NAME" >/dev/null 2>&1; then
    echo "  ✅ Table existe dans BigQuery"
else
    echo "  ❌ Table n'existe pas dans BigQuery"
    exit 1
fi

# Vérifier si la table est déjà dans le state
echo "🔍 Vérification du state Terraform..."
if terraform state show "module.bigquery.google_bigquery_table.tables[\"$TABLE_NAME\"]" >/dev/null 2>&1; then
    echo "  ℹ️  Table est déjà dans le state Terraform"
    echo "  📋 Affichage de l'état actuel:"
    terraform state show "module.bigquery.google_bigquery_table.tables[\"$TABLE_NAME\"]"
    exit 0
fi

# Importer la table
echo "📥 Import de la table dans le state Terraform..."
terraform import \
  -var-file=environments/dev/terraform.tfvars \
  "module.bigquery.google_bigquery_table.tables[\"$TABLE_NAME\"]" \
  "projects/$PROJECT_ID/datasets/$DATASET_ID/tables/$TABLE_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Import réussi !"
    echo ""
    echo "📋 Vérification de l'état:"
    terraform state show "module.bigquery.google_bigquery_table.tables[\"$TABLE_NAME\"]"
else
    echo ""
    echo "❌ Import échoué"
    exit 1
fi

