output "sqs_queue_url" {
  value = aws_sqs_queue.gen_audio_queue.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.gen_audio_queue.arn
}

output "sqs_queue_result_url" {
  value = aws_sqs_queue.gen_audio_result_queue.id
}

output "sqs_queue_result_arn" {
  value = aws_sqs_queue.gen_audio_result_queue.arn
}

output "sqs_queue_url_dlq" {
  value = aws_sqs_queue.gen_audio_dlq.id
}


output "sqs_short_podcasts_url" {
  value = aws_sqs_queue.short_podcasts.id
}

output "sqs_short_podcasts_arn" {
  value = aws_sqs_queue.short_podcasts.arn
}

output "sqs_medium_podcasts_url" {
  value = aws_sqs_queue.medium_podcasts.id
}

output "sqs_medium_podcasts_arn" {
  value = aws_sqs_queue.medium_podcasts.arn
}

output "sqs_large_podcasts_url" {
  value = aws_sqs_queue.large_podcasts.id
}

output "sqs_large_podcasts_arn" {
  value = aws_sqs_queue.large_podcasts.arn
}

output "sqs_free_podcasts_url" {
  value = aws_sqs_queue.free.id
}

output "sqs_free_podcasts_arn" {
  value = aws_sqs_queue.free.arn
}

output "sqs_end_idle_task_url" {
  value = aws_sqs_queue.end_idle_task.id
}

output "sqs_end_idle_task_arn" {
  value = aws_sqs_queue.end_idle_task.arn
}