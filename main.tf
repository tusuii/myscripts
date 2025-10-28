provider "google" {
  project     = "vibrant-epsilon-475606-f6"
  region      = var.region
  credentials = file("/home/subodh/Documents/ajna/gcp-terraform/vibrant-epsilon-475606-f6-4cb5da7203b0.json")
}

# Create a Compute Engine instance
resource "google_compute_instance" "ubuntu_vm" {
  name         = var.instance_name
  zone         = "${var.region}-c"
  machine_type = var.os_family # You can change to e2-small, n1-standard-1, etc.

  # Boot disk configuration
  boot_disk {
    initialize_params {
      image = var.image # Ubuntu 22.04 LTS image
      size  = 20        # Disk size in GB
    }
  }

  # Network configuration
  network_interface {
    network = "default"

    # Assign external IP
    access_config {
    }
  }

  # Optional: Add metadata (e.g., SSH key)
  metadata = {
    ssh-keys = "${var.username}:${file("~/.ssh/id_rsa.pub")}"
  }

  # Optional: Tags (e.g., for firewall rules)
  tags = ["ubuntu", "test-vm"]
}


#--------------------------------instance 2
resource "google_compute_instance" "jenkins_slave_2" {
  name         = var.instance_name_2
  zone         = "${var.region}-c"
  machine_type = var.os_family # You can change to e2-small, n1-standard-1, etc.

  # Boot disk configuration
  boot_disk {
    initialize_params {
      image = var.image # Ubuntu 22.04 LTS image
      size  = 20        # Disk size in GB
    }
  }

  # Network configuration
  network_interface {
    network = "default"

    # Assign external IP
    access_config {
    }
  }

  # Optional: Add metadata (e.g., SSH key)
  metadata = {
    ssh-keys = "${var.username}:${file("~/.ssh/id_rsa.pub")}"
  }

  # Optional: Tags (e.g., for firewall rules)
  tags = ["ubuntu", "test-vm"]
}

module "storage_bucket" {
  count = 2
  source      = "./modules/storage_bucket"
  bucket_name = "my-modular-bucket-${count.index}"
}

# --------------------------------------
# Module: Cloud SQL PostgreSQL
# --------------------------------------
module "storage_db" {
  source = "./modules/storage_db"

  # PostgreSQL version
  dbversion    = var.dbversion       # e.g., "POSTGRES_15"

  # Cloud SQL instance configuration
  name         = var.name            # e.g., "my-postgres-instance"
  tier         = var.tier            # e.g., "db-f1-micro"

  # Database inside the instance
  db_name      = var.db_name         # e.g., "mydb"

  # Database user
  db_user_name = var.db_user_name    # e.g., "postgres"
  db_password  = var.db_password     # sensitive, use var
}


# --------------------------------------
