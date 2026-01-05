terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
  
  # Backend GCS pour stocker le state Terraform
  # À configurer après création du bucket de state
  # backend "gcs" {
  #   bucket = "terraform-state-bucket"
  #   prefix = "spark-streaming-pipeline"
  # }
}






