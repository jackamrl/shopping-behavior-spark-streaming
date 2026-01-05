provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Module pour activer les APIs nécessaires
module "apis" {
  source = "./modules/apis"
  
  project_id = var.project_id
  apis = [
    "compute.googleapis.com",
    "storage.googleapis.com",
    "dataproc.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com"  # Nécessaire pour gérer les permissions IAM
  ]
}

# Module pour créer les Service Accounts et permissions IAM
module "iam" {
  source = "./modules/iam"
  
  project_id    = var.project_id
  pipeline_name = var.pipeline_name
  environment   = var.environment
  use_existing_service_accounts = var.use_existing_service_accounts
  
  depends_on = [module.apis]
}

# Permissions supplémentaires pour GitHub Actions
# Ces permissions sont ajoutées après la création du Service Account dans le module IAM

# Permission pour gérer les politiques IAM du projet (nécessaire pour modifier les permissions)
resource "google_project_iam_member" "github_actions_project_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${module.iam.github_actions_service_account_email}"
  
  depends_on = [module.iam]
}

# Permission pour activer les APIs
resource "google_project_iam_member" "github_actions_serviceusage" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${module.iam.github_actions_service_account_email}"
  
  depends_on = [module.iam]
}

# Permission pour gérer les buckets GCS (créer, modifier, supprimer)
resource "google_project_iam_member" "github_actions_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${module.iam.github_actions_service_account_email}"
  
  depends_on = [module.iam]
}

# Permission pour lire les datasets BigQuery (nécessaire pour data sources)
resource "google_project_iam_member" "github_actions_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${module.iam.github_actions_service_account_email}"
  
  depends_on = [module.iam]
}

# Permission pour créer et gérer les tables BigQuery
resource "google_project_iam_member" "github_actions_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${module.iam.github_actions_service_account_email}"
  
  depends_on = [module.iam]
}

# Permission pour créer et gérer les canaux de notification Cloud Monitoring
resource "google_project_iam_member" "github_actions_monitoring_notification" {
  project = var.project_id
  role    = "roles/monitoring.notificationChannelEditor"
  member  = "serviceAccount:${module.iam.github_actions_service_account_email}"
  
  depends_on = [module.iam]
}

# Module pour créer les buckets GCS
module "gcs" {
  source = "./modules/gcs"
  
  project_id    = var.project_id
  pipeline_name = var.pipeline_name
  environment   = var.environment
  buckets       = var.gcs_buckets
  use_existing_buckets = var.use_existing_buckets
  
  dataproc_service_account = module.iam.dataproc_service_account_email
  consumer_service_account  = module.iam.consumer_service_account_email
  github_actions_service_account = module.iam.github_actions_service_account_email
  
  depends_on = [module.apis, module.iam]
}

# Module pour créer le dataset et tables BigQuery
module "bigquery" {
  source = "./modules/bigquery"
  
  project_id    = var.project_id
  dataset_config = var.bigquery_dataset
  tables        = var.bigquery_tables
  use_existing_dataset = var.use_existing_dataset
  
  consumer_service_account = module.iam.consumer_service_account_email
  
  depends_on = [module.apis, module.iam]
}

# Module pour créer le cluster Dataproc (optionnel)
module "dataproc" {
  source = "./modules/dataproc"
  
  count = var.dataproc_cluster_config.enable_cluster ? 1 : 0
  
  project_id    = var.project_id
  region        = var.region
  pipeline_name = var.pipeline_name
  environment   = var.environment
  
  cluster_config = var.dataproc_cluster_config
  
  # Utiliser les ressources existantes par défaut
  use_existing_cluster       = true
  use_existing_staging_bucket = true
  
  service_account = module.iam.dataproc_service_account_email
  
  gcs_bucket_data      = module.gcs.data_bucket_name
  gcs_bucket_checkpoint = module.gcs.checkpoint_bucket_name
  bigquery_dataset_id  = module.bigquery.dataset_id
  
  depends_on = [module.apis, module.iam, module.gcs, module.bigquery]
}

# Module pour configurer le monitoring et alertes
module "monitoring" {
  source = "./modules/monitoring"
  
  project_id    = var.project_id
  pipeline_name = var.pipeline_name
  environment   = var.environment
  
  dataproc_cluster_id = var.dataproc_cluster_config.enable_cluster ? module.dataproc[0].cluster_id : null
  bigquery_dataset_id = module.bigquery.dataset_id
  
  depends_on = [module.bigquery]
}
#testtt