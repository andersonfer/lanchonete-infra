# ==============================================================================
# OUTPUTS - AWS LOAD BALANCER CONTROLLER
# ==============================================================================

output "controller_service_account" {
  description = "Nome do ServiceAccount do AWS Load Balancer Controller"
  value       = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
}

output "controller_namespace" {
  description = "Namespace do AWS Load Balancer Controller"
  value       = kubernetes_service_account.aws_load_balancer_controller.metadata[0].namespace
}

output "helm_release_status" {
  description = "Status da instalação do Helm"
  value       = helm_release.aws_load_balancer_controller.status
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = var.cluster_name
}

output "vpc_id" {
  description = "ID da VPC utilizada"
  value       = data.aws_vpc.default.id
}

output "subnets_publicas" {
  description = "IDs das subnets públicas"
  value       = data.aws_subnets.publicas.ids
}

