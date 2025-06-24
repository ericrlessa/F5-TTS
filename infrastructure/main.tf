module "f5tts" {
  source = "./modules/f5tts"
  region = var.region
  sqs_queue_name = var.sqs_queue_name
  ecs_instance_type = var.ecs_instance_type
  ecs_cluster_name = var.ecs_cluster_name
  ecs_ami_ssm_param = var.ecs_ami_ssm_param
  f5tts_image = local.f5tts_image
  listener_image = local.sqs_listener_image
}

module "clone_service" {
  source = "./modules/clone-service"
  bucket_name = var.bucket_name
  region = var.region
  clone_service_image = local.clone_service_image
}

module "generate_audio" {
  source = "./modules/generate-audio"
  bucket_name = var.bucket_name
  region = var.region
  generate_audio_handler_image = local.generate_audio_handler_image
}

module "sqs_listener" {
  source = "./modules/sqs-listener"
  bucket_name = var.bucket_name
  region = var.region
  sqs_queue_name = var.sqs_queue_name
}