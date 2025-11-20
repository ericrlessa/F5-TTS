provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "GeniusPod"
    }
  }
}

terraform {
  backend "s3" {}
}

module "vpc" {
  source = "./modules/vpc"
  region = var.region
}

module "f5tts" {
  source = "./modules/f5tts"
  region = var.region
  
  sqs_result_queue_url = module.f5tts_result_queue.sqs_queue_result_url
  sqs_result_queue_arn = module.f5tts_result_queue.sqs_queue_result_arn

  ecs_instance_type = var.ecs_instance_type
  f5tts_image = local.f5tts_image
  bucket_name = local.bucket_name
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  job_definition = local.job_definition

  ami_id = module.batch_image_builder.custom_ami_id
}

module "f5tts_result_queue" {
  source = "./modules/f5tts-result-queue"
  sqs_queue_name = var.sqs_queue_name
}

module "f5tts_result_processing" {
  source = "./modules/f5tts-result-processing"
  processing_result_function_name = "${var.processing_result_function_name}-${terraform.workspace}"
  processing_result_handler_image = local.f5tts_result_processing_image
  supabase_url = local.supabase_url
  supabase_service_key = local.supabase_service_key
  sqs_queue_arn = module.f5tts_result_queue.sqs_queue_result_arn
}

module "podcast_episodes" {
  source = "./modules/podcast-episodes"
  bucket_name = local.bucket_name
  podcast_episodes_image = local.podcast_episodes_image
  podcast_episodes_function_name = "${var.podcast_episodes_function_name}-${terraform.workspace}"
  job_definition = local.job_definition
}

module "voices" {
  source = "./modules/voices"
  bucket_name = local.bucket_name
  voices_function_name = "${var.voices_function_name}-${terraform.workspace}"
  voices_image_uri = local.voices_image
}

module "scraper" {
  source = "./modules/scraper"
  scraper_function_name = "${var.scraper_function_name}-${terraform.workspace}"
  scraper_image = local.scraper_image
  websocket_execution_arn = module.api_gateway_websocket.execution_arn
  websocket_endpoint = module.api_gateway_websocket.websocket_url_https
}

module "scraper_trigger" {
  source = "./modules/scraper-trigger"
  scraper_trigger_function_name = "${var.scraper_trigger_function_name}-${terraform.workspace}"
  scraper_trigger_image = local.scraper_trigger_image
  scraper_function_arn = module.scraper.scraper_arn
  scraper_function_name = "${var.scraper_function_name}-${terraform.workspace}"
  websocket_execution_arn = module.api_gateway_websocket.execution_arn
  websocket_endpoint = module.api_gateway_websocket.websocket_url_https
}

module "api_gateway" {
  source = "./modules/api-gateway-rest"

  region = var.region

  episodes_integration_uri = module.podcast_episodes.lambda_invoke_arn
  voices_integration_uri = module.voices.lambda_invoke_arn

  episodes_function_name = "${var.podcast_episodes_function_name}-${terraform.workspace}"
  voices_function_name = "${var.voices_function_name}-${terraform.workspace}"
}

module "api_gateway_websocket" {
  source = "./modules/api-gateway-websocket"
  scraper_integration_uri = module.scraper_trigger.scraper_trigger_invoke_arn
  region = var.region
  websocket_authorizer_lambda_uri = module.authorizer.authorizer_invoke_arn
}

module "authorizer" {
  source = "./modules/authorizer"
  authorizer_function_name = "${var.authorizer_function_name}-${terraform.workspace}"
  issuer_url_jwt = terraform.workspace == "prod" ? var.issuer_url_jwt_prod : var.issuer_url_jwt_dev
  jwt_secret = terraform.workspace == "prod" ? var.jwt_secret_prod : var.jwt_secret_dev
  authorizer_image = local.authorizer_image
  websocket_execution_arn = module.api_gateway_websocket.execution_arn
}

module "sns_contact" {
  source = "./modules/sns-contact"
  sns_emails = var.sns_emails
}

module "cloudfront_domain" {
  source = "./modules/dns_cloudfront"
  origin_domain_name = local.origin_domain_name
  domain_name = var.domain_name
  origin_id = local.origin_id
}

module "batch_image_builder" {
  source = "./modules/image-builder"

  f5tts_image              = local.f5tts_image
  image_builder_logs_bucket = var.image_builder_logs_bucket
  base_ami_id              = data.aws_ami.ecs_gpu_optimized.id
  root_volume_size         = 100

  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

data "aws_ami" "ecs_gpu_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-gpu-hvm-2.0.*-x86_64-ebs"]
  }
}