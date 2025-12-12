variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "dataset_config" {
  description = "Configuration du dataset BigQuery"
  type = object({
    dataset_id    = string
    location      = string
    description   = string
    friendly_name = string
  })
}

variable "tables" {
  description = "Configuration des tables BigQuery"
  type = map(object({
    schema = list(object({
      name = string
      type = string
      mode = optional(string)
    }))
    description       = optional(string)
    partition_field    = optional(string)
    clustering_fields = optional(list(string))
  }))
  default = {}
}

variable "consumer_service_account" {
  description = "Email du Service Account Consumer"
  type        = string
}

# Dataset BigQuery
resource "google_bigquery_dataset" "dataset" {
  dataset_id    = var.dataset_config.dataset_id
  friendly_name = var.dataset_config.friendly_name
  description   = var.dataset_config.description
  location      = var.dataset_config.location
  project       = var.project_id
  
  labels = {
    environment = "production"
    pipeline    = "spark-streaming"
  }
  
  access {
    role          = "OWNER"
    user_by_email = data.google_client_openid_userinfo.me.email
  }
  
  access {
    role          = "WRITER"
    user_by_email = var.consumer_service_account
  }
}

data "google_project" "project" {
  project_id = var.project_id
}

data "google_client_openid_userinfo" "me" {}

# Tables BigQuery
resource "google_bigquery_table" "tables" {
  for_each = var.tables
  
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = each.key
  project    = var.project_id
  
  description = each.value.description
  
  # Convertir le schéma en format JSON
  schema = jsonencode([
    for field in each.value.schema : {
      name = field.name
      type = field.type
      mode = field.mode != null ? field.mode : "NULLABLE"
    }
  ])
  
  # Partitioning si spécifié
  dynamic "time_partitioning" {
    for_each = each.value.partition_field != null ? [1] : []
    content {
      type  = "DAY"
      field = each.value.partition_field
    }
  }
  
  # Clustering - désactivé pour l'instant (peut être ajouté manuellement dans BigQuery si nécessaire)
  # Note: Le clustering peut être configuré directement dans BigQuery après création
  
  labels = {
    environment = "production"
    pipeline    = "spark-streaming"
  }
  
  depends_on = [google_bigquery_dataset.dataset]
}

# Outputs
output "dataset_id" {
  description = "ID du dataset BigQuery"
  value       = google_bigquery_dataset.dataset.dataset_id
}

output "dataset_location" {
  description = "Localisation du dataset"
  value       = google_bigquery_dataset.dataset.location
}

output "tables" {
  description = "IDs des tables créées"
  value = {
    for k, v in google_bigquery_table.tables : k => v.table_id
  }
}

