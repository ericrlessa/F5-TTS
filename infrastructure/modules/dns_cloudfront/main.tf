provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["www.${var.domain_name}"]

  tags = {
    Name = "geniuspod-cert"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudfront_distribution" "cdn_geniuspod" {
  enabled         = true
  comment         = ""
  is_ipv6_enabled = true
  http_version    = "http2"
  price_class     = "PriceClass_All"

  lifecycle {
    prevent_destroy = true
  }

  aliases = ["geniuspod.ai", "www.geniuspod.ai"]

  origin {
    origin_id   = var.origin_id
    domain_name = var.origin_domain_name
    
     custom_origin_config {
        http_port                = 80
        https_port               = 443
        origin_protocol_policy   = "http-only"
        origin_ssl_protocols     = ["TLSv1.2"]
        origin_read_timeout      = 60
        origin_keepalive_timeout = 60
    }
  }

  default_cache_behavior {
    target_origin_id       = var.origin_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    compress         = true

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    trusted_key_groups = []
    trusted_signers    = []
  }

  custom_error_response {
    error_code            = 404
    response_page_path    = "/index.html"
    response_code         = "200"
    error_caching_min_ttl = 10
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

}
