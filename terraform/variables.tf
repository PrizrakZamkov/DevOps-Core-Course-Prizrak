# Переменные для конфигурации Yandex Cloud

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "zone" {
  description = "Yandex Cloud zone"
  type        = string
  default     = "ru-central1-a"
}

variable "service_account_key_file" {
  description = "Path to service account key file"
  type        = string
  default     = "key.json"
}

variable "vm_name" {
  description = "Name of the VM instance"
  type        = string
  default     = "lab04-vm"
}

variable "vm_image_family" {
  description = "OS image family"
  type        = string
  default     = "ubuntu-2404-lts"
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Amount of RAM in GB"
  type        = number
  default     = 2
}

variable "vm_core_fraction" {
  description = "CPU core fraction (for burstable instances)"
  type        = number
  default     = 20 # 20% для free tier
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "ubuntu"
}


variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub username or organization"
  type        = string
}

variable "repo_name" {
  description = "Repository name to manage"
  type        = string
}