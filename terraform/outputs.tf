output "gcs_buckets" {
  description = "Informations sur les buckets GCS créés"
  value = {
    data_bucket      = module.gcs.data_bucket_name
    checkpoint_bucket = module.gcs.checkpoint_bucket_name
    artifacts_bucket  = module.gcs.artifacts_bucket_name
  }
}

output "bigquery_dataset" {
  description = "Informations sur le dataset BigQuery"
  value = {
    dataset_id    = module.bigquery.dataset_id
    full_dataset_id = "${var.project_id}:${module.bigquery.dataset_id}"
  }
}

output "dataproc_cluster" {
  description = "Informations sur le cluster Dataproc (si activé)"
  value = var.dataproc_cluster_config.enable_cluster ? {
    cluster_id = module.dataproc[0].cluster_id
    region     = var.region
  } : null
}

output "service_accounts" {
  description = "Emails des Service Accounts créés"
  value = {
    dataproc       = module.iam.dataproc_service_account_email
    consumer       = module.iam.consumer_service_account_email
    github_actions = module.iam.github_actions_service_account_email
  }
}

output "github_actions_key" {
  description = "Clé JSON du Service Account GitHub Actions (à ajouter dans GitHub Secrets)"
  value       = module.iam.github_actions_key
  sensitive   = true
}

output "configuration_summary" {
  description = "Résumé de la configuration déployée"
  value = {
    project_id    = var.project_id
    environment   = var.environment
    region        = var.region
    pipeline_name = var.pipeline_name
  }
}



