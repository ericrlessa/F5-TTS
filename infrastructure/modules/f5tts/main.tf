terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ================= IAM policy for ECS instances to access SQS and S3
resource "aws_iam_policy" "ecs_sqs_s3_policy" {
  name        = "ecs-sqs-s3-policy-${var.env}"
  description = "Allow ECS instances to receive messages from SQS and read S3 objects"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ],
        Resource = [
          var.sqs_free_podcasts_arn,
          var.sqs_short_podcasts_arn,
          var.sqs_medium_podcasts_arn,
          var.sqs_large_podcasts_arn
        ]
      },
      {
        Effect   = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = var.sqs_result_queue_arn
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ],
        Resource = "arn:aws:s3:::${var.bucket_name}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ],
        "Resource": "*"
      }
    ]
  })
}

# ================= IAM role for EC2 instances (ECS hosts)
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name               = "ecsInstanceRole-f5tts-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_sqs_s3_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = aws_iam_policy.ecs_sqs_s3_policy.arn
}

resource "aws_iam_instance_profile" "ecs_profile" {
  name = "ecsInstanceProfile-${var.env}"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/ecs-f5tts"
  retention_in_days = 1
}

# ================= Launch Template with ECS Optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = var.ecs_ami_ssm_param
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 100  # <- Increase this to the desired size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config
echo ECS_ENABLE_AWSVPC_TRUNKING=true >> /etc/ecs/ecs.config
EOF
  )
}

# ================= ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = var.ecs_cluster_name
}

# ================= Auto Scaling Group that can scale to 0
resource "aws_autoscaling_group" "ecs" {
  name                = "ecs-asg"
  desired_capacity    = 0
  min_size            = 0
  max_size            = 1
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  warm_pool {
    pool_state                  = "Stopped"  # or "Running"
    min_size                    = 1
    max_group_prepared_capacity = 2
    
    instance_reuse_policy {
      reuse_on_scale_in = true
    }
  }

  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "gpu_capacity" {
  name = "gpu-capacity"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
    
    managed_termination_protection = "ENABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "cluster_cp" {
  cluster_name = aws_ecs_cluster.cluster.name 
  
  capacity_providers = [aws_ecs_capacity_provider.gpu_capacity.name]
  
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.gpu_capacity.name
  }
}

# ================= Task Definition
resource "aws_ecs_task_definition" "free_podcast_task" {
  family                   = "free-podcast-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "4096"
  memory                   = "14336"
  
  container_definitions = jsonencode([
    {
      name         = "free-podcast"
      image        = var.f5tts_image
      essential    = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      command      = ["serve"]
      resourceRequirements = [
        {
          type  = "GPU"
          value = "1"
        },
      ]
      environment = [
        {
          name  = "SQS_REC_QUEUE_URL"
          value = var.sqs_free_podcasts_url
        },
        {
          name  = "SQS_SND_QUEUE_URL"
          value = var.sqs_result_queue_url
        },
        {
          name  = "SERVICE_NAME"
          value = var.free_service_ecs
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/free-podcast-container"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

resource "aws_ecs_task_definition" "short_podcast_task" {
  family                   = "short-podcast-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "4096"
  memory                   = "14336"
  
  container_definitions = jsonencode([
    {
      name         = "short-podcast"
      image        = var.f5tts_image
      essential    = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      command      = ["serve"]
      resourceRequirements = [
        {
          type  = "GPU"
          value = "1"
        },
      ]
      environment = [
        {
          name  = "SQS_REC_QUEUE_URL"
          value = var.sqs_short_podcasts_url
        },
        {
          name  = "SQS_SND_QUEUE_URL"
          value = var.sqs_result_queue_url
        }
        ,
        {
          name  = "SERVICE_NAME"
          value = var.short_service_ecs
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/short-podcast-container"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

resource "aws_ecs_task_definition" "medium_podcast_task" {
  family                   = "medium-podcast-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "4096"
  memory                   = "14336"
  
  container_definitions = jsonencode([
    {
      name         = "medium-podcast"
      image        = var.f5tts_image
      essential    = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      command      = ["serve"]
      resourceRequirements = [
        {
          type  = "GPU"
          value = "1"
        },
      ]
      environment = [
        {
          name  = "SQS_REC_QUEUE_URL"
          value = var.sqs_medium_podcasts_url
        },
        {
          name  = "SQS_SND_QUEUE_URL"
          value = var.sqs_result_queue_url
        },
        {
          name  = "SERVICE_NAME"
          value = var.medium_service_ecs
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/medium-podcast-container"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

resource "aws_ecs_task_definition" "large_podcast_task" {
  family                   = "large-podcast-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "4096"
  memory                   = "14336"
  
  container_definitions = jsonencode([
    {
      name         = "large-podcast"
      image        = var.f5tts_image
      essential    = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      command      = ["serve"]
      resourceRequirements = [
        {
          type  = "GPU"
          value = "1"
        },
      ]
      environment = [
        {
          name  = "SQS_REC_QUEUE_URL"
          value = var.sqs_large_podcasts_url
        },
        {
          name  = "SQS_SND_QUEUE_URL"
          value = var.sqs_result_queue_url
        },
        {
          name  = "SERVICE_NAME"
          value = var.large_service_ecs
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/large-podcast-container"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

# ================= ECS Service
resource "aws_ecs_service" "free_service_ecs" {
  name            = var.free_service_ecs
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.free_podcast_task.arn
  desired_count   = 0
  launch_type     = "EC2"
  network_configuration {
    subnets         = var.private_subnet_ids
    assign_public_ip = false
    security_groups = [aws_security_group.ecs_tasks_sg.id] 
  }
}

resource "aws_ecs_service" "short_service_ecs" {
  name            = var.short_service_ecs
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.short_podcast_task.arn
  desired_count   = 0
  launch_type     = "EC2"
  network_configuration {
    subnets         = var.private_subnet_ids
    assign_public_ip = false
    security_groups = [aws_security_group.ecs_tasks_sg.id] 
  }
}

resource "aws_ecs_service" "medium_service_ecs" {
  name            = var.medium_service_ecs
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.medium_podcast_task.arn
  desired_count   = 0
  launch_type     = "EC2"
  network_configuration {
    subnets         = var.private_subnet_ids
    assign_public_ip = false
    security_groups = [aws_security_group.ecs_tasks_sg.id] 
  }
}

resource "aws_ecs_service" "large_service_ecs" {
  name            = var.large_service_ecs
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.large_podcast_task.arn
  desired_count   = 0
  launch_type     = "EC2"
  network_configuration {
    subnets         = var.private_subnet_ids
    assign_public_ip = false
    security_groups = [aws_security_group.ecs_tasks_sg.id] 
  }
}

# ================= Security Group for ECS tasks
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP inbound to port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # adjust this to restrict access if needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-tasks-sg"
  }
}