terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# IAM Role for ECS instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile-${var.env}"
  role = aws_iam_role.ecs_instance_role.name
}

# IAM Role for AWS Batch Service
resource "aws_iam_role" "aws_batch_service_role" {
  name = "aws_batch_service_role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "batch.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# Compute Environment
resource "aws_batch_compute_environment" "batch_compute_env" {
  compute_environment_name = "batch-compute-env-${var.env}"
  service_role             = aws_iam_role.aws_batch_service_role.arn
  type                     = "MANAGED"

  compute_resources {
    type               = "EC2"
    allocation_strategy = "BEST_FIT"

    instance_role    = aws_iam_instance_profile.ecs_instance_profile.arn
    instance_type    = ["g5.xlarge"]
    max_vcpus        = 80
    min_vcpus        = 0
    desired_vcpus    = 0

    subnets           = var.private_subnet_ids
    
    # Optional: Add tags for better resource management
    tags = {
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.aws_batch_service_role]
}

# Job Queue
resource "aws_batch_job_queue" "batch_queue" {
  name     = "batch-job-queue-${var.env}"
  state    = "ENABLED"
  priority = 1
  
  compute_environment_order {
    compute_environment = aws_batch_compute_environment.batch_compute_env.arn
    order               = 1
  }
}

# IAM Role for Batch Jobs
resource "aws_iam_role" "batch_job_role" {
  name = "batch_job_role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "batch_logs" {
  name              = "/aws/batch/podcast-${var.env}"
  retention_in_days = 3
  
  tags = {
    Environment = var.env
  }
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_role_policy" "batch_logs_policy" {
  name = "batch-logs-policy-${var.env}"
  role = aws_iam_role.batch_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        # More specific resource restriction (optional but recommended)
        Resource = [
          "${aws_cloudwatch_log_group.batch_logs.arn}:*",
          "${aws_cloudwatch_log_group.batch_logs.arn}:*:*"
        ]
      }
    ]
  })
}

# Attach ECS Task Execution Role policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Job Definition
resource "aws_batch_job_definition" "simple_job" {
  name = "simple-batch-job-${var.env}"
  type = "container"

  platform_capabilities = ["EC2"]

  container_properties = jsonencode({
    image = var.f5tts_image
    command = [
      "serve"
    ]
    resourceRequirements = [
      {
        type  = "VCPU"
        value = "4"
      },
      {
        type  = "MEMORY"
        value = "14336"  # 14GB
      }
    ]
    # Log configuration for CloudWatch
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.batch_logs.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "batch-${var.env}"
      }
    }
    jobRoleArn       = aws_iam_role.batch_job_role.arn
    executionRoleArn = aws_iam_role.batch_job_role.arn
  })

  retry_strategy {
    attempts = 3
  }

  timeout {
    attempt_duration_seconds = 600
  }

  depends_on = [
    aws_iam_role_policy.batch_logs_policy,
    aws_iam_role_policy_attachment.ecs_task_execution
  ]
}