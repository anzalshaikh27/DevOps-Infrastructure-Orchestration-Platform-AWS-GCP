# WebApp
A cloud-native health check API built with Node.js and PostgreSQL for monitoring application and database health.

## Assignment 1: RESTful Health Check API
### Project Structure
```
webapp_fork/
├── config/
│   └── database.js         # Database configuration
├── models/
│   └── healthCheck.js      # Health check database model
├── routes/
│   └── health.js          # Health check route handlers
├── .env                   # Environment variables
├── .gitignore            # Git ignore file
├── app.js                # Application entry point
└── package.json          # Project dependencies
```
### Local Development Setup
1. Install dependencies:
   ```bash
   npm install
   ```
2. Configure environment:
   ```
   DATABASE_URL=postgres://username:password@localhost:5432/healthcheck_db
   PORT=8080
   ```
3. Start application:
   ```bash
   npm start
   ```
### API Endpoint: GET /healthz
#### Response Codes
- `200 OK`: Health check successful
- `400 Bad Request`: Request contains payload
- `405 Method Not Allowed`: Non-GET methods
- `503 Service Unavailable`: Database failure
#### Headers
```
Cache-Control: no-cache, no-store, must-revalidate;
Pragma: no-cache
X-Content-Type-Options: nosniff
```

## Assignment 2: Shell Script Automation
### Prerequisites
- Ubuntu 24.04 LTS Droplet on DigitalOcean
- SSH key access to the droplet
- PostgreSQL database
- Node.js environment
### Deployment Scripts
#### 1. Copy Script (Local Machine)
The `copy_to_droplet.sh` script transfers necessary files to the droplet:
Run:
```bash
chmod +x copy_to_droplet.sh
./copy_to_droplet.sh
```
#### 2. Setup Script (On Droplet)
The `setup.sh` script automates:
1. System package updates
2. PostgreSQL installation
3. Database creation from .env
4. Application user/group setup
5. Application deployment
6. PM2 process management setup
Run on droplet:
```bash
cd /root/webapp-setup
./setup.sh
```
### Verification
Test the deployment:
```bash
# Check database
sudo -u postgres psql -l
```

## Assignment 3: Infrastructure as Code with Terraform
### AWS Networking Infrastructure
The project uses Terraform to automatically provision AWS networking resources:

#### Resources Created
- Virtual Private Cloud (VPC)
- 3 Public Subnets across different AZs
- 3 Private Subnets across different AZs
- Internet Gateway
- Route Tables (public and private)
- Route Table Associations

#### Directory Structure
```
terraform/
├── provider.tf          # AWS provider configuration
├── variables.tf         # Variable declarations
├── vpc.tf               # VPC resource
├── subnets.tf           # Public and private subnets
├── route_tables.tf      # Route tables configuration
├── dev.tfvars           # Variables for dev environment
└── demo.tfvars          # Variables for demo environment
```

#### Usage
```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan -var-file="dev.tfvars"

# Apply changes
terraform apply -var-file="dev.tfvars"

# Create multiple VPCs using workspaces
terraform workspace new vpc2
terraform apply -var-file="demo.tfvars"
```

### GitHub Actions CI
The project includes GitHub Actions workflow for CI/CD:
- Code formatting check (`terraform fmt`)
- Terraform validation (`terraform validate`)
- Branch protection rules to prevent merging failed PRs

## Assignment 4: AMI Creation and EC2 Deployment
### Packer AMI Configuration
The project uses HashiCorp Packer to create custom AMIs for the application:

#### Features
- Creates custom AMIs for AWS
- Pre-installs application dependencies
- Configures PostgreSQL database
- Sets up systemd service
- Shares AMIs across AWS accounts

#### Directory Structure
```
packer/
├── ami.pkr.hcl         # Packer configuration file
├── ami-setup.sh        # Provisioning script
├── systemd.service     # Systemd service definition
└── webapp.zip          # Application files
```

### Additional Terraform Resources
Additional Terraform configurations for EC2 deployment:

#### Resources Created
- Application Security Group (ports 22, 80, 443, and app port)
- EC2 Instance with custom AMI
- 25GB GP2 root volume
- Proper security group attachment

#### Configuration
```hcl
# Security group configuration
resource "aws_security_group" "application" {
  name        = "${var.vpc_name}-application-sg"
  description = "Security group for web applications"
  vpc_id      = aws_vpc.main.id

  # Ingress rules for SSH, HTTP, HTTPS, and app port
  # Egress rules for outbound traffic
}

# EC2 instance configuration
resource "aws_instance" "app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[0].id
  
  vpc_security_group_ids = [aws_security_group.application.id]
  
  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }
}
```

#### AMI Sharing Between Accounts
To share AMIs between dev and demo accounts:
```hcl
# In Packer configuration
variable "share_account_id" {
  type    = string
  default = env("SHARE_ACCOUNT_ID")
}

source "amazon-ebs" "aws_image" {
  # AMI configuration
  ami_users     = [var.share_account_id]
  snapshot_users = [var.share_account_id]
}
```

Usage with environment variables:
```bash
export SHARE_ACCOUNT_ID="869935075529"
packer build .
```

## Assignment05: New API Endpoints: File Management

### POST /v1/file
Uploads a file to S3 and stores metadata in the database.
#### Request
- **Content-Type:** `multipart/form-data`
- **Body:** `file` (required, file upload)

#### Response Codes
- `201 Created`: File uploaded successfully
- `400 Bad Request`: No file provided
- `500 Internal Server Error`: Failed to upload

#### Example Response
```json
{
  "id": "f1234567-89ab-cdef-1234-56789abcdef0",
  "file_name": "example.jpg",
  "file_type": "image/jpeg",
  "size": 102400,
  "created_date": "2025-03-19T14:21:00Z"
}
```

### GET /v1/file/{id}
Retrieves file metadata by file ID.
#### Response Codes
- `200 OK`: Returns file metadata
- `404 Not Found`: File ID not found
- `500 Internal Server Error`: Failed to retrieve

#### Example Response
```json
{
  "id": "f1234567-89ab-cdef-1234-56789abcdef0",
  "file_name": "example.jpg",
  "s3_object_key": "f1234567-89ab-cdef-1234-56789abcdef0-example.jpg",
  "size": 102400,
  "file_type": "image/jpeg",
  "created_date": "2025-03-19T14:21:00Z",
  "s3_path": "s3://your-s3-bucket-name/f1234567-89ab-cdef-1234-56789abcdef0-example.jpg"
}
```

### DELETE /v1/file/{id}
Deletes a file from S3 and removes its metadata from the database.
#### Response Codes
- `204 No Content`: File deleted
- `404 Not Found`: File ID not found
- `500 Internal Server Error`: Failed to delete

## Assignment 06: Logging and Metrics

### Enhanced API Routes
All API routes have been enhanced with improved error handling and comprehensive logging:

- Detailed error messages with proper status codes
- Consistent error response format
- UUID validation for file operations
- Proper handling of edge cases (e.g., multiple file uploads)

### Application Logging
The application now includes a robust logging system:

- Structured JSON logs for better parsing and analysis
- Separate application and error logs
- All logs forwarded to CloudWatch for centralized monitoring
- Log directory configuration to support both local development and production
- Meaningful log messages with proper grammar and detailed context

### Custom Metrics Collection
The following metrics are now collected and sent to CloudWatch:

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

### CloudWatch Integration
The application is fully integrated with AWS CloudWatch:

- CloudWatch agent installed and configured via user data
- Automatic log forwarding to CloudWatch logs
- Custom metrics published to CloudWatch Metrics
- StatsD metrics collection for detailed performance monitoring
- Test environment detection to prevent errors during testing

### Project Structure Updates
New configuration files have been added:

```
webapp_fork/
├── config/
│   ├── database.js      # Database configuration
│   ├── logger.js        # Logging configuration
│   └── metrics.js       # Metrics collection
├── models/
│   ├── healthCheck.js   # Health check model
│   └── file.js          # File metadata model
├── routes/
│   ├── health.js        # Health check routes
│   └── file.js          # File management routes
```

### Environment Setup
Additional environment variables for metrics and logging:

```
DATABASE_URL=postgres://username:password@localhost:5432/healthcheck_db
PORT=8080
S3_BUCKET=your-s3-bucket-name
LOG_DIR=/var/log/webapp
AWS_REGION=us-east-1
```

## Database Schema
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

## Assignment 08: CI/CD Enhancements and Application Security

### CI/CD for Web Application - Enhanced Workflow

The CI/CD pipeline has been enhanced with automated deployment capabilities:

#### Pull Request Merged Workflow
When a pull request is merged to the main branch, the GitHub Actions workflow:

1. Runs unit tests to verify application functionality
2. Validates the Packer template for AMI creation
3. Builds the application artifact and packages it for deployment
4. Builds a new AMI in the DEV AWS account with:
   - Upgraded OS packages
   - Dependencies installation (Node.js, etc.)
   - Application artifacts and configuration
   - Automatic startup configuration
   - AMI sharing with the DEMO AWS account

5. Switches AWS credentials to the DEMO account
6. Creates a new Launch Template version with the latest AMI
7. Triggers an instance refresh in the Auto Scaling Group
8. Waits for the instance refresh to complete before finishing

#### Continuous Deployment Process
The workflow ensures zero-downtime deployments by:
- Maintaining minimum healthy instances during refresh (90%)
- Setting appropriate instance warmup time (300 seconds)
- Making the workflow status reflect the instance refresh status
- Proper error handling and retry mechanisms

### New API Endpoint

A new `/cicd` endpoint has been added to the application that:
- Functions identically to the `/healthz` endpoint
- Records database access timestamps
- Includes the same security headers and validation
- Follows the same error handling patterns

This endpoint serves as a verification point for successful deployments.

### Security Enhancements

To improve application security:

#### SSL/TLS Implementation
- HTTPS endpoints secured with SSL certificates
- Dev environment uses AWS Certificate Manager
- Demo environment uses imported third-party certificates from Namecheap

#### Access Control
- Direct EC2 instance access is restricted
- All traffic routed through the load balancer
- Security groups configured to minimize attack surface

#### Data Security
- Database credentials stored in AWS Secrets Manager
- Credentials retrieved at runtime using IAM roles
- Environment variables stored securely with proper permissions

### GitHub Actions Workflow
The CI/CD workflow is configured in `.github/workflows/build-image.yml` and includes:

```yaml
# Key workflow steps
- name: "Run Integration Tests"
  # Test application functionality
- name: "Build Custom Images with Packer"
  # Create and share AMI
- name: "Configure AWS Credentials for DEMO account"
  # Switch to demo account credentials
- name: "Start Instance Refresh"
  # Trigger auto scaling group refresh
- name: "Wait for Instance Refresh to Complete"
  # Ensure deployment completes successfully
```

This implementation provides a complete CI/CD pipeline that automatically deploys application changes to both development and production environments upon merging pull requests.

## Author
Mohammed Anzal Shaikh

## License
This project is part of CSYE6225 coursework and follows academic guidelines.