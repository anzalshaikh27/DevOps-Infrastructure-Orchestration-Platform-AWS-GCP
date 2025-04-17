# AWS VPC Infrastructure with Terraform and GitHub Actions

This repository contains Terraform configurations for creating AWS VPC infrastructure and implements CI/CD using GitHub Actions.

## Infrastructure Overview

The Terraform configuration creates:
* VPC with DNS support
* 3 Public Subnets across different AZs
* 3 Private Subnets across different AZs
* Internet Gateway
* Route Tables (Public and Private)
* Application Security Group
* EC2 Instance with Custom AMI
* RDS PostgreSQL Instance
* Database Security Group
* S3 Bucket with Lifecycle Policy
* IAM Role for EC2-S3 Access
* CloudWatch Log Groups and Metrics Configuration
* Auto Scaling Group with Launch Template
* Application Load Balancer
* Route53 DNS Configuration

## Prerequisites

1. AWS Account and Access
   * IAM user with appropriate VPC permissions
   * AWS CLI configured with dev/demo profiles
   * No default profile (use explicit profiles)

2. GitHub Repository Setup
   * Fork the repository
   * Set up branch protection rules
   * Configure GitHub Actions secrets

## AWS Configuration

### AWS CLI Profile Setup
```bash
# Check existing profiles
aws configure list-profiles

# Configure dev profile
aws configure --profile dev
AWS Access Key ID: [YOUR_ACCESS_KEY]
AWS Secret Access Key: [YOUR_SECRET_KEY]
Default region name: us-east-1
Default output format: json
```

### GitHub Actions IAM User
1. Create IAM User:
   * User name: github-actions-terraform
   * Access type: Programmatic access only
   * Attach AWSVPCFullAccess policy
   * Save Access Keys for GitHub Secrets

## Repository Structure
```
├── provider.tf                # AWS provider configuration
├── variables.tf               # Variable declarations
├── vpc.tf                     # VPC resource
├── cloudwatch.tf              # Cloudwatch log groups and metrics configuration
├── subnets.tf                 # Public and private subnets
├── route_tables.tf            # Route tables configuration
├── security_groups.tf         # Security groups for application, load balancer, and database
├── ec2.tf                     # EC2 instance configuration with user data
├── launch_template.tf         # Launch template for auto scaling
├── auto_scaling.tf            # Auto scaling group and policies
├── load_balancer.tf           # Application load balancer configuration
├── route53.tf                 # DNS configuration for subdomains
├── rds.tf                     # RDS instance configuration
├── s3.tf                      # S3 bucket configuration
├── iam.tf                     # IAM roles and policies
├── dev.tfvars                 # Variables for dev environment
├── demo.tfvars                # Variables for demo environment
└── .github/workflows/         # GitHub Actions workflows
```

## Terraform Configuration

### Variables (dev.tfvars)
```hcl
aws_profile = "dev"
vpc_name = "dev-vpc"
vpc_cidr = "10.0.0.0/16"
region = "us-east-1"
environment = "dev"
ami_id = "ami-xxxxx"  # Your custom AMI ID
instance_type = "t2.micro"
app_port = 8080
db_password = "password"  # Password for RDS instance
key_name = "your-key-name"
hosted_zone_id = "your-hosted-zone-id"

availability_zones = [
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24",
  "10.0.13.0/24"
]
```

## Application Security Group

The security group configuration includes:

```hcl
resource "aws_security_group" "application" {
  name        = "${var.vpc_name}-application-sg"
  description = "Security group for web applications"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port access
  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## EC2 Instance

The EC2 instance configuration includes:

```hcl
resource "aws_instance" "app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[0].id
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  vpc_security_group_ids = [aws_security_group.application.id]
  
  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  disable_api_termination = false  # No accidental termination protection
}
```

## Assignment 05 and 06: RDS, S3, Cloudwatch and IAM Resources

This assignment enhances the infrastructure with database, storage, and proper access management:

### Database Security Group

A security group specifically for RDS instances that:
- Allows PostgreSQL traffic (port 5432) only from the application security group
- Restricts direct internet access to the database
- Limits outbound traffic to the VPC CIDR block following least privilege principle

### RDS PostgreSQL Database

A PostgreSQL database instance that:
- Uses a custom parameter group instead of default
- Is deployed in private subnets for security
- Has encryption enabled for data at rest
- Is accessible only through the application servers

### S3 Bucket Configuration

A private S3 bucket that:
- Uses UUID naming for uniqueness
- Has default encryption enabled
- Implements a lifecycle policy to transition objects to STANDARD_IA after 30 days
- Blocks all public access

### IAM Role Configuration

IAM roles and policies that:
- Allow EC2 instances to access the S3 bucket
- Follow the principle of least privilege
- Are attached to EC2 instances via instance profiles
- Enable secure, credential-free access between services

### CloudWatch Monitoring and Logging

The infrastructure includes CloudWatch configuration for monitoring and logging:

#### CloudWatch Log Groups
- Application log group for collecting application logs
- Error log group for collecting error logs
- Both log groups have a 30-day retention period

#### CloudWatch Agent Configuration
- Configured via user data on EC2 instances
- Collects system metrics including:
  - CPU usage (idle, user, system)
  - Memory usage
  - Disk usage
  - Network statistics
- Collects application logs from:
  - Application log file
  - Error log file
- Sends logs to corresponding CloudWatch log groups
- Configured to run as the application user

#### IAM Permissions for CloudWatch
- IAM policy granting permissions for:
  - Publishing CloudWatch metrics
  - Creating and managing log groups and streams
  - Putting log events
  - Working with AWS X-Ray for tracing
  - Using SSM parameters for CloudWatch configuration
- Attached to the EC2 role for seamless integration

### User Data for EC2

EC2 instances use user data script to:
- Configure environment variables for database connection
- Pass S3 bucket information to the application
- Set up CloudWatch agent configuration
- Automate application setup on instance launch
- Configure log directories with appropriate permissions
- Start services including the CloudWatch agent

## Creating Multiple VPCs

Using Terraform workspaces:
```bash
# Create new workspace
terraform workspace new my-vpc-2

# List workspaces
terraform workspace list

# Switch workspaces
terraform workspace select my-vpc-2

# Apply with different configurations
terraform apply -var-file="vpc2.tfvars"
```

## GitHub Actions CI

The workflow performs:
1. Code formatting check
2. Terraform initialization
3. Configuration validation

### Workflow Configuration
Located in `.github/workflows/terraform-ci.yml`

### GitHub Secrets Required
* AWS_ACCESS_KEY_ID
* AWS_SECRET_ACCESS_KEY

## Assignment 07: Load Balancing and Auto Scaling

This assignment enhances the infrastructure with load balancing, auto scaling, and DNS configuration:

### Load Balancer Security Group

A security group for the Application Load Balancer that:
- Allows HTTP traffic (port 80) from anywhere in the world
- Allows HTTPS traffic (port 443) from anywhere in the world
- Permits all outbound traffic

### Updated Application Security Group

Modified security group for EC2 instances that:
- Restricts application port access to only allow traffic from the load balancer security group
- Maintains SSH access for administration
- Follows the principle of least privilege by removing direct internet access

### Launch Template

A launch template for EC2 instances that:
- Uses the same custom AMI as the standalone EC2 instance
- Configures the same IAM instance profile, security groups, and user data
- Allows proper tagging of all resources created by the auto-scaling group
- Enables public IP address association for instances

### Auto Scaling Group

An auto scaling group configuration that:
- Maintains a minimum of 3 and maximum of 5 instances
- Uses the launch template to create new instances
- Spans multiple availability zones for high availability
- Registers instances with the load balancer target group
- Includes proper instance health checks
- Has a cooldown period of 60 seconds between scaling actions

### Auto Scaling Policies

Auto scaling policies that:
- Scale up by 1 instance when average CPU usage exceeds 5%
- Scale down by 1 instance when average CPU usage falls below 3%
- Use CloudWatch alarms to trigger scaling actions based on CPU metrics

### Application Load Balancer

An Application Load Balancer that:
- Distributes traffic across all auto scaling instances
- Listens on HTTP port 80
- Forwards traffic to the application port (8080)
- Uses health checks to determine instance availability
- Is associated with the load balancer security group

### DNS Configuration

Route53 DNS configuration that:
- Creates an alias record for the subdomain (dev.anzalshaikh.me or demo.anzalshaikh.me)
- Points the alias record to the Application Load Balancer
- Makes the application accessible via the subdomain URL
- Uses the correct hosted zone ID for the subdomain

## Usage

1. Clone Repository:
```bash
git clone <repository-url>
cd <repository-name>
```

2. Initialize Terraform:
```bash
terraform init
```

3. Create New VPC:
```bash
# Create new workspace (optional)
terraform workspace new vpc2

# Apply configuration
terraform apply -var-file="dev.tfvars"
```

4. Destroy Infrastructure:
```bash
terraform destroy -var-file="dev.tfvars"
```

## Assignment 08: Key Management Service and SSL Certificates

This assignment enhances the infrastructure with AWS KMS for encryption and secure SSL certificates:

### AWS Key Management Service (KMS)

The infrastructure uses AWS KMS for encrypting sensitive data:

- Separate KMS keys for different resource types:
  - EC2 KMS key for EBS volume encryption
  - RDS KMS key for database encryption
  - S3 KMS key for object encryption
  - Secrets Manager KMS key for database credentials

- Key features:
  - Automated key rotation every 90 days using EventBridge rules
  - Unique key names with timestamp suffixes to prevent naming conflicts
  - Custom key policies for each key type following the principle of least privilege
  - Key aliases for easier identification

### Database Password Management

Database passwords are now stored and retrieved securely:

- Random password generation with URL-safe special characters
- Password stored in AWS Secrets Manager with KMS encryption
- EC2 instances retrieve database credentials at runtime
- User data script fetches credentials from Secrets Manager during instance boot

### SSL Certificate Implementation

Secure communication is implemented using SSL certificates:

- For dev environment:
  - AWS Certificate Manager (ACM) is used to provision certificates
  - Certificates are automatically validated using DNS validation

- For demo environment:
  - SSL certificate purchased from Namecheap
  - Certificate imported into AWS Certificate Manager
  - Load balancer configured to use the imported certificate

#### Importing SSL Certificate from Namecheap to AWS

To import a Namecheap SSL certificate to AWS Certificate Manager:

1. Download the SSL certificate files from Namecheap:
   - Certificate file (certificate.crt)
   - Private key file (private.key)
   - Certificate chain file (ca_bundle.crt)

2. Import the certificate using AWS CLI:
   ```bash
   aws acm import-certificate \
     --certificate fileb://certificate.crt \
     --private-key fileb://private.key \
     --certificate-chain fileb://ca_bundle.crt \
     --region us-east-1 \
     --profile demo

## Author

Mohammed Anzal Shaikh

## License

This project is part of CSYE6225 coursework and follows academic guidelines.