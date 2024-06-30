output "llm_service_endpoint" {
  value = module.llm_service.service_endpoint
}

output "open_webui_endpoint" {
  value = module.open_webui_service.service_endpoint
}
