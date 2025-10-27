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
  bucket_name = var.bucket_name
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  batch_job_queue = var.batch_job_queue
  free_batch_job_queue = var.free_batch_job_queue
  job_definition = var.job_definition

  ami_id = module.batch_image_builder.custom_ami_id
  
  env = var.env
}

module "f5tts_result_queue" {
  source = "./modules/f5tts-result-queue"
  region = var.region
  sqs_queue_name = var.sqs_queue_name
}

module "f5tts_result_processing" {
  source = "./modules/f5tts-result-processing"
  processing_result_function_name = var.processing_result_function_name
  processing_result_handler_image = local.f5tts_result_processing_image
  supabase_url = var.supabase_url
  supabase_service_key = var.supabase_service_key
  sqs_queue_arn = module.f5tts_result_queue.sqs_queue_result_arn
  env = var.env
}

module "podcast_episodes" {
  source = "./modules/podcast-episodes"
  bucket_name = var.bucket_name
  podcast_episodes_image = local.podcast_episodes_image
  podcast_episodes_function_name = var.podcast_episodes_function_name
  free_batch_job_queue = var.free_batch_job_queue
  batch_job_queue = var.batch_job_queue
  job_definition = var.job_definition
  
  env = var.env
}

module "voices" {
  source = "./modules/voices"
  bucket_name = var.bucket_name
  voices_function_name = var.voices_function_name
  voices_image_uri = local.voices_image
  env = var.env
  region = var.region
}

module "scraper" {
  source = "./modules/scraper"
  scraper_function_name = var.scraper_function_name
  scraper_image = local.scraper_image
  region = var.region
  env = var.env
}

module "api_gateway" {
  source = "./modules/api-gateway"

  env = var.env
  region = var.region

  scraper_integration_uri = module.scraper.lambda_invoke_arn
  episodes_integration_uri = module.podcast_episodes.lambda_invoke_arn
  voices_integration_uri = module.voices.lambda_invoke_arn

  episodes_function_name = var.podcast_episodes_function_name
  voices_function_name = var.voices_function_name
  scraper_function_name = var.scraper_function_name
}

module "sns_contact" {
  source = "./modules/sns-contact"
  sns_emails = var.sns_emails
}

module "cloudfront_domain" {
  source = "./modules/dns_cloudfront"
  origin_domain_name = var.origin_domain_name
  domain_name = var.domain_name
  origin_id = var.origin_id
}

module "batch_image_builder" {
  source = "./modules/image-builder"

  env                      = var.env
  f5tts_image              = local.f5tts_image
  image_builder_logs_bucket = var.image_builder_logs_bucket
  base_ami_id              = data.aws_ami.ecs_gpu_optimized.id
  root_volume_size         = 100

  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  region = var.region
}

data "aws_ami" "ecs_gpu_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-gpu-hvm-2.0.*-x86_64-ebs"]
  }
}