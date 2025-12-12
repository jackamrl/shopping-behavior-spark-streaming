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

locals {
  cluster_name = "${var.pipeline_name}-${var.environment}-cluster"
  staging_bucket = "${var.pipeline_name}-${var.environment}-staging"
}

# Bucket de staging pour Dataproc
resource "google_storage_bucket" "staging" {
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

# Cluster Dataproc
resource "google_dataproc_cluster" "spark_cluster" {
  name     = local.cluster_name
  region   = var.region
  project  = var.project_id
  
  cluster_config {
    staging_bucket = google_storage_bucket.staging.name
    
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

# Outputs
output "cluster_id" {
  description = "ID du cluster Dataproc"
  value       = google_dataproc_cluster.spark_cluster.name
}

output "cluster_region" {
  description = "Région du cluster"
  value       = var.region
}

output "staging_bucket" {
  description = "Bucket de staging"
  value       = google_storage_bucket.staging.name
}

