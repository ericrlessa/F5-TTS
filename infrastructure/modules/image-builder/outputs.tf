output "custom_ami_id" {
  description = "ID of the custom AMI with pre-pulled container"
  value       = one(one(aws_imagebuilder_image.batch_ami.output_resources).amis).image
}

output "pipeline_arn" {
  description = "ARN of the Image Builder pipeline"
  value       = aws_imagebuilder_image_pipeline.batch_pipeline.arn
}

output "recipe_arn" {
  description = "ARN of the Image Builder recipe"
  value       = aws_imagebuilder_image_recipe.batch_ami_recipe.arn
}