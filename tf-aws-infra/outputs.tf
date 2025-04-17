output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app_asg.name
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app_load_balancer.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app_target_group.arn
}

output "security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.application.id
}

output "load_balancer_security_group_id" {
  description = "ID of the load balancer security group"
  value       = aws_security_group.load_balancer.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.arn
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2"
  value       = aws_iam_role.ec2_s3_access_role.arn
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.postgres_db.endpoint
}

output "rds_db_name" {
  description = "The database name"
  value       = aws_db_instance.postgres_db.db_name
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.app_launch_template.id
}

output "route53_domain" {
  description = "Domain name configured in Route53"
  value       = aws_route53_record.subdomain.name
}