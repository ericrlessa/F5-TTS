provider "aws" {
  region = var.region
}

module "gen_audio_queue" {
  source = "./modules/gen-audio-queue"
  region = var.region
  sqs_queue_name = var.sqs_queue_name
}

module "f5tts" {
  source = "./modules/f5tts"
  region = var.region
  sqs_queue_name = var.sqs_queue_name
  sqs_queue_arn = module.gen_audio_queue.sqs_queue_arn
  ecs_instance_type = var.ecs_instance_type
  ecs_cluster_name = var.ecs_cluster_name
  ecs_ami_ssm_param = var.ecs_ami_ssm_param
  f5tts_image = local.f5tts_image
  sqs_listener_image = local.sqs_listener_image
  bucket_name = var.bucket_name
}

module "clone_service" {
  source = "./modules/clone-service"
  bucket_name = var.bucket_name
  region = var.region
  clone_service_image = local.clone_service_image
  clone_service_function_name = var.clone_service_function_name
}

module "generate_audio" {
  source = "./modules/generate-audio"
  bucket_name = var.bucket_name
  region = var.region
  generate_audio_handler_image = local.generate_audio_handler_image
  generate_audio_function_name = var.generate_audio_function_name
  sqs_queue_arn = module.gen_audio_queue.sqs_queue_arn
  sqs_queue_url = module.gen_audio_queue.sqs_queue_url
}

module "api_gateway" {
  source = "./modules/api-gateway"
  clone_service_integration_uri = module.clone_service.lambda_invoke_arn
  generate_audio_integration_uri = module.generate_audio.lambda_invoke_arn
  generate_audio_function_name = var.generate_audio_function_name
  clone_service_function_name = var.clone_service_function_name
}