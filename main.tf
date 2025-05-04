provider "google" {
  project = "clgcporg10-181"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name                    = "wiz-iac-cluster"
  location                = "us-central1-a"
  remove_default_node_pool = true
  deletion_protection     = false
}

# GKE Node Pool
resource "google_container_node_pool" "default_pool" {
  name       = "default-pool"
  cluster    = google_container_cluster.gke_cluster.name
  location   = "us-central1-a"
  node_count = 3

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# MongoDB VM Instance
resource "google_compute_instance" "mongodb_vm" {
  name         = "mongo-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network       = "default"
    access_config {}  # Assigns external IP
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y gnupg curl
    curl -fsSL https://pgp.mongodb.com/server-4.4.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update
    apt-get install -y mongodb-org
    systemctl start mongod
    systemctl enable mongod
    sleep 10
    mongo --eval 'db.createUser({user:"wills",pwd:"12345a",roles:[{role:"readWrite",db:"test"}]})'
  EOT
}

# Public GCS Bucket for Backups
resource "google_storage_bucket" "wiz_db" {
  name          = "wizard-iac-storage"
  location      = "US"
  force_destroy = true
  uniform_bucket_level_access = true
}

# Make GCS Bucket Public (misconfiguration)
resource "google_storage_bucket_iam_binding" "public_read" {
  bucket = google_storage_bucket.wiz_db.name

  role    = "roles/storage.objectViewer"
  members = ["allUsers"]
}
