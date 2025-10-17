
output "sqs_queue_result_url" {
  value = aws_sqs_queue.gen_audio_result_queue.id
}

output "sqs_queue_result_arn" {
  value = aws_sqs_queue.gen_audio_result_queue.arn
}