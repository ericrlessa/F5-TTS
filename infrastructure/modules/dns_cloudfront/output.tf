output "acm_certificate_validation_record" {
  value = length(aws_acm_certificate.cert) > 0 ? [
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : {
      domain_name = dvo.domain_name
      name        = dvo.resource_record_name
      type        = dvo.resource_record_type
      value       = dvo.resource_record_value
    }
  ] : []
}

output "certificate_arn" {
  value = length(aws_acm_certificate.cert) > 0 ? aws_acm_certificate.cert[0].arn : null
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.cdn_geniuspod.domain_name
  description = "CloudFront distribution domain to create CNAME in Namecheap"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn_geniuspod.id
}