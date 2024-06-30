variable "prefix" {
  description = "Prefix to resource created by this module"
  type        = string
  default     = "ow"
}

variable "region" {
  description = "aws region for setup"
  type        = string
  default     = "ap-southeast-1"
}

variable "azs" {
  description = "Availability zones to deploy the ECS"
  type        = list(string)
}

# VPC related
variable "vpc_id" {
  description = "VPC id to deploy the Open webui ECS"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "ecs_subnet_ids" {
  description = "ID of subnets to deploy the ECS (and EFS storage), recommend pvt subnets"
  type        = list(string)
}

variable "alb_subnet_ids" {
  description = "ID of subnets to deploy the ALB to expose ECS, recommend pub subnets"
  type        = list(string)
}

# LLM service (ollama) related
variable "llm_service_endpoint" {
  description = "The LLM service endpoint (i.e. Ollama base url) for open webui integration. e.g. http://xxx.xx.xx:8888"
  type        = string
}

# Open webui related
variable "open_webui_task_cpu" {
  description = "CPU in open webui task def"
  type        = number
  default     = 1024
}

variable "open_webui_task_mem" {
  description = "Memory in open webui task def"
  type        = number
  default     = 2048
}

variable "open_webui_task_count" {
  description = "Desired tasks in open webui ECS service"
  type        = number
  default     = 3
}

variable "open_webui_port" {
  description = "Port that open webui is open for"
  type        = number
  default     = 8080
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
