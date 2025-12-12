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

# Service Account pour Dataproc
resource "google_service_account" "dataproc" {
  account_id   = "spark-dataproc-${var.environment}"
  display_name = "Service Account pour Dataproc - ${var.environment}"
  project      = var.project_id
}

# Service Account pour le Consumer Spark
resource "google_service_account" "consumer" {
  account_id   = "spark-consumer-${var.environment}"
  display_name = "Service Account pour Consumer Spark - ${var.environment}"
  project      = var.project_id
}

# Service Account pour GitHub Actions
resource "google_service_account" "github_actions" {
  account_id   = "spark-github-${var.environment}"
  display_name = "Service Account pour GitHub Actions - ${var.environment}"
  project      = var.project_id
}

# Clé JSON pour GitHub Actions (à ajouter dans GitHub Secrets)
resource "google_service_account_key" "github_actions_key" {
  service_account_id = google_service_account.github_actions.name
}

# Permissions Dataproc
resource "google_project_iam_member" "dataproc_worker" {
  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${google_service_account.dataproc.email}"
}

resource "google_project_iam_member" "dataproc_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.dataproc.email}"
}

resource "google_project_iam_member" "dataproc_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dataproc.email}"
}

# Permissions Consumer
resource "google_project_iam_member" "consumer_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.consumer.email}"
}

resource "google_project_iam_member" "consumer_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.consumer.email}"
}

# Permissions GitHub Actions
resource "google_project_iam_member" "github_actions_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_dataproc" {
  project = var.project_id
  role    = "roles/dataproc.editor"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Outputs
output "dataproc_service_account_email" {
  description = "Email du Service Account Dataproc"
  value       = google_service_account.dataproc.email
}

output "consumer_service_account_email" {
  description = "Email du Service Account Consumer"
  value       = google_service_account.consumer.email
}

output "github_actions_service_account_email" {
  description = "Email du Service Account GitHub Actions"
  value       = google_service_account.github_actions.email
}

output "github_actions_key" {
  description = "Clé JSON du Service Account GitHub Actions (base64)"
  value       = google_service_account_key.github_actions_key.private_key
  sensitive   = true
}

