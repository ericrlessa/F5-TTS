terraform {
  required_providers {
    aws = { source="hashicorp/aws" version="~>5.0" }
  }
}

provider "aws" {
  region = var.region
}

variable "region" { 
  type=string 
}

variable "sqs_queue_name" { 
  type=string 
}

variable "ecs_instance_type" { 
  type=string 
}

variable "ecs_cluster_name" { 
  type=string 
}

variable "ecs_ami_ssm_param" {
  type = string
}

# ✅ Get existing SQS queue
data "aws_sqs_queue" "queue" {
  name = var.sqs_queue_name
}

# ================= ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = var.ecs_cluster_name
}

# ================= IAM role for EC2
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals = [{ type="Service" , identifiers=["ec2.amazonaws.com"] }]
  }
}
resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# ================= Launch Template with ECS Optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = var.ecs_ami_ssm_param
}
resource "aws_launch_template" "ecs" {
  name_prefix = "ecs-"
  image_id = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ecs_instance_type
  iam_instance_profile { name = aws_iam_instance_profile.ecs_profile.name }
  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config
EOF
  )
}

resource "aws_iam_instance_profile" "ecs_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

# ================= Auto Scaling Group that can scale to 0
resource "aws_autoscaling_group" "ecs" {
  name = "ecs-asg"
  desired_capacity = 0
  min_size = 0
  max_size = 1
  launch_template {
    id = aws_launch_template.ecs.id
    version = "$Latest"
  }
  tag {
    key = "Name"
    value = "ecs-instance"
    propagate_at_launch = true
  }
  vpc_zone_identifier = data.aws_subnet_ids.default.ids
}

# Fetch default subnet IDs
data "aws_vpc" "default" { default = true }
data "aws_subnet_ids" "default" { vpc_id = data.aws_vpc.default.id }

# ================= CloudWatch Metrics & Policies
data "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name = "sqs-scale-up"
}

resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_name = "sqs-scale-up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 1
  threshold = 0
  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace = "AWS/SQS"
  dimensions = { QueueName = data.aws_sqs_queue.queue.name }
  statistic = "Sum"
  period = 60
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_name = "sqs-scale-down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = 5
  threshold = 0
  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace = "AWS/SQS"
  dimensions = { QueueName = data.aws_sqs_queue.queue.name }
  statistic = "Sum"
  period = 60
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

resource "aws_autoscaling_policy" "scale_up" {
  name = "scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = 1
  cooldown = 120
  policy_type = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name = "scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = -1
  cooldown = 300
  policy_type = "SimpleScaling"
}

# ================= Task Definition
resource "aws_ecs_task_definition" "task" {
  family = "voice-clone-task"
  network_mode = "bridge"
  requires_compatibilities = ["EC2"]
  cpu = "512"
  memory = "1024"

  container_definitions = jsonencode([
    {
      name = "f5tts"
      image = var.f5tts_image
      essential = true
      portMappings = [{ containerPort = 80, hostPort = 80 }]
    },
    {
      name = "sqs-listener"
      image = var.sqs_listener_image
      essential = true
      dependsOn = [{ containerName = "f5tts", condition = "HEALTHY" }]
    }
  ])
}

# ================= ECS Service
resource "aws_ecs_service" "service" {
  name = "voice-clone-service"
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count = 1
  launch_type = "EC2"
}

# ✅ Outputs
output "ecs_cluster_name" { value = aws_ecs_cluster.cluster.name }
output "asg_name" { value = aws_autoscaling_group.ecs.name }