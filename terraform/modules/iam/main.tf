variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "pipeline_name" {
  description = "Nom de la pipeline"
  type        = string
}

variable "environment" {
  description = "Environnement"
  type        = string
}

# Service Account pour GitHub Actions (existant, créé manuellement)
# On utilise un data source car ce Service Account existe déjà et est utilisé pour authentifier Terraform
data "google_service_account" "github_actions" {
  account_id = "spark-github-${var.environment}"
  project    = var.project_id
}

# Permissions pour GitHub Actions : créer et gérer les Service Accounts
# Ces permissions permettent au Service Account GitHub Actions de :
# - Lire les Service Accounts (nécessaire pour le data source)
# - Créer et gérer les Service Accounts (nécessaire pour créer dataproc, consumer)

# Permission pour lire les Service Accounts (nécessaire pour le data source)
resource "google_project_iam_member" "github_actions_iam_viewer" {
  project = var.project_id
  role    = "roles/iam.serviceAccountViewer"
  member  = "serviceAccount:${data.google_service_account.github_actions.email}"
}

# Permission pour créer et gérer les Service Accounts
resource "google_project_iam_member" "github_actions_iam_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${data.google_service_account.github_actions.email}"
  
  depends_on = [google_project_iam_member.github_actions_iam_viewer]
}

# Service Account pour Dataproc (existant, créé manuellement)
# On utilise un data source car ce Service Account existe déjà
data "google_service_account" "dataproc" {
  account_id = "spark-dataproc-${var.environment}"
  project    = var.project_id
}

# Service Account pour le Consumer Spark (existant, créé manuellement)
# On utilise un data source car ce Service Account existe déjà
data "google_service_account" "consumer" {
  account_id = "spark-consumer-${var.environment}"
  project    = var.project_id
}

# Clé JSON pour GitHub Actions (à ajouter dans GitHub Secrets)
# Note: La clé doit être créée manuellement et ajoutée dans GitHub Secrets
# gcloud iam service-accounts keys create KEY_FILE \
#   --iam-account=spark-github-dev@PROJECT_ID.iam.gserviceaccount.com
# 
# Cette ressource est commentée car la clé existe déjà
# resource "google_service_account_key" "github_actions_key" {
#   service_account_id = data.google_service_account.github_actions.name
# }

# Permissions Dataproc
resource "google_project_iam_member" "dataproc_worker" {
  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${data.google_service_account.dataproc.email}"
}

resource "google_project_iam_member" "dataproc_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${data.google_service_account.dataproc.email}"
}

resource "google_project_iam_member" "dataproc_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${data.google_service_account.dataproc.email}"
}

# Permissions Consumer
resource "google_project_iam_member" "consumer_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${data.google_service_account.consumer.email}"
}

resource "google_project_iam_member" "consumer_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_service_account.consumer.email}"
}

# Permissions GitHub Actions
resource "google_project_iam_member" "github_actions_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${data.google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_dataproc" {
  project = var.project_id
  role    = "roles/dataproc.editor"
  member  = "serviceAccount:${data.google_service_account.github_actions.email}"
}

# Outputs
output "dataproc_service_account_email" {
  description = "Email du Service Account Dataproc"
  value       = data.google_service_account.dataproc.email
}

output "consumer_service_account_email" {
  description = "Email du Service Account Consumer"
  value       = data.google_service_account.consumer.email
}

output "github_actions_service_account_email" {
  description = "Email du Service Account GitHub Actions"
  value       = data.google_service_account.github_actions.email
}

# Note: La clé JSON doit être créée manuellement
# output "github_actions_key" {
#   description = "Clé JSON du Service Account GitHub Actions (base64)"
#   value       = google_service_account_key.github_actions_key.private_key
#   sensitive   = true
# }

#yo

