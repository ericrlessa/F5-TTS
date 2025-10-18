# IAM Role for Image Builder INSTANCE (EC2 that builds AMI)
resource "aws_iam_role" "image_builder_role" {
  name = "image-builder-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# IAM Policies for INSTANCE role - ONLY what the INSTANCE needs
resource "aws_iam_role_policy_attachment" "image_builder_ssm_core" {
  role       = aws_iam_role.image_builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"  # For SSM agent
}

resource "aws_iam_role_policy_attachment" "image_builder_ec2" {
  role       = aws_iam_role.image_builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"  # For EC2 operations
}

resource "aws_iam_role_policy_attachment" "image_builder_s3" {
  role       = aws_iam_role.image_builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"  # For logs
}

resource "aws_iam_role_policy_attachment" "image_builder_ecr" {
  role       = aws_iam_role.image_builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"  # For Docker pulls
}

# Image Builder Service Policy (required for the instance)
resource "aws_iam_role_policy_attachment" "image_builder_service" {
  role       = aws_iam_role.image_builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_instance_profile" "image_builder_profile" {
  name = "image-builder-profile-${var.env}"
  role = aws_iam_role.image_builder_role.name
}

# Security Group for Image Builder instances
resource "aws_security_group" "image_builder" {
  name        = "image-builder-sg-${var.env}"
  description = "Security group for Image Builder instances"
  vpc_id      = var.vpc_id

  egress {
    description = "SSM and outbound access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "General outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.env
  }
}

resource "aws_imagebuilder_component" "pull_container" {
  name     = "pull-container-${var.env}"
  platform = "Linux"
  version  = "1.0.2"  # Increment version

  data = yamlencode({
    phases = [{
      name = "build"
      steps = [        
        {
          name   = "ECRLogin"
          action = "ExecuteBash"
          inputs = {
            commands = [
              "set -e",
              "echo 'Logging into ECR using IAM role...'",
              "AWS_ECR_REGISTRY='${split("/", var.f5tts_image)[0]}'",
              "echo \"ECR Registry: $AWS_ECR_REGISTRY\"",
              # Install ECR credential helper if not present
              "if ! command -v docker-credential-ecr-login &> /dev/null; then",
              "  echo 'Installing ECR credential helper...'",
              "  yum install -y -q amazon-ecr-credential-helper",
              "fi",
              # Configure Docker to use ECR credential helper
              "mkdir -p /root/.docker",
              "cat > /root/.docker/config.json << EOF",
              "{",
              "  \"credHelpers\": {",
              "    \"$AWS_ECR_REGISTRY\": \"ecr-login\"",
              "  }",
              "}",
              "EOF",
              "echo 'ECR configuration completed'"
            ]
          }
        },
        {
          name   = "PullContainer"
          action = "ExecuteBash"
          inputs = {
            commands = [
              "set -e",
              "echo 'Pulling container image...'",
              "echo \"Image: ${var.f5tts_image}\"",
              "docker pull ${var.f5tts_image}",
              "echo 'Container pulled successfully'",
              "docker images ${var.f5tts_image}"
            ]
          }
        }
      ]
    }]
    schemaVersion = "1.0"
  })
}

# Image Recipe
resource "aws_imagebuilder_image_recipe" "batch_ami_recipe" {
  name         = "batch-ami-recipe-${var.env}"
  version      = "1.0.0"
  parent_image = var.base_ami_id

  component {
    component_arn = aws_imagebuilder_component.pull_container.arn
  }

  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tags = {
    Environment = var.env
  }
}

# Infrastructure Configuration
resource "aws_imagebuilder_infrastructure_configuration" "batch_config" {
  name                          = "batch-infra-config-${var.env}"
  description                   = "Infrastructure for Batch AMI builds"
  instance_profile_name         = aws_iam_instance_profile.image_builder_profile.name
  instance_types                = ["m5.large", "m5.xlarge"]
  terminate_instance_on_failure = true

  subnet_id          = var.public_subnet_ids[0]
  security_group_ids = [aws_security_group.image_builder.id]

  logging {
    s3_logs {
      s3_bucket_name = var.image_builder_logs_bucket
      s3_key_prefix  = "image-builder/${var.env}"
    }
  }

  tags = {
    Environment = var.env
  }
}

# Image Pipeline (Manual Trigger)
resource "aws_imagebuilder_image_pipeline" "batch_pipeline" {
  name        = "batch-pipeline-${var.env}"
  description = "Pipeline for Batch AMI with pre-pulled containers"

  image_recipe_arn                 = aws_imagebuilder_image_recipe.batch_ami_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.batch_config.arn

  # Manual triggers only
  schedule {
    schedule_expression = "cron(0 0 1 1 ? 2025)"
    pipeline_execution_start_condition = "EXPRESSION_MATCH_ONLY"
  }

  tags = {
    Environment = var.env
  }
}

# Manual Image Creation Resource
resource "aws_imagebuilder_image" "batch_ami" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.batch_ami_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.batch_config.arn

}