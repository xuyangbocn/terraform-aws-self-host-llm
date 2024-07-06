variable "region" {
  description = "AWS region for setup"
  type        = string
  default     = "ap-southeast-1"
}

variable "azs" {
  description = "List of AWS availability zone to deploy the VPC hosting Ollama and Open webui"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

# VPC related
variable "vpc_name" {
  description = "Name of vpc to be created"
  type        = string
  default     = "llm-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC creation"
  type        = string
  default     = "172.31.0.0/16"
}

variable "vpc_private_subnets_names" {
  description = "List of VPC private subnets name"
  type        = list(string)
  default     = ["private-48-1a", "private-64-1b", "private-80-1c"]
}

variable "vpc_private_subnets_cidrs" {
  description = "List of VPC private subnets cidrs"
  type        = list(string)
  default     = ["172.31.48.0/20", "172.31.64.0/20", "172.31.80.0/20"]
}

variable "vpc_public_subnets_names" {
  description = "List of VPC public subnets name"
  type        = list(string)
  default     = ["public-0-1a", "public-16-1b", "public-32-1c"]
}

variable "vpc_public_subnets_cidrs" {
  description = "List of VPC public subnets cidrs"
  type        = list(string)
  default     = ["172.31.0.0/20", "172.31.16.0/20", "172.31.32.0/20"]
}

# LLM EC2 Related
variable "llm_ec2_configs" {
  description = "List of EC2/EBS config for each LLM EC2"
  /* Ex.
  [
    {
      llm_model = "llama3:8b"
      instance_type = "g5g.xlarge"
      ami_id = "" 
      ebs_volume_gb = 200
      app_port = 11434
    },
  ]
  */
  type = list(object({
    llm_model     = string
    instance_type = string
    ami_id        = string # if empty string, fall back to default DL AMI by AWS
    ebs_volume_gb = number
    app_port      = number
  }))
}

# API GW Related
variable "create_api_gw" {
  description = "Whether to front and expose the internal ALB with API Gateway"
  type        = bool
  default     = true
}

variable "api_gw_disable_execute_endpoint" {
  description = "disable_execute_api_endpoint of API Gw, may be true if custom domain name is setup"
  type        = bool
  default     = false
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

# Open WebUI related
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
