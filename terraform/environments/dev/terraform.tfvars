# Configuration pour l'environnement DEV
project_id   = "spark-streaming-483317"
region       = "europe-west1"
zone         = "europe-west1-b"
environment  = "dev"
pipeline_name = "spark-streaming-pipeline"

# Configuration des buckets GCS
gcs_buckets = {
  data = {
    location      = "EU"
    storage_class = "STANDARD"
    versioning    = false
    lifecycle_rules = [
      {
        action = {
          type = "Delete"
        }
        condition = {
          age = 90  # Supprimer les fichiers après 90 jours
        }
      }
    ]
  }
  checkpoint = {
    location      = "EU"
    storage_class = "STANDARD"
    versioning    = true
    lifecycle_rules = []
  }
  artifacts = {
    location      = "EU"
    storage_class = "STANDARD"
    versioning    = true
    lifecycle_rules = []
  }
}

# Configuration Dataproc
# Note: Si enable_cluster = false, utilisez Dataproc Serverless (recommandé)
# Si enable_cluster = true, un cluster permanent sera créé
dataproc_cluster_config = {
  enable_cluster = true   # true = créer un cluster permanent, false = utiliser serverless
  machine_type   = "n1-standard-2"
  num_instances  = 2
  image_version  = "2.1-debian11"
}

# Configuration pour utiliser les ressources existantes ou les créer
# 
# RÈGLE : Si la ressource EXISTE DÉJÀ → true, sinon → false
#
# Pour vérifier si une ressource existe :
# - Service Accounts: gcloud iam service-accounts list --project=spark-streaming-483317
# - Buckets: gsutil ls -p spark-streaming-483317
# - Dataset: bq ls --project_id=spark-streaming-483317
#
# Voir TERRAFORM_USE_EXISTING_GUIDE.md pour plus de détails
use_existing_dataset = false              # false = créer, true = utiliser l'existant
use_existing_buckets = true               # false = créer, true = utiliser l'existant (buckets existent déjà)
use_existing_service_accounts = true      # false = créer, true = utiliser l'existant (existent déjà)

# Configuration BigQuery
bigquery_dataset = {
  dataset_id    = "shopping_dev"
  location      = "EU"
  description   = "Dataset de développement pour la pipeline Spark Streaming"
  friendly_name = "Shopping Dev"
}

# Configuration des tables BigQuery
bigquery_tables = {
  orders = {
    description = "Table des commandes clients (dev)"
    schema = [
      { name = "customer_id", type = "INTEGER", mode = "NULLABLE" },
      { name = "age", type = "INTEGER", mode = "NULLABLE" },
      { name = "gender", type = "STRING", mode = "NULLABLE" },
      { name = "item_purchased", type = "STRING", mode = "NULLABLE" },
      { name = "category", type = "STRING", mode = "NULLABLE" },
      { name = "purchase_amount_usd", type = "FLOAT", mode = "NULLABLE" },
      { name = "location", type = "STRING", mode = "NULLABLE" },
      { name = "size", type = "STRING", mode = "NULLABLE" },
      { name = "color", type = "STRING", mode = "NULLABLE" },
      { name = "season", type = "STRING", mode = "NULLABLE" },
      { name = "review_rating", type = "FLOAT", mode = "NULLABLE" },
      { name = "subscription_status", type = "STRING", mode = "NULLABLE" },
      { name = "shipping_type", type = "STRING", mode = "NULLABLE" },
      { name = "discount_applied", type = "STRING", mode = "NULLABLE" },
      { name = "promo_code_used", type = "STRING", mode = "NULLABLE" },
      { name = "previous_purchases", type = "INTEGER", mode = "NULLABLE" },
      { name = "payment_method", type = "STRING", mode = "NULLABLE" },
      { name = "frequency_of_purchases", type = "STRING", mode = "NULLABLE" },
      { name = "processed_time", type = "TIMESTAMP", mode = "NULLABLE" }
    ]
    partition_field    = "processed_time"
    clustering_fields  = ["category", "location"]
  }
}

