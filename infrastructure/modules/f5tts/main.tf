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
    security_group_ids = [aws_security_group.batch_compute_sg.id] 

    
    launch_template {
      launch_template_name = aws_launch_template.batch_launch_template.name
    }

    # Optional: Add tags for better resource management
    tags = {
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.aws_batch_service_role]
}

resource "aws_launch_template" "batch_launch_template" {
  name = "batch-launch-template-${var.env}"

  block_device_mappings {
    device_name = "/dev/xvda"  # Root volume

    ebs {
      volume_size = 100  # GB - increase as needed
      volume_type = "gp3"
      delete_on_termination = true
    }
  }

  # Optional: Specify GPU-optimized AMI
  image_id = data.aws_ami.ecs_gpu_optimized.id
}

data "aws_ami" "ecs_gpu_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-gpu-hvm-2.0.*-x86_64-ebs"]
  }
}

resource "aws_security_group" "batch_compute_sg" {
  name        = "batch-compute-sg-${var.env}"
  description = "Security group for AWS Batch compute environment in private subnet"
  vpc_id      = var.vpc_id

  # Outbound internet access for NAT gateway (required for ECR, Docker Hub, etc.)
  egress {
    description = "Outbound internet access via NAT gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
      },
      {
        type  = "GPU"
        value = "1"
      }
    ]
    environment = [
      {
        name  = "SQS_SND_QUEUE_URL"
        value = var.sqs_result_queue_url
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

# S3 Read Policy for the job role
resource "aws_iam_policy" "s3_read_access" {
  name        = "s3-read-access-${var.env}"
  description = "S3 read access for Batch jobs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "batch_job_s3_access" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.s3_read_access.arn
}

# IAM Policy for SQS access
resource "aws_iam_policy" "sqs_write_access" {
  name        = "sqs-write-access-${var.env}"
  description = "SQS write access for Batch jobs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:SendMessageBatch",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          var.sqs_result_queue_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "batch_job_sqs_access" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.sqs_write_access.arn
}