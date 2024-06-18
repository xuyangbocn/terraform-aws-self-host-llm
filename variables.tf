variable "region" {
  description = "aws region for setup"
  type        = string
  default     = "ap-southeast-1"
}

variable "api_gw_domain" {
  description = "Domain to be used for API Gw custom domain name setup"
  type        = string
  default     = ""
}

variable "api_gw_domain_route53_zone" {
  description = "Route53 zone id where the custom domain name is hosted at"
  type        = string
  default     = ""
}

variable "api_gw_domain_ssl_cert_arn" {
  description = "The arn of the acm cert for API Gw custom domain name setup"
  type        = string
  default     = ""
}

variable "disable_execute_api_endpoint" {
  description = "disable_execute_api_endpoint of API Gw, may be true if custom domain name is setup"
  type        = bool
  default     = false
}

variable "open_webui_image_url" {
  description = "URL to open webui docker image for deployment"
  type        = string
}

variable "open_webui_domain" {
  description = "Domain to be used to expose Open Webui ALB"
  type        = string
  default     = ""
}

variable "open_webui_domain_route53_zone" {
  description = "Route53 zone id where the domain name for Open webui ALB is hosted at"
  type        = string
  default     = ""
}

variable "open_webui_domain_ssl_cert_arn" {
  description = "The arn of the acm cert for Open webui ALb"
  type        = string
  default     = ""
}
