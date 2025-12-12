variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
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

variable "cluster_config" {
  description = "Configuration du cluster"
  type = object({
    machine_type  = string
    num_instances = number
    image_version = string
  })
}

variable "service_account" {
  description = "Email du Service Account pour Dataproc"
  type        = string
}

variable "gcs_bucket_data" {
  description = "Nom du bucket GCS pour les données"
  type        = string
}

variable "gcs_bucket_checkpoint" {
  description = "Nom du bucket GCS pour les checkpoints"
  type        = string
}

variable "bigquery_dataset_id" {
  description = "ID du dataset BigQuery"
  type        = string
}

variable "use_existing_cluster" {
  description = "Si true, utilise le cluster existant au lieu d'en créer un nouveau"
  type        = bool
  default     = true
}

variable "use_existing_staging_bucket" {
  description = "Si true, utilise le bucket de staging existant au lieu d'en créer un nouveau"
  type        = bool
  default     = true
}

locals {
  cluster_name = "${var.pipeline_name}-${var.environment}-cluster"
  staging_bucket = "${var.pipeline_name}-${var.environment}-staging"
}

# Bucket de staging pour Dataproc - Data source pour vérifier si existe
data "google_storage_bucket" "existing_staging" {
  count = var.use_existing_staging_bucket ? 1 : 0
  name  = local.staging_bucket
}

# Bucket de staging pour Dataproc - Création conditionnelle
resource "google_storage_bucket" "staging" {
  count         = var.use_existing_staging_bucket ? 0 : 1
  name          = local.staging_bucket
  location      = var.region
  storage_class = "STANDARD"
  project       = var.project_id
  
  uniform_bucket_level_access = true
  
  labels = {
    environment = var.environment
    pipeline    = var.pipeline_name
    component   = "dataproc-staging"
  }
}

# Local pour utiliser le bucket de staging existant ou créé
locals {
  staging_bucket_name = var.use_existing_staging_bucket ? data.google_storage_bucket.existing_staging[0].name : google_storage_bucket.staging[0].name
}

# Cluster Dataproc - Création conditionnelle
# Si use_existing_cluster = true, le cluster n'est pas créé par Terraform
# Il doit être importé dans le state avec: terraform import module.dataproc[0].google_dataproc_cluster.spark_cluster projects/PROJECT_ID/regions/REGION/clusters/CLUSTER_NAME
resource "google_dataproc_cluster" "spark_cluster" {
  count    = var.use_existing_cluster ? 0 : 1
  name     = local.cluster_name
  region   = var.region
  project  = var.project_id
  
  cluster_config {
    staging_bucket = local.staging_bucket_name
    
    master_config {
      num_instances = 1
      machine_type  = var.cluster_config.machine_type
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 100
      }
    }
    
    worker_config {
      num_instances    = var.cluster_config.num_instances
      machine_type     = var.cluster_config.machine_type
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 100
      }
    }
    
    software_config {
      image_version = var.cluster_config.image_version
      override_properties = {
        "dataproc:dataproc.allow.zero.workers" = "true"
        "spark:spark.sql.adaptive.enabled"     = "true"
        "spark:spark.sql.adaptive.coalescePartitions.enabled" = "true"
        "spark:spark.serializer" = "org.apache.spark.serializer.KryoSerializer"
      }
    }
    
    gce_cluster_config {
      service_account = var.service_account
      service_account_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      tags = ["spark-cluster", var.environment]
    }
    
    # Initialisation pour les connecteurs BigQuery
    initialization_action {
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/connectors/connectors.sh"
      timeout_sec = 300
    }
  }
  
  labels = {
    environment = var.environment
    pipeline    = var.pipeline_name
  }
}

# Local pour utiliser le cluster existant ou créé
# Si use_existing_cluster = true, on utilise le nom du cluster (supposé existant)
# Sinon, on utilise le cluster créé par Terraform
locals {
  cluster_id_value = var.use_existing_cluster ? local.cluster_name : google_dataproc_cluster.spark_cluster[0].name
}

# Outputs
output "cluster_id" {
  description = "ID du cluster Dataproc"
  value       = local.cluster_id_value
}

output "cluster_region" {
  description = "Région du cluster"
  value       = var.region
}

output "staging_bucket" {
  description = "Bucket de staging"
  value       = local.staging_bucket_name
}

