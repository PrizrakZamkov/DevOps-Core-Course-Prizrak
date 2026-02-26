# Вывод полезной информации после apply

output "vm_id" {
  description = "ID of the created VM"
  value       = yandex_compute_instance.lab04_vm.id
}

output "vm_name" {
  description = "Name of the VM"
  value       = yandex_compute_instance.lab04_vm.name
}

output "vm_external_ip" {
  description = "External IP address of the VM"
  value       = yandex_compute_instance.lab04_vm.network_interface[0].nat_ip_address
}

output "vm_internal_ip" {
  description = "Internal IP address of the VM"
  value       = yandex_compute_instance.lab04_vm.network_interface[0].ip_address
}

output "ssh_connection_string" {
  description = "SSH connection command"
  value       = "ssh ${var.ssh_user}@${yandex_compute_instance.lab04_vm.network_interface[0].nat_ip_address}"
}

output "network_id" {
  description = "ID of the created network"
  value       = yandex_vpc_network.lab04_network.id
}

output "subnet_id" {
  description = "ID of the created subnet"
  value       = yandex_vpc_subnet.lab04_subnet.id
}