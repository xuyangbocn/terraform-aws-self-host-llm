output "ec2" {
  description = "List of EC2 instances (tf resource: aws_instance)"
  value       = aws_instance.llm
}

output "alb" {
  description = "The ALB in the front of EC2s (tf resource: aws_lb)"
  value       = aws_lb.llm
}

output "api_gw" {
  description = "API gateway instance (tf resource: aws_apigatewayv2_api), "
  value       = one(aws_apigatewayv2_api.llm_apigw)
}

output "service_endpoint" {
  description = "Endpoint to consumer Ollama service"
  value = var.create_api_gw ? (local.apigw_configs.create_custom_domain ?
    "https://${var.api_gw_domain}" :
    aws_apigatewayv2_api.llm_apigw[0].api_endpoint
  ) : aws_lb.llm.dns_name
}

output "dlami_arm" {
  description = "AWS Deep learning AMI for ARM"
  value       = data.aws_ami.dlami_arm.id
}

output "dlami_x86" {
  description = "AWS Deep learning AMI for x86"
  value       = data.aws_ami.dlami_x86.id
}
