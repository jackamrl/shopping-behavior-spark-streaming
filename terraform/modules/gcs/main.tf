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

variable "use_existing_buckets" {
  description = "Si true, utilise les buckets existants au lieu d'en créer de nouveaux"
  type        = bool
  default     = true
}

locals {
  # Les noms de buckets GCS doivent être globalement uniques dans tout GCP
  # On ajoute le project_id pour garantir l'unicité
  bucket_prefix = "${var.pipeline_name}-${var.environment}-${replace(var.project_id, ".", "-")}"
}

# Bucket pour les données d'entrée - Data source pour vérifier si existe
data "google_storage_bucket" "existing_data" {
  count = var.use_existing_buckets ? 1 : 0
  name  = "${local.bucket_prefix}-data"
}

# Bucket pour les données d'entrée - Création conditionnelle
resource "google_storage_bucket" "data" {
  count         = var.use_existing_buckets ? 0 : 1
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

# Local pour utiliser le bucket existant ou créé
locals {
  data_bucket_name = var.use_existing_buckets ? data.google_storage_bucket.existing_data[0].name : google_storage_bucket.data[0].name
}

# Note: Si le bucket n'existe pas, décommentez le resource ci-dessous et commentez le data source
# resource "google_storage_bucket" "data" {
#   name          = "${local.bucket_prefix}-data"
#   location      = var.buckets.data.location
#   storage_class = var.buckets.data.storage_class
#   project       = var.project_id
#   
#   versioning {
#     enabled = var.buckets.data.versioning
#   }
#   
#   uniform_bucket_level_access = true
#   
#   # Lifecycle rules
#   dynamic "lifecycle_rule" {
#     for_each = var.buckets.data.lifecycle_rules
#     content {
#       action {
#         type          = lifecycle_rule.value.action.type
#         storage_class = lifecycle_rule.value.action.storage_class
#       }
#       condition {
#         age                  = lifecycle_rule.value.condition.age
#         matches_storage_class = lifecycle_rule.value.condition.matches_storage_class
#       }
#     }
#   }
#   
#   labels = {
#     environment = var.environment
#     pipeline    = var.pipeline_name
#     component   = "data"
#   }
# }

# Bucket pour les checkpoints - Data source pour vérifier si existe
data "google_storage_bucket" "existing_checkpoint" {
  count = var.use_existing_buckets ? 1 : 0
  name  = "${local.bucket_prefix}-checkpoints"
}

# Bucket pour les checkpoints - Création conditionnelle
resource "google_storage_bucket" "checkpoint" {
  count         = var.use_existing_buckets ? 0 : 1
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

# Local pour utiliser le bucket existant ou créé
locals {
  checkpoint_bucket_name = var.use_existing_buckets ? data.google_storage_bucket.existing_checkpoint[0].name : google_storage_bucket.checkpoint[0].name
}

# Note: Si le bucket n'existe pas, décommentez le resource ci-dessous et commentez le data source
# resource "google_storage_bucket" "checkpoint" {
#   name          = "${local.bucket_prefix}-checkpoints"
#   location      = var.buckets.checkpoint.location
#   storage_class = var.buckets.checkpoint.storage_class
#   project       = var.project_id
#   
#   versioning {
#     enabled = true  # Toujours activer pour les checkpoints
#   }
#   
#   uniform_bucket_level_access = true
#   
#   labels = {
#     environment = var.environment
#     pipeline    = var.pipeline_name
#     component   = "checkpoint"
#   }
# }

# Bucket pour les artefacts - Data source pour vérifier si existe
data "google_storage_bucket" "existing_artifacts" {
  count = var.use_existing_buckets ? 1 : 0
  name  = "${local.bucket_prefix}-artifacts"
}

# Bucket pour les artefacts - Création conditionnelle
resource "google_storage_bucket" "artifacts" {
  count         = var.use_existing_buckets ? 0 : 1
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

# Local pour utiliser le bucket existant ou créé
locals {
  artifacts_bucket_name = var.use_existing_buckets ? data.google_storage_bucket.existing_artifacts[0].name : google_storage_bucket.artifacts[0].name
}

# Note: Si le bucket n'existe pas, décommentez le resource ci-dessous et commentez le data source
# resource "google_storage_bucket" "artifacts" {
#   name          = "${local.bucket_prefix}-artifacts"
#   location      = var.buckets.artifacts.location
#   storage_class = var.buckets.artifacts.storage_class
#   project       = var.project_id
#   
#   versioning {
#     enabled = true
#   }
#   
#   uniform_bucket_level_access = true
#   
#   labels = {
#     environment = var.environment
#     pipeline    = var.pipeline_name
#     component   = "artifacts"
#   }
# }

# IAM pour le bucket de données
resource "google_storage_bucket_iam_member" "data_dataproc" {
  bucket = local.data_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.dataproc_service_account}"
}

resource "google_storage_bucket_iam_member" "data_consumer" {
  bucket = local.data_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.consumer_service_account}"
}

# IAM pour le bucket de checkpoints
resource "google_storage_bucket_iam_member" "checkpoint_consumer" {
  bucket = local.checkpoint_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.consumer_service_account}"
}

resource "google_storage_bucket_iam_member" "checkpoint_dataproc" {
  bucket = local.checkpoint_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.dataproc_service_account}"
}

# IAM pour le bucket d'artefacts
resource "google_storage_bucket_iam_member" "artifacts_github_actions" {
  bucket = local.artifacts_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.github_actions_service_account}"
}

resource "google_storage_bucket_iam_member" "artifacts_dataproc" {
  bucket = local.artifacts_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.dataproc_service_account}"
}

# Outputs
output "data_bucket_name" {
  description = "Nom du bucket de données"
  value       = local.data_bucket_name
}

output "checkpoint_bucket_name" {
  description = "Nom du bucket de checkpoints"
  value       = local.checkpoint_bucket_name
}

output "artifacts_bucket_name" {
  description = "Nom du bucket d'artefacts"
  value       = local.artifacts_bucket_name
}

