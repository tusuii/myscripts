
variable "network_name" {
  description = "The name of the VPC network."
  type        = string
  default     = "default-network"
}

variable "image" {
  description = "image for installation"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}
variable "subnetwork_name" {
  description = "The name of the subnetwork."
  type        = string
  default     = "default-subnetwork"
}

variable "username" {
  description = "username of the instance"
  type        = string
  default     = "ubuntu"
}
variable "region" {
  description = "The region where resources will be created."
  type        = string
  default     = "asia-south1"

}
variable "internal_address_name" {
  description = "The name of the internal IP address resource."
  type        = string
  default     = "internal-ip-address"
}

variable "subnetwork_cidr" {
  description = "The CIDR range for the subnetwork."
  type        = string
  default     = "10.0.42.0/24"
}

variable "internal_address" {
  description = "The specific internal IP address to be assigned."
  type        = string
  default     = "10.0.42.42"
}

variable "os_family" {
  description = "this is the os for the vm"
  type        = string
  default     = "e2-micro"
}

variable "os_project" {
  description = "os_project"
  type        = string
  default     = "ubuntu-22-04"
}

variable "instance_name" {
  description = "name of the instance"
  default     = "my-test-instance"
  type        = string
}
variable "instance_name_2" {
  description = "name of the instance"
  default     = "jenkins-slave-2"
  type        = string
}

#-------------------------------------
variable "dbversion" {
  description = "Postgres database version for Cloud SQL instance"
  type        = string
  default     = "POSTGRES_15"
}

variable "name" {
  description = "Cloud SQL instance name"
  type        = string
  default     = "my-postgres-instance"
}

variable "tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "mydb"
}

variable "db_user_name" {
  description = "Database username"
  type        = string
  default     = "postgres_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "MyStrongPassword123!"
  sensitive   = true
}
#-------------------------------------