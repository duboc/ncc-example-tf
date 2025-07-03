# Network Connectivity Center (NCC) Simple Topology
# This creates a hub-and-spoke topology with VPC spokes

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-a"
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com"
  
  disable_dependent_services = true
}

resource "google_project_service" "networkconnectivity_api" {
  project = var.project_id
  service = "networkconnectivity.googleapis.com"
  
  disable_dependent_services = true
  depends_on = [google_project_service.compute_api]
}

# Create VPC networks for spokes
resource "google_compute_network" "spoke_vpc_1" {
  name                    = "ncc-spoke-vpc-1"
  auto_create_subnetworks = false
  
  depends_on = [google_project_service.compute_api]
}

resource "google_compute_network" "spoke_vpc_2" {
  name                    = "ncc-spoke-vpc-2"
  auto_create_subnetworks = false
  
  depends_on = [google_project_service.compute_api]
}

# Create subnets for each spoke VPC
resource "google_compute_subnetwork" "spoke_subnet_1" {
  name          = "ncc-spoke-subnet-1"
  ip_cidr_range = "10.1.0.0/24"
  region        = var.region
  network       = google_compute_network.spoke_vpc_1.id
}

resource "google_compute_subnetwork" "spoke_subnet_2" {
  name          = "ncc-spoke-subnet-2"
  ip_cidr_range = "10.2.0.0/24"
  region        = var.region
  network       = google_compute_network.spoke_vpc_2.id
}

# Create firewall rules for internal communication
resource "google_compute_firewall" "spoke_1_internal" {
  name    = "ncc-spoke-1-internal"
  network = google_compute_network.spoke_vpc_1.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["ncc-spoke-1"]
}

resource "google_compute_firewall" "spoke_2_internal" {
  name    = "ncc-spoke-2-internal"
  network = google_compute_network.spoke_vpc_2.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["ncc-spoke-2"]
}

# Create NCC Hub
resource "google_network_connectivity_hub" "ncc_hub" {
  name        = "ncc-hub"
  description = "Network Connectivity Center Hub for simple topology"
  
  depends_on = [google_project_service.networkconnectivity_api]
}

# Create VPC spokes
resource "google_network_connectivity_spoke" "spoke_1" {
  name     = "ncc-spoke-1"
  location = "global"
  hub      = google_network_connectivity_hub.ncc_hub.id

  linked_vpc_network {
    uri                        = google_compute_network.spoke_vpc_1.self_link
    exclude_export_ranges      = []
  }

  description = "VPC Spoke 1 connected to NCC Hub"
}

resource "google_network_connectivity_spoke" "spoke_2" {
  name     = "ncc-spoke-2"
  location = "global"
  hub      = google_network_connectivity_hub.ncc_hub.id

  linked_vpc_network {
    uri                        = google_compute_network.spoke_vpc_2.self_link
    exclude_export_ranges      = []
  }

  description = "VPC Spoke 2 connected to NCC Hub"
}

# Create sample VM instances for testing connectivity
resource "google_compute_instance" "spoke_1_vm" {
  name         = "ncc-spoke-1-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.spoke_vpc_1.name
    subnetwork = google_compute_subnetwork.spoke_subnet_1.name
  }

  tags = ["ncc-spoke-1"]

  metadata_startup_script = "apt-get update && apt-get install -y apache2"

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "spoke_2_vm" {
  name         = "ncc-spoke-2-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.spoke_vpc_2.name
    subnetwork = google_compute_subnetwork.spoke_subnet_2.name
  }

  tags = ["ncc-spoke-2"]

  metadata_startup_script = "apt-get update && apt-get install -y apache2"

  service_account {
    scopes = ["cloud-platform"]
  }
}

# Outputs
output "ncc_hub_id" {
  description = "The ID of the NCC Hub"
  value       = google_network_connectivity_hub.ncc_hub.id
}

output "ncc_hub_name" {
  description = "The name of the NCC Hub"
  value       = google_network_connectivity_hub.ncc_hub.name
}

output "spoke_1_id" {
  description = "The ID of Spoke 1"
  value       = google_network_connectivity_spoke.spoke_1.id
}

output "spoke_2_id" {
  description = "The ID of Spoke 2"
  value       = google_network_connectivity_spoke.spoke_2.id
}

output "spoke_1_vm_internal_ip" {
  description = "Internal IP of VM in Spoke 1"
  value       = google_compute_instance.spoke_1_vm.network_interface[0].network_ip
}

output "spoke_2_vm_internal_ip" {
  description = "Internal IP of VM in Spoke 2"
  value       = google_compute_instance.spoke_2_vm.network_interface[0].network_ip
}

output "instructions" {
  description = "Instructions for using the NCC deployment"
  value = <<-EOT
    Your NCC hub and spokes have been deployed successfully!
    
    To use this deployment:
    1. Set your project ID: export TF_VAR_project_id="your-project-id"
    2. Run: terraform init
    3. Run: terraform plan
    4. Run: terraform apply
    
    The topology includes:
    - 1 NCC Hub
    - 2 VPC Spokes (with subnets in ${var.region})
    - 2 test VMs (one in each spoke)
    - Firewall rules for internal communication
    
    You can test connectivity between VMs using their internal IPs.
  EOT
}