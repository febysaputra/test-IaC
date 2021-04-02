terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.12.0"
    }
  }
}

provider "google" {

  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_subnetwork" "subnet" {
  name = "terraform-subnetwork"
  ip_cidr_range = "10.12.0.0/24"
  region = var.region
  network = google_compute_network.vpc_network.name
}

resource "google_compute_router" "router" {
  name    = "terraform-router"
  region  = google_compute_subnetwork.subnet.region
  network = google_compute_network.vpc_network.name
}

resource "google_compute_router_nat" "nat" {
  name                               = "router"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_address" "vm_static_ip" {
  name = "terraform-static-ip"
  region = var.region
}

resource "google_compute_instance_template" "foobar" {
  name           = "my-instance-template"
  machine_type   = "f1-micro"
  can_ip_forward = false

  tags = ["vm"]

  disk {
    source_image = "debian-cloud/debian-9"
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      nat_ip = google_compute_address.vm_static_ip.address
    }
  }
}

resource "google_compute_target_pool" "foobar" {
  name = "my-target-pool"
}

resource "google_compute_instance_group_manager" "foobar" {
  name = "my-igm"
  zone = var.zone

  version {
    instance_template  = google_compute_instance_template.foobar.id
    name               = "primary"
  }

  target_pools       = [google_compute_target_pool.foobar.id]
  base_instance_name = "foobar"
}

resource "google_compute_autoscaler" "foobar" {
  name   = "my-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.foobar.name

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.45
    }
  }
}