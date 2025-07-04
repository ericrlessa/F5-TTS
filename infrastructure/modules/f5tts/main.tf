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
  name        = "ecs_sqs_s3_policy"
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
        Resource = var.sqs_queue_arn
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ],
        Resource = "arn:aws:s3:::${var.bucket_name}/*"
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
  name               = "ecsInstanceRole-f5tts"
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
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/voice-clone"
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

  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }
}

# ================= CloudWatch Metrics & Policies for autoscaling
resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_name          = "sqs-scale-up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  dimensions          = { QueueName = var.sqs_queue_name }
  statistic           = "Sum"
  period              = 60
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_name          = "sqs-scale-down-math"
  evaluation_periods  = 5
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id = "m1"
    metric {
      namespace  = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      period     = 60
      stat       = "Sum"
      dimensions = {
        QueueName = var.sqs_queue_name
      }
    }
    return_data = false
  }

  metric_query {
    id = "m2"
    metric {
      namespace  = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      period     = 60
      stat       = "Sum"
      dimensions = {
        QueueName = var.sqs_queue_name
      }
    }
    return_data = false
  }

  metric_query {
    id          = "e1"
    expression  = "IF(m1 <= 0 && m2 <= 0, 1, 0)"
    label       = "BothVisibleAndInflightZero"
    return_data = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                  = "scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type       = "ChangeInCapacity"
  scaling_adjustment    = 1
  cooldown              = 120
  policy_type           = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                  = "scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type       = "ChangeInCapacity"
  scaling_adjustment    = -1
  cooldown              = 300
  policy_type           = "SimpleScaling"
}

# ================= Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "voice-clone-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "4096"
  memory                   = "14336"
  
  container_definitions = jsonencode([
    {
      name         = "f5tts"
      image        = var.f5tts_image
      essential    = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      command      = ["serve"]
      resourceRequirements = [
        {
          type  = "GPU"
          value = "1"
        }
      ]
      environment = [
        {
          name  = "MODEL_SERVER_TIMEOUT"
          value = 7200
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/voice-clone"
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
    },
    {
      name      = "sqs-listener"
      image     = var.sqs_listener_image
      essential = true
      dependsOn = [{ containerName = "f5tts", condition = "HEALTHY" }]
      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "ENDPOINT_URL"
          value = "http://localhost:8080/invocations"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/voice-clone"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ================= ECS Service
resource "aws_ecs_service" "service" {
  name            = "voice-clone-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
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