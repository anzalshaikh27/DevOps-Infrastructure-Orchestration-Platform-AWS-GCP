resource "aws_launch_template" "app_launch_template" {
  name          = "csye6225_launch_template"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_s3_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.application.id]
  }

  user_data = base64encode(local.user_data)

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 25
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2_key.arn
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.vpc_name}-app-server"
      Environment = var.environment
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.vpc_name}-app-volume"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.vpc_name}-launch-template"
    Environment = var.environment
  }
}