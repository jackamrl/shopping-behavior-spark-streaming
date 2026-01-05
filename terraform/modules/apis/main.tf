variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "apis" {
  description = "Liste des APIs à activer"
  type        = list(string)
}

# Activer toutes les APIs nécessaires
resource "google_project_service" "apis" {
  for_each = toset(var.apis)
  
  project = var.project_id
  service = each.value
  
  disable_dependent_services = false
  disable_on_destroy         = false
}

output "enabled_apis" {
  description = "Liste des APIs activées"
  value       = var.apis
}






