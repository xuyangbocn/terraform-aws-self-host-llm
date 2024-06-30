variable "prefix" {
  description = "Prefix to resource created by this module"
  type        = string
  default     = "llm"
}

variable "azs" {
  description = "Availability zones to deploy the EC2"
  type        = list(string)
}

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

# VPC Related
variable "vpc_id" {
  description = "VPC id to deploy the EC2"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "subnet_ids" {
  description = "ID of subnets to deploy the EC2, recommend pvt subnets"
  type        = list(string)
}

# ALB Related
variable "open_webui_port" {
  description = "ALB security group will whitelist ingress traffic over this port from within VPC"
  type        = number
  default     = 0
}


# API GW Related
variable "create_api_gw" {
  description = "Whether to front and expose the internal ALB with API Gateway"
  type        = bool
  default     = true
}

variable "api_gw_disable_execute_endpoint" {
  description = "API Gateway not to expose its own execute endpoint"
  type        = bool
  default     = true
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
