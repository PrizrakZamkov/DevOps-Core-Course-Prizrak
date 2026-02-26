# Настройка Terraform и провайдера
terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100"
    }
  }
}

# Провайдер Yandex Cloud
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

# Сеть
resource "yandex_vpc_network" "lab04_network" {
  name = "${var.vm_name}-network"

  labels = {
    environment = "lab04"
    managed_by  = "terraform"
  }
}

# Подсеть
resource "yandex_vpc_subnet" "lab04_subnet" {
  name           = "${var.vm_name}-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.lab04_network.id
  v4_cidr_blocks = ["10.2.0.0/24"]

  labels = {
    environment = "lab04"
    managed_by  = "terraform"
  }
}

# Security Group (Firewall)
resource "yandex_vpc_security_group" "lab04_sg" {
  name       = "${var.vm_name}-sg"
  network_id = yandex_vpc_network.lab04_network.id

  # Входящий SSH
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow SSH"
  }

  # Входящий HTTP
  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow HTTP"
  }

  # Входящий порт приложения
  ingress {
    protocol       = "TCP"
    port           = 5000
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow application port"
  }

  # Исходящий трафик (разрешить всё)
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound traffic"
  }

  labels = {
    environment = "lab04"
    managed_by  = "terraform"
  }
}

# Виртуальная машина
resource "yandex_compute_instance" "lab04_vm" {
  name        = var.vm_name
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory
    core_fraction = var.vm_core_fraction # 20% для free tier
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10 # GB
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lab04_subnet.id
    security_group_ids = [yandex_vpc_security_group.lab04_sg.id]
    nat                = true # Публичный IP
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }

  labels = {
    environment = "lab04"
    managed_by  = "terraform"
    purpose     = "learning"
  }

  # Разрешить прерываемые VM (дешевле)
  scheduling_policy {
    preemptible = false # Используй false для стабильности
  }
}

# Data source для получения образа Ubuntu
data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}