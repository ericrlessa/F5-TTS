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

module "gen_audio_queue" {
  source = "./modules/gen-audio-queue"
  region = var.region
  sqs_queue_name = var.sqs_queue_name
}

module "vpc" {
  source = "./modules/vpc"
  region = var.region
}

module "f5tts" {
  source = "./modules/f5tts"
  region = var.region
  sqs_queue_name = var.sqs_queue_name
  sqs_queue_arn = module.gen_audio_queue.sqs_queue_arn
  sqs_queue_url = module.gen_audio_queue.sqs_queue_url
  ecs_instance_type = var.ecs_instance_type
  ecs_cluster_name = var.ecs_cluster_name
  ecs_ami_ssm_param = var.ecs_ami_ssm_param
  f5tts_image = local.f5tts_image
  sqs_listener_image = local.sqs_listener_image
  bucket_name = var.bucket_name
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  env = var.env
}

module "clone_service" {
  source = "./modules/clone-service"
  bucket_name = var.bucket_name
  region = var.region
  clone_service_image = local.clone_service_image
  clone_service_function_name = var.clone_service_function_name
  env = var.env
}

module "generate_audio" {
  source = "./modules/generate-audio"
  bucket_name = var.bucket_name
  generate_audio_handler_image = local.generate_audio_handler_image
  generate_audio_function_name = var.generate_audio_function_name
  sqs_queue_arn = module.gen_audio_queue.sqs_queue_arn
  sqs_queue_url = module.gen_audio_queue.sqs_queue_url
  env = var.env
}

module "list_audio" {
  source = "./modules/list-audio"
  bucket_name = var.bucket_name
  list_audio_function_name = var.list_audio_function_name
  list_audio_handler_image = local.list_audio_handler_image
  env = var.env
  region = var.region
}

module "processing_result_audio" {
  source = "./modules/processing-result-listener"
  processing_result_function_name = var.processing_result_function_name
  processing_result_handler_image = local.processing_result_handler_image
  supabase_url = var.supabase_url
  supabase_service_key = var.supabase_service_key
  sqs_queue_arn = module.gen_audio_queue.sqs_queue_result_arn
  env = var.env
}

module "api_gateway" {
  source = "./modules/api-gateway"
  clone_service_integration_uri = module.clone_service.lambda_invoke_arn
  generate_audio_integration_uri = module.generate_audio.lambda_invoke_arn
  generate_audio_function_name = var.generate_audio_function_name
  clone_service_function_name = var.clone_service_function_name
  list_audio_integration_uri = module.list_audio.lambda_invoke_arn
  list_service_function_name = var.list_audio_function_name
  env = var.env
}