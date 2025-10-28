output "ip_address" {
  description = "The internal IP address of the instance."
  value       = google_compute_instance.ubuntu_vm.network_interface[0].network_ip

}
output "image" {
  description = "The image used for the boot disk of the instance."
  value       = google_compute_instance.ubuntu_vm.boot_disk[0].initialize_params[0].image

}

output "instance_name" {
  description = "The name of the Compute Engine instance."
  value       = google_compute_instance.ubuntu_vm.name
}
output "external_ip" {
  description = "The external IP address of the instance."
  value       = google_compute_instance.ubuntu_vm.network_interface[0].access_config[0].nat_ip
}
output "zone" {
  description = "The zone where the instance is deployed."
  value       = google_compute_instance.ubuntu_vm.zone
}
output "machine_type" {
  description = "The machine type of the instance."
  value       = google_compute_instance.ubuntu_vm.machine_type
}

# outputs.tf (root)

output "db_name" {
  value = module.storage_db.db_name
}

output "db_user_name" {
  value = module.storage_db.db_user_name
}

output "db_password" {
  value     = module.storage_db.db_password
  sensitive = true
}

output "db_instance_ip" {
  value = module.storage_db.db_instance_ip
}
