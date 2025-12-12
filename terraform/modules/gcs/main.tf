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

variable "buckets" {
  description = "Configuration des buckets"
  type = map(object({
    location      = string
    storage_class = string
    versioning    = bool
    lifecycle_rules = optional(list(object({
      action = object({
        type          = string
        storage_class = optional(string)
      })
      condition = object({
        age                   = optional(number)
        days_since_noncurrent = optional(number)
        matches_storage_class  = optional(list(string))
      })
    })), [])
  }))
}

variable "dataproc_service_account" {
  description = "Email du Service Account Dataproc"
  type        = string
}

variable "consumer_service_account" {
  description = "Email du Service Account Consumer"
  type        = string
}

variable "github_actions_service_account" {
  description = "Email du Service Account GitHub Actions"
  type        = string
}

locals {
  bucket_prefix = "${var.pipeline_name}-${var.environment}"
}

# Bucket pour les données d'entrée (inbox)
resource "google_storage_bucket" "data" {
  name          = "${local.bucket_prefix}-data"
  location      = var.buckets.data.location
  storage_class = var.buckets.data.storage_class
  project       = var.project_id
  
  versioning {
    enabled = var.buckets.data.versioning
  }
  
  uniform_bucket_level_access = true
  
  # Lifecycle rules
  dynamic "lifecycle_rule" {
    for_each = var.buckets.data.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }
      condition {
        age                  = lifecycle_rule.value.condition.age
        matches_storage_class = lifecycle_rule.value.condition.matches_storage_class
      }
    }
  }
  
  labels = {
    environment = var.environment
    pipeline    = var.pipeline_name
    component   = "data"
  }
}

# Bucket pour les checkpoints
resource "google_storage_bucket" "checkpoint" {
  name          = "${local.bucket_prefix}-checkpoints"
  location      = var.buckets.checkpoint.location
  storage_class = var.buckets.checkpoint.storage_class
  project       = var.project_id
  
  versioning {
    enabled = true  # Toujours activer pour les checkpoints
  }
  
  uniform_bucket_level_access = true
  
  labels = {
    environment = var.environment
    pipeline    = var.pipeline_name
    component   = "checkpoint"
  }
}

# Bucket pour les artefacts (JARs, dépendances)
resource "google_storage_bucket" "artifacts" {
  name          = "${local.bucket_prefix}-artifacts"
  location      = var.buckets.artifacts.location
  storage_class = var.buckets.artifacts.storage_class
  project       = var.project_id
  
  versioning {
    enabled = true
  }
  
  uniform_bucket_level_access = true
  
  labels = {
    environment = var.environment
    pipeline    = var.pipeline_name
    component   = "artifacts"
  }
}

# IAM pour le bucket de données
resource "google_storage_bucket_iam_member" "data_dataproc" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.dataproc_service_account}"
}

resource "google_storage_bucket_iam_member" "data_consumer" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.consumer_service_account}"
}

# IAM pour le bucket de checkpoints
resource "google_storage_bucket_iam_member" "checkpoint_consumer" {
  bucket = google_storage_bucket.checkpoint.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.consumer_service_account}"
}

resource "google_storage_bucket_iam_member" "checkpoint_dataproc" {
  bucket = google_storage_bucket.checkpoint.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.dataproc_service_account}"
}

# IAM pour le bucket d'artefacts
resource "google_storage_bucket_iam_member" "artifacts_github_actions" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.github_actions_service_account}"
}

resource "google_storage_bucket_iam_member" "artifacts_dataproc" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.dataproc_service_account}"
}

# Outputs
output "data_bucket_name" {
  description = "Nom du bucket de données"
  value       = google_storage_bucket.data.name
}

output "checkpoint_bucket_name" {
  description = "Nom du bucket de checkpoints"
  value       = google_storage_bucket.checkpoint.name
}

output "artifacts_bucket_name" {
  description = "Nom du bucket d'artefacts"
  value       = google_storage_bucket.artifacts.name
}

