terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Storage bucket name"
  type        = string
}

# Private storage bucket
resource "google_storage_bucket" "private_bucket" {
  name     = var.bucket_name
  location = var.region
  
  uniform_bucket_level_access = true
  
  public_access_prevention = "enforced"
}

# Backend service for the bucket
resource "google_compute_backend_bucket" "bucket_backend" {
  name        = "${var.bucket_name}-backend"
  bucket_name = google_storage_bucket.private_bucket.name
  enable_cdn  = true
}

# URL map
resource "google_compute_url_map" "bucket_url_map" {
  name            = "${var.bucket_name}-url-map"
  default_service = google_compute_backend_bucket.bucket_backend.id
}

# HTTP proxy (no SSL for IP access)
resource "google_compute_target_http_proxy" "bucket_proxy" {
  name    = "${var.bucket_name}-proxy"
  url_map = google_compute_url_map.bucket_url_map.id
}

# Global forwarding rule
resource "google_compute_global_forwarding_rule" "bucket_forwarding_rule" {
  name       = "${var.bucket_name}-forwarding-rule"
  target     = google_compute_target_http_proxy.bucket_proxy.id
  port_range = "80"
}

# Service account for bucket access
resource "google_service_account" "bucket_sa" {
  account_id   = "${var.bucket_name}-sa"
  display_name = "Bucket Service Account"
}

# IAM binding for service account to access bucket
resource "google_storage_bucket_iam_binding" "bucket_access" {
  bucket = google_storage_bucket.private_bucket.name
  role   = "roles/storage.objectViewer"
  
  members = [
    "serviceAccount:${google_service_account.bucket_sa.email}",
    "serviceAccount:service-${data.google_project.project.number}@compute-system.iam.gserviceaccount.com"
  ]
}

data "google_project" "project" {}

# Output the CDN IP address
output "cdn_ip" {
  value = google_compute_global_forwarding_rule.bucket_forwarding_rule.ip_address
}

output "cdn_url" {
  value = "http://${google_compute_global_forwarding_rule.bucket_forwarding_rule.ip_address}"
}

output "bucket_name" {
  value = google_storage_bucket.private_bucket.name
}







#
#
#
#
#
#
#
#
#Now you only need these variables in terraform.tfvars:
#project_id = "your-gcp-project-id"
#bucket_name = "your-unique-bucket-name"
#region = "us-central1"
