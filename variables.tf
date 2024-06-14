variable "custom_domain_name" {
  description = "Domain to be used for API Gw custom domain name setup"
  type        = string
  default     = ""
}

variable "custom_domain_name_route53_zone" {
  description = "Route53 zone id where the custom domain name is hosted at"
  type        = string
  default     = ""
}

variable "custom_domain_name_ssl_cert_arn" {
  description = "The arn of the acm cert for API Gw custom domain name setup"
  type        = string
  default     = ""
}

variable "disable_execute_api_endpoint" {
  description = "disable_execute_api_endpoint of API Gw, may be true if custom domain name is setup"
  type        = bool
  default     = false
}
