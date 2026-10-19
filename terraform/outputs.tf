output "prometheus_url" {
  description = "URL de Prometheus"
  value       = "http://localhost:${var.prometheus_port}"
}

output "grafana_url" {
  description = "URL de Grafana (admin / ver variable grafana_admin_password)"
  value       = "http://localhost:${var.grafana_port}"
}

output "sonarqube_url" {
  description = "URL de SonarQube (admin / admin en el primer login)"
  value       = "http://localhost:${var.sonarqube_port}"
}

output "red_devops" {
  description = "Red Docker compartida por todos los servicios"
  value       = docker_network.devops.name
}
