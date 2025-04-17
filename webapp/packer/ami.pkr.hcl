packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.0"
    }
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1.0"
    }
  }
}

# AWS Variables
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_source_ami" {
  type    = string
  default = "ami-04b4f1a9cf54c11d0"
}

variable "aws_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "aws_ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "aws_volume_size" {
  type    = number
  default = 8
}

variable "aws_volume_type" {
  type    = string
  default = "gp2"
}

# GCP Dev Variables
variable "gcp_project_id" {
  type    = string
  default = "dummy"
}

# GCP Demo Variables
variable "gcp_demo_project_id" {
  type    = string
  default = env("GCP_DEMO_PROJECT_ID")
}

variable "gcp_source_image_family" {
  type    = string
  default = "ubuntu-2404-lts-amd64"
}

variable "gcp_machine_type" {
  type    = string
  default = "e2-medium"
}

variable "gcp_zone" {
  type    = string
  default = "us-east1-b"
}

variable "gcp_ssh_username" {
  type    = string
  default = "packer"
}

variable "gcp_network" {
  type    = string
  default = "default"
}

variable "db_password" {
  type    = string
  default = env("DB_PASSWORD")
}

variable "db_user" {
  type    = string
  default = env("DB_USER")
}

variable "db_name" {
  type    = string
  default = env("DB_NAME")
}

variable "demo_aws_account_id" {
  type    = string
  default = env("AWS_DEMO_ID")
}

source "amazon-ebs" "aws_image" {
  region        = var.aws_region
  source_ami    = var.aws_source_ami
  instance_type = var.aws_instance_type
  ssh_username  = var.aws_ssh_username
  ami_name      = "custom-aws-image-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}"
  ami_users     = [var.demo_aws_account_id] #demo account sharing

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.aws_volume_size
    volume_type           = var.aws_volume_type
    delete_on_termination = true
  }
  tags = {
    Name        = "custom-aws-image-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}"
    Environment = "dev"
    Builder     = "packer"
  }
}

source "googlecompute" "gcp_image" {
  project_id          = var.gcp_project_id
  source_image_family = var.gcp_source_image_family
  image_name          = "custom-gcp-image-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}"
  image_family        = "custom-family"
  machine_type        = var.gcp_machine_type
  zone                = var.gcp_zone
  ssh_username        = var.gcp_ssh_username
  image_description   = "Machine Image with Node.js and PostgreSQl on Ubuntu"
  use_internal_ip     = false
  network             = var.gcp_network

  image_labels = {
    environment = "dev"
    builder     = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.aws_image", ]

  provisioner "file" {
    source      = "./packer/webapp.zip"
    destination = "/tmp/webapp.zip"
  }

  provisioner "file" {
    source      = "./packer/systemd.service"
    destination = "/tmp/systemd.service"
  }
  provisioner "shell" {
    script = "./packer/ami-setup.sh"
    environment_vars = [
      "DB_PASSWORD=${var.db_password}",
      "DB_USER=${var.db_user}",
      "DB_NAME=${var.db_name}"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y curl",
      "curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb",
      "sudo dpkg -i amazon-cloudwatch-agent.deb || sudo apt-get install -f -y",
      "sudo systemctl enable amazon-cloudwatch-agent",
      "sudo systemctl start amazon-cloudwatch-agent"
    ]
  }

  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}