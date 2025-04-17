variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block"
  }
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod/demo)"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Must be within VPC CIDR range."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "Must provide exactly 3 CIDR blocks for public subnets"
  }
  validation {
    condition     = can([for cidr in var.public_subnet_cidrs : cidrhost(cidr, 0)])
    error_message = "All public subnet CIDR blocks must be valid"
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets. Must be within VPC CIDR range."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Must provide exactly 3 CIDR blocks for private subnets"
  }
  validation {
    condition     = can([for cidr in var.private_subnet_cidrs : cidrhost(cidr, 0)])
    error_message = "All private subnet CIDR blocks must be valid"
  }
}

variable "aws_profile" {
  description = "AWS CLI profile to use (dev or demo)"
  type        = string
  validation {
    condition     = contains(["dev", "demo"], var.aws_profile)
    error_message = "AWS profile must be either 'dev' or 'demo'"
  }
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "app_port" {
  description = "Port on which application runs"
  type        = number
}

variable "db_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
  default     = null
}

variable "db_username" {
  description = "Database username for the RDS instance"
  type        = string
}

variable "db_name" {
  description = "Database name for the RDS instance"
  type        = string
}

variable "key_name" {
  description = "The key name to use for the instances"
  type        = string
}
variable "hosted_zone_id" {
  description = "The ID of the hosted zone for the subdomain"
  type        = string
}

#Assg8 variables

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS (leave empty for dev environment to create one)"
  type        = string
  default     = ""
}