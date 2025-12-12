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

variable "dataproc_cluster_id" {
  description = "ID du cluster Dataproc (optionnel)"
  type        = string
  default     = null
}

variable "bigquery_dataset_id" {
  description = "ID du dataset BigQuery"
  type        = string
}

# Groupe de notification pour les alertes
resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "${var.pipeline_name}-${var.environment}-email"
  type         = "email"
  
  labels = {
    email_address = "admin@example.com"  # À remplacer par votre email
  }
  
  enabled = true
}

# Alerte pour les erreurs Dataproc (si cluster activé)
resource "google_monitoring_alert_policy" "dataproc_errors" {
  count = var.dataproc_cluster_id != null ? 1 : 0
  
  project      = var.project_id
  display_name = "${var.pipeline_name}-${var.environment} - Erreurs Dataproc"
  combiner     = "OR"
  
  conditions {
    display_name = "Erreurs dans les logs Dataproc"
    
    condition_threshold {
      filter          = "resource.type=\"cloud_dataproc_cluster\" AND resource.labels.cluster_name=\"${var.dataproc_cluster_id}\" AND severity=\"ERROR\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.id]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Alerte pour les erreurs BigQuery - Désactivée pour l'instant
# Note: Les alertes BigQuery nécessitent des métriques spécifiques
# qui peuvent être configurées manuellement dans Cloud Monitoring
# resource "google_monitoring_alert_policy" "bigquery_errors" {
#   ...
# }

# Outputs
output "notification_channel_id" {
  description = "ID du canal de notification"
  value       = google_monitoring_notification_channel.email.id
}



