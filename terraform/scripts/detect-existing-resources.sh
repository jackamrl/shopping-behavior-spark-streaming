#!/bin/bash
# Script bash pour détecter automatiquement les ressources existantes
# et mettre à jour les variables use_existing_* dans terraform.tfvars

set -e

PROJECT_ID="${1:-spark-streaming-483317}"
ENVIRONMENT="${2:-dev}"
TF_VARS_FILE="${3:-environments/dev/terraform.tfvars}"

echo "🔍 Détection automatique des ressources existantes..."
echo "Projet: $PROJECT_ID"
echo "Environnement: $ENVIRONMENT"
echo ""

# Fonction pour vérifier si un Service Account existe
check_service_account() {
    local account_id=$1
    local project=$2
    gcloud iam service-accounts describe "${account_id}@${project}.iam.gserviceaccount.com" \
        --project="$project" >/dev/null 2>&1
    return $?
}

# Fonction pour vérifier si un bucket existe
check_bucket() {
    local bucket_name=$1
    local project=$2
    # Utiliser gsutil stat qui est plus fiable pour vérifier l'existence
    # Si le bucket existe mais qu'on n'a pas les permissions, on essaie aussi gsutil ls -b
    if gsutil stat -p "$project" "gs://$bucket_name" >/dev/null 2>&1; then
        return 0
    fi
    # Fallback: essayer de lister le bucket (peut échouer si pas de permissions mais bucket existe)
    if gsutil ls -b -p "$project" "gs://$bucket_name" >/dev/null 2>&1; then
        return 0
    fi
    # Dernier essai: vérifier via gcloud storage buckets describe
    if gcloud storage buckets describe "gs://$bucket_name" --project="$project" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Fonction pour vérifier si un dataset BigQuery existe
check_dataset() {
    local dataset_id=$1
    local project=$2
    bq show --project_id="$project" "${project}:${dataset_id}" >/dev/null 2>&1
    return $?
}

# Détection des Service Accounts
echo "📋 Vérification des Service Accounts..."
if check_service_account "spark-dataproc-$ENVIRONMENT" "$PROJECT_ID" && \
   check_service_account "spark-consumer-$ENVIRONMENT" "$PROJECT_ID"; then
    echo "  ✅ Service Accounts existent"
    USE_EXISTING_SERVICE_ACCOUNTS="true"
else
    echo "  ❌ Service Accounts n'existent pas"
    USE_EXISTING_SERVICE_ACCOUNTS="false"
fi

# Détection des buckets
echo "📦 Vérification des buckets GCS..."
PIPELINE_NAME="spark-streaming-pipeline"
BUCKET_PREFIX="${PIPELINE_NAME}-${ENVIRONMENT}-$(echo $PROJECT_ID | tr '.' '-')"

# Vérifier chaque bucket individuellement pour un meilleur debugging
DATA_BUCKET="${BUCKET_PREFIX}-data"
CHECKPOINT_BUCKET="${BUCKET_PREFIX}-checkpoints"
ARTIFACTS_BUCKET="${BUCKET_PREFIX}-artifacts"

echo "  🔍 Vérification: gs://${DATA_BUCKET}"
DATA_EXISTS=$(check_bucket "$DATA_BUCKET" "$PROJECT_ID" && echo "true" || echo "false")
echo "  🔍 Vérification: gs://${CHECKPOINT_BUCKET}"
CHECKPOINT_EXISTS=$(check_bucket "$CHECKPOINT_BUCKET" "$PROJECT_ID" && echo "true" || echo "false")
echo "  🔍 Vérification: gs://${ARTIFACTS_BUCKET}"
ARTIFACTS_EXISTS=$(check_bucket "$ARTIFACTS_BUCKET" "$PROJECT_ID" && echo "true" || echo "false")

if [ "$DATA_EXISTS" = "true" ] && [ "$CHECKPOINT_EXISTS" = "true" ] && [ "$ARTIFACTS_EXISTS" = "true" ]; then
    echo "  ✅ Tous les buckets existent"
    USE_EXISTING_BUCKETS="true"
else
    echo "  ⚠️  Certains buckets n'existent pas ou ne sont pas accessibles:"
    [ "$DATA_EXISTS" = "true" ] && echo "    ✅ gs://${DATA_BUCKET}" || echo "    ❌ gs://${DATA_BUCKET}"
    [ "$CHECKPOINT_EXISTS" = "true" ] && echo "    ✅ gs://${CHECKPOINT_BUCKET}" || echo "    ❌ gs://${CHECKPOINT_BUCKET}"
    [ "$ARTIFACTS_EXISTS" = "true" ] && echo "    ✅ gs://${ARTIFACTS_BUCKET}" || echo "    ❌ gs://${ARTIFACTS_BUCKET}"
    echo "  💡 Astuce: Si les buckets existent mais ne sont pas détectés, vérifiez les permissions IAM"
    USE_EXISTING_BUCKETS="false"
fi

# Détection du dataset BigQuery
echo "🗄️  Vérification du dataset BigQuery..."
if check_dataset "shopping_${ENVIRONMENT}" "$PROJECT_ID"; then
    echo "  ✅ Dataset existe"
    USE_EXISTING_DATASET="true"
    
    # Vérifier si la table orders existe
    echo "📊 Vérification de la table orders..."
    if bq show --project_id="$PROJECT_ID" "${PROJECT_ID}:shopping_${ENVIRONMENT}.orders" >/dev/null 2>&1; then
        echo "  ✅ Table orders existe - sera importée dans Terraform"
        TABLE_EXISTS="true"
    else
        echo "  ❌ Table orders n'existe pas"
        TABLE_EXISTS="false"
    fi
else
    echo "  ❌ Dataset n'existe pas"
    USE_EXISTING_DATASET="false"
    TABLE_EXISTS="false"
fi

echo ""
echo "📝 Mise à jour de $TF_VARS_FILE..."

# Mettre à jour le fichier terraform.tfvars
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/use_existing_dataset = .*/use_existing_dataset = $USE_EXISTING_DATASET/" "$TF_VARS_FILE"
    sed -i '' "s/use_existing_buckets = .*/use_existing_buckets = $USE_EXISTING_BUCKETS/" "$TF_VARS_FILE"
    sed -i '' "s/use_existing_service_accounts = .*/use_existing_service_accounts = $USE_EXISTING_SERVICE_ACCOUNTS/" "$TF_VARS_FILE"
else
    # Linux
    sed -i "s/use_existing_dataset = .*/use_existing_dataset = $USE_EXISTING_DATASET/" "$TF_VARS_FILE"
    sed -i "s/use_existing_buckets = .*/use_existing_buckets = $USE_EXISTING_BUCKETS/" "$TF_VARS_FILE"
    sed -i "s/use_existing_service_accounts = .*/use_existing_service_accounts = $USE_EXISTING_SERVICE_ACCOUNTS/" "$TF_VARS_FILE"
fi

echo ""
echo "✅ Configuration mise à jour automatiquement :"
echo "  use_existing_dataset = $USE_EXISTING_DATASET"
echo "  use_existing_buckets = $USE_EXISTING_BUCKETS"
echo "  use_existing_service_accounts = $USE_EXISTING_SERVICE_ACCOUNTS"
echo ""
echo "🚀 Vous pouvez maintenant exécuter terraform plan/apply"

