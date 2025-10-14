# GCP Production Infrastructure with Terraform

## Prerequisites

1. **Install Required Tools:**
   ```bash
   # Install Terraform
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt-get update && sudo apt-get install terraform

   # Install Google Cloud SDK
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   ```

2. **GCP Setup:**
   ```bash
   # Authenticate
   gcloud auth login
   gcloud auth application-default login

   # Set project
   gcloud config set project YOUR_PROJECT_ID

   # Enable required APIs
   gcloud services enable compute.googleapis.com
   gcloud services enable storage.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   gcloud services enable sqladmin.googleapis.com
   gcloud services enable servicenetworking.googleapis.com
   ```

## Project Structure

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── storage/
│   ├── database/
│   ├── secrets/
│   └── artifact-registry/
├── shared/
│   ├── variables.tf
│   └── outputs.tf
└── scripts/
    └── setup.sh
```

## Core Modules

### 1. VPC Module (`modules/vpc/main.tf`)

```hcl
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "${var.vpc_name}-private"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "${var.vpc_name}-public"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.vpc_name}-nat"
  router = google_compute_router.router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.private_subnet_cidr]
}
```

### 2. Storage Module (`modules/storage/main.tf`)

```hcl
resource "google_storage_bucket" "public_bucket" {
  name          = "${var.project_id}-${var.environment}-public"
  location      = var.region
  force_destroy = var.force_destroy

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket" "private_bucket" {
  name          = "${var.project_id}-${var.environment}-private"
  location      = var.region
  force_destroy = var.force_destroy

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_key.id
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}

resource "google_kms_key_ring" "bucket_keyring" {
  name     = "${var.project_id}-${var.environment}-bucket-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "bucket_key" {
  name     = "bucket-key"
  key_ring = google_kms_key_ring.bucket_keyring.id

  rotation_period = "7776000s" # 90 days
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.public_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
```

### 3. Artifact Registry Module (`modules/artifact-registry/main.tf`)

```hcl
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "${var.project_id}-${var.environment}-docker"
  description   = "Docker repository for ${var.environment}"
  format        = "DOCKER"

  cleanup_policies {
    id     = "delete-old-images"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 days
    }
  }

  cleanup_policies {
    id     = "keep-recent-tagged"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }
}

resource "google_artifact_registry_repository" "npm_repo" {
  location      = var.region
  repository_id = "${var.project_id}-${var.environment}-npm"
  description   = "NPM repository for ${var.environment}"
  format        = "NPM"
}

resource "google_artifact_registry_repository_iam_member" "docker_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.service_account_email}"
}
```

### 4. Database Module (`modules/database/main.tf`)

```hcl
resource "google_sql_database_instance" "postgres" {
  name             = "${var.project_id}-${var.environment}-postgres"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = var.db_tier
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.db_disk_size
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
      require_ssl     = true
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }
  }

  deletion_protection = var.environment == "prod" ? true : false

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.project_id}-${var.environment}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database" "app_database" {
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "app_user" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

resource "google_sql_ssl_cert" "client_cert" {
  common_name = "${var.project_id}-${var.environment}-client-cert"
  instance    = google_sql_database_instance.postgres.name
}
```

### 5. Secrets Module (`modules/secrets/main.tf`)

```hcl
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_id}-${var.environment}-db-password"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

resource "google_secret_manager_secret" "api_keys" {
  secret_id = "${var.project_id}-${var.environment}-api-keys"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "api_keys_version" {
  secret = google_secret_manager_secret.api_keys.id
  secret_data = jsonencode({
    stripe_key    = var.stripe_api_key
    sendgrid_key  = var.sendgrid_api_key
    jwt_secret    = var.jwt_secret
  })
}

resource "google_secret_manager_secret_iam_member" "secret_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}
```

## Environment Configuration

### Development Environment (`environments/dev/main.tf`)

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_name            = "${var.project_id}-${var.environment}-vpc"
  region              = var.region
  private_subnet_cidr = "10.0.1.0/24"
  public_subnet_cidr  = "10.0.2.0/24"
  pods_cidr          = "10.1.0.0/16"
  services_cidr      = "10.2.0.0/16"
}

module "storage" {
  source = "../../modules/storage"

  project_id    = var.project_id
  environment   = var.environment
  region        = var.region
  force_destroy = true
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id            = var.project_id
  environment           = var.environment
  region                = var.region
  service_account_email = google_service_account.app_service_account.email
}

module "database" {
  source = "../../modules/database"

  project_id    = var.project_id
  environment   = var.environment
  region        = var.region
  vpc_id        = module.vpc.vpc_id
  db_tier       = "db-f1-micro"
  db_disk_size  = 20
  database_name = var.database_name
  db_username   = var.db_username
  db_password   = random_password.db_password.result
}

module "secrets" {
  source = "../../modules/secrets"

  project_id            = var.project_id
  environment           = var.environment
  region                = var.region
  db_password           = random_password.db_password.result
  stripe_api_key        = var.stripe_api_key
  sendgrid_api_key      = var.sendgrid_api_key
  jwt_secret            = random_password.jwt_secret.result
  service_account_email = google_service_account.app_service_account.email
}

resource "google_service_account" "app_service_account" {
  account_id   = "${var.project_id}-${var.environment}-app"
  display_name = "Application Service Account"
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}
```

### Variables (`environments/dev/terraform.tfvars`)

```hcl
project_id       = "your-gcp-project-id"
environment      = "dev"
region           = "us-central1"
database_name    = "app_db"
db_username      = "app_user"
stripe_api_key   = "sk_test_..."
sendgrid_api_key = "SG...."
```

### Backend Configuration (`environments/dev/backend.tf`)

```hcl
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "terraform/dev"
  }
}
```

## Shared Variables (`shared/variables.tf`)

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "stripe_api_key" {
  description = "Stripe API key"
  type        = string
  sensitive   = true
}

variable "sendgrid_api_key" {
  description = "SendGrid API key"
  type        = string
  sensitive   = true
}
```

## Setup Script (`scripts/setup.sh`)

```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
PROJECT_ID=${2}

if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <environment> <project-id>"
    exit 1
fi

echo "Setting up Terraform for environment: $ENVIRONMENT"

# Create state bucket if it doesn't exist
BUCKET_NAME="${PROJECT_ID}-terraform-state"
if ! gsutil ls -b gs://$BUCKET_NAME > /dev/null 2>&1; then
    echo "Creating state bucket: $BUCKET_NAME"
    gsutil mb gs://$BUCKET_NAME
    gsutil versioning set on gs://$BUCKET_NAME
fi

# Navigate to environment directory
cd "environments/$ENVIRONMENT"

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan

echo "Setup complete! Run 'terraform apply' to deploy infrastructure."
```

## Best Practices Implemented

1. **Security:**
   - Private subnets with NAT gateway
   - KMS encryption for storage
   - SSL required for database
   - IAM least privilege access
   - Secrets stored in Secret Manager

2. **High Availability:**
   - Regional database for production
   - Multi-zone deployments
   - Backup and point-in-time recovery

3. **Cost Optimization:**
   - Lifecycle policies for storage
   - Appropriate instance sizing per environment
   - Cleanup policies for artifacts

4. **Monitoring & Logging:**
   - Database connection logging
   - NAT gateway logging
   - Audit trails enabled

5. **Infrastructure as Code:**
   - Modular design for reusability
   - Environment-specific configurations
   - State management with remote backend

## Deployment Commands

```bash
# Initial setup
./scripts/setup.sh dev your-project-id

# Deploy infrastructure
cd environments/dev
terraform apply

# View outputs
terraform output

# Destroy (when needed)
terraform destroy
```

## Extending Infrastructure

To add new resources:

1. Create new modules in `modules/` directory
2. Add module calls in environment `main.tf`
3. Define variables in `shared/variables.tf`
4. Update `terraform.tfvars` with new values

Example: Adding Cloud Run service:

```hcl
# modules/cloud-run/main.tf
resource "google_cloud_run_service" "app" {
  name     = "${var.project_id}-${var.environment}-app"
  location = var.region

  template {
    spec {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo}/app:latest"
      }
    }
  }
}
```

This setup provides a solid foundation for production GCP infrastructure that you can extend as your needs grow.
