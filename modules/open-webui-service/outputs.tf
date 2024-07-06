output "ecs_cluster" {
  description = "ECS cluster where Open webui is deployed in (tf resource: aws_ecs_cluster)"
  value       = aws_ecs_cluster.open_webui

}

output "ecs_task_def" {
  description = "ECS task definition for Open webui (tf resource: aws_ecs_task_definition)"
  value       = aws_ecs_task_definition.open_webui
}

output "ecs_service" {
  description = "ECS fargate service for Open webui (tf resource: aws_ecs_service)"
  value       = aws_ecs_service.open_webui
}

output "efs" {
  description = "EFS used by the ECS tasks (tf resource: aws_efs_file_system)"
  value       = aws_efs_file_system.open_webui
}

output "alb" {
  description = "ALB in the front of ECS (tf resource: aws_lb)"
  value       = aws_lb.ow
}

output "service_endpoint" {
  description = "Endpoint to consumer Ollama service"
  value       = local.alb_configs.create_domain ? "https://${var.open_webui_domain}" : "http://${aws_lb.ow.dns_name}"
}
