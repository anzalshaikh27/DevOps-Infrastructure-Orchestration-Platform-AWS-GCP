# DevOps Infrastructure Orchestration Platform - AWS and GCP

A comprehensive platform for automating cloud infrastructure across AWS and GCP using Terraform and GitHub Actions. Features VPC architecture, auto-scaling, load balancing, RDS PostgreSQL, S3 storage, custom AMIs with Packer, zero-downtime deployments, KMS encryption, and CloudWatch monitoring.

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

## Cloud-Native Web Application

This project includes a cloud-native health check and file management API built with Node.js and PostgreSQL:

### API Endpoints

#### Health Monitoring
- **GET /healthz**: Application and database health check
- **GET /cicd**: Deployment verification endpoint

#### File Management
- **POST /v1/file**: Upload files to S3 with metadata tracking
- **GET /v1/file/{id}**: Retrieve file metadata
- **DELETE /v1/file/{id}**: Remove files from S3 and database

### Project Structure
```
webapp/
├── config/
│   ├── database.js         # Database configuration
│   ├── logger.js           # Logging configuration
│   └── metrics.js          # Metrics collection
├── models/
│   ├── healthCheck.js      # Health check database model
│   └── file.js             # File metadata model
├── routes/
│   ├── health.js           # Health check routes
│   └── file.js             # File management routes
├── .env                    # Environment variables
├── app.js                  # Application entry point
└── package.json            # Project dependencies
```

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
├── terraform/
│   ├── provider.tf            # AWS provider configuration
│   ├── variables.tf           # Variable declarations
│   ├── vpc.tf                 # VPC resource
│   ├── cloudwatch.tf          # Cloudwatch log groups and metrics configuration
│   ├── subnets.tf             # Public and private subnets
│   ├── route_tables.tf        # Route tables configuration
│   ├── security_groups.tf     # Security groups for application, load balancer, and database
│   ├── ec2.tf                 # EC2 instance configuration with user data
│   ├── launch_template.tf     # Launch template for auto scaling
│   ├── auto_scaling.tf        # Auto scaling group and policies
│   ├── load_balancer.tf       # Application load balancer configuration
│   ├── route53.tf             # DNS configuration for subdomains
│   ├── rds.tf                 # RDS instance configuration
│   ├── s3.tf                  # S3 bucket configuration
│   ├── iam.tf                 # IAM roles and policies
│   ├── dev.tfvars             # Variables for dev environment
│   └── demo.tfvars            # Variables for demo environment
├── packer/
│   ├── ami.pkr.hcl            # Packer configuration file
│   ├── ami-setup.sh           # Provisioning script
│   ├── systemd.service        # Systemd service definition
│   └── webapp.zip             # Application files
├── webapp/                    # Application source code
│   └── ...                    # Application files structure as shown above
└── .github/workflows/         # GitHub Actions workflows
    ├── terraform-ci.yml       # Terraform validation workflow
    └── build-image.yml        # AMI building and deployment workflow
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

## Security Configuration

### Application Security Group

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

### Database Security Group

A security group specifically for RDS instances that:
- Allows PostgreSQL traffic (port 5432) only from the application security group
- Restricts direct internet access to the database
- Limits outbound traffic to the VPC CIDR block following least privilege principle

## Database Configuration

### RDS PostgreSQL Database

A PostgreSQL database instance that:
- Uses a custom parameter group instead of default
- Is deployed in private subnets for security
- Has encryption enabled for data at rest
- Is accessible only through the application servers

### Database Schema
```sql
CREATE TABLE health_check (
    check_id SERIAL PRIMARY KEY,
    datetime TIMESTAMP NOT NULL
);

CREATE TABLE file (
    id UUID PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    s3_object_key VARCHAR(255) NOT NULL,
    size INTEGER NOT NULL,
    file_type VARCHAR(100) NOT NULL,
    created_date TIMESTAMP NOT NULL DEFAULT NOW()
);
```

## Storage Configuration

### S3 Bucket Configuration

A private S3 bucket that:
- Uses UUID naming for uniqueness
- Has default encryption enabled
- Implements a lifecycle policy to transition objects to STANDARD_IA after 30 days
- Blocks all public access

## Identity and Access Management

### IAM Role Configuration

IAM roles and policies that:
- Allow EC2 instances to access the S3 bucket
- Follow the principle of least privilege
- Are attached to EC2 instances via instance profiles
- Enable secure, credential-free access between services

## Monitoring and Logging

### CloudWatch Configuration

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

### Custom Metrics Collection
The application collects and sends the following metrics to CloudWatch:

#### API Usage Metrics
- **Count**: Number of times each API endpoint is called
- **Duration**: Time taken (in milliseconds) for each API call
- **Status**: Success vs error outcomes for each endpoint

#### S3 Operation Metrics
- **Duration**: Time taken for S3 operations (upload, retrieval, deletion)
- **Count**: Number of S3 operations performed

#### Database Performance Metrics
- **Query Duration**: Time taken for database operations
- **Database Connectivity**: Health check database connectivity status

## Deployment and Scaling

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

## Key Management and Encryption

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

Database passwords are stored and retrieved securely:

- Random password generation with URL-safe special characters
- Password stored in AWS Secrets Manager with KMS encryption
- EC2 instances retrieve database credentials at runtime
- User data script fetches credentials from Secrets Manager during instance boot

## SSL Certificate Management

Secure communication is implemented using SSL certificates:

- For dev environment:
  - AWS Certificate Manager (ACM) is used to provision certificates
  - Certificates are automatically validated using DNS validation

- For demo environment:
  - SSL certificate purchased from Namecheap
  - Certificate imported into AWS Certificate Manager
  - Load balancer configured to use the imported certificate

### Importing SSL Certificate from Namecheap to AWS

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
   ```

## CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline uses GitHub Actions for automated deployments:

#### Pull Request Workflow
- Runs Terraform validation
- Checks Terraform formatting
- Ensures code quality before merging

#### Build and Deploy Workflow
When a pull request is merged to the main branch, the workflow:

1. Runs unit tests for the application
2. Validates the Packer template
3. Builds the application artifact
4. Creates a new AMI in the DEV AWS account
5. Shares the AMI with the DEMO account
6. Updates the Launch Template with the new AMI
7. Triggers an instance refresh in the Auto Scaling Group
8. Ensures zero-downtime deployment

## Managing Multiple Environments

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

## Local Development Setup

1. Install dependencies:
   ```bash
   npm install
   ```
2. Configure environment:
   ```
   DATABASE_URL=postgres://username:password@localhost:5432/healthcheck_db
   PORT=8080
   S3_BUCKET=your-s3-bucket-name
   LOG_DIR=/var/log/webapp
   AWS_REGION=us-east-1
   ```
3. Start application:
   ```bash
   npm start
   ```

## Usage

1. Clone Repository:
```bash
git clone <repository-url>
cd <repository-name>
```

2. Initialize Terraform:
```bash
cd terraform
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

## Author

Mohammed Anzal Shaikh

## License

This project is part of CSYE6225 coursework and follows academic guidelines.