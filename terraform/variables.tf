variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP par défaut"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone GCP par défaut"
  type        = string
  default     = "europe-west1-b"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être dev, staging ou prod."
  }
}

variable "pipeline_name" {
  description = "Nom de la pipeline (utilisé pour nommer les ressources)"
  type        = string
  default     = "spark-streaming-pipeline"
}

# Variables pour GCS
variable "gcs_buckets" {
  description = "Configuration des buckets GCS"
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
  default = {}
}

# Variables pour Dataproc
variable "dataproc_cluster_config" {
  description = "Configuration du cluster Dataproc"
  type = object({
    enable_cluster = bool
    machine_type   = string
    num_instances  = number
    image_version  = string
  })
  default = {
    enable_cluster = false
    machine_type   = "n1-standard-4"
    num_instances  = 2
    image_version  = "2.1-debian11"
  }
}

# Variables pour BigQuery
variable "bigquery_dataset" {
  description = "Configuration du dataset BigQuery"
  type = object({
    dataset_id    = string
    location      = string
    description   = string
    friendly_name = string
  })
}

variable "bigquery_tables" {
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

# Variables pour le réseau (optionnel)
variable "create_vpc" {
  description = "Créer un VPC dédié pour Dataproc"
  type        = bool
  default     = false
}

variable "vpc_name" {
  description = "Nom du VPC (si create_vpc = true)"
  type        = string
  default     = ""
}

# Variables pour utiliser les ressources existantes
variable "use_existing_dataset" {
  description = "Si true, utilise le dataset BigQuery existant au lieu d'en créer un nouveau"
  type        = bool
  default     = false
}

variable "use_existing_buckets" {
  description = "Si true, utilise les buckets GCS existants au lieu d'en créer de nouveaux"
  type        = bool
  default     = false
}



