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

variable "use_existing_service_accounts" {
  description = "Si true, utilise les Service Accounts existants au lieu d'en créer de nouveaux"
  type        = bool
  default     = true
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

# Service Account pour Dataproc - Data source pour vérifier si existe
data "google_service_account" "existing_dataproc" {
  count      = var.use_existing_service_accounts ? 1 : 0
  account_id = "spark-dataproc-${var.environment}"
  project    = var.project_id
}

# Service Account pour Dataproc - Création conditionnelle
resource "google_service_account" "dataproc" {
  count        = var.use_existing_service_accounts ? 0 : 1
  account_id   = "spark-dataproc-${var.environment}"
  display_name = "Service Account pour Dataproc - ${var.environment}"
  project      = var.project_id
  
  depends_on = [google_project_iam_member.github_actions_iam_admin]
}

# Service Account pour le Consumer Spark - Data source pour vérifier si existe
data "google_service_account" "existing_consumer" {
  count      = var.use_existing_service_accounts ? 1 : 0
  account_id = "spark-consumer-${var.environment}"
  project    = var.project_id
}

# Service Account pour le Consumer Spark - Création conditionnelle
resource "google_service_account" "consumer" {
  count        = var.use_existing_service_accounts ? 0 : 1
  account_id   = "spark-consumer-${var.environment}"
  display_name = "Service Account pour Consumer Spark - ${var.environment}"
  project      = var.project_id
  
  depends_on = [google_project_iam_member.github_actions_iam_admin]
}

# Local pour utiliser le Service Account existant ou créé
locals {
  dataproc_service_account_email = var.use_existing_service_accounts ? data.google_service_account.existing_dataproc[0].email : google_service_account.dataproc[0].email
  consumer_service_account_email = var.use_existing_service_accounts ? data.google_service_account.existing_consumer[0].email : google_service_account.consumer[0].email
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

# Permissions Dataproc - Permissions complètes pour exécuter des jobs Spark
resource "google_project_iam_member" "dataproc_worker" {
  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${local.dataproc_service_account_email}"
}

# Permissions Storage - Lecture et écriture complètes
resource "google_project_iam_member" "dataproc_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${local.dataproc_service_account_email}"
}

resource "google_project_iam_member" "dataproc_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${local.dataproc_service_account_email}"
}

# Permissions BigQuery - Édition des données et exécution de jobs
resource "google_project_iam_member" "dataproc_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${local.dataproc_service_account_email}"
}

resource "google_project_iam_member" "dataproc_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${local.dataproc_service_account_email}"
}

resource "google_project_iam_member" "dataproc_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${local.dataproc_service_account_email}"
}

# Permissions pour lire les métadonnées des datasets
resource "google_project_iam_member" "dataproc_bigquery_metadata_viewer" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:${local.dataproc_service_account_email}"
}

# Permissions Consumer
resource "google_project_iam_member" "consumer_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${local.consumer_service_account_email}"
}

resource "google_project_iam_member" "consumer_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${local.consumer_service_account_email}"
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
  value       = local.dataproc_service_account_email
}

output "consumer_service_account_email" {
  description = "Email du Service Account Consumer"
  value       = local.consumer_service_account_email
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

