variable "docker_host" {
  description = "Socket del daemon Docker"
  type        = string
  default     = "unix:///var/run/docker.sock"
  # Windows con Docker Desktop: "npipe:////./pipe/docker_engine"
}

variable "grafana_admin_password" {
  description = "Contraseña del admin de Grafana"
  type        = string
  sensitive   = true
  default     = "turnero2024"
}

variable "sonarqube_admin_password" {
  description = "Contraseña del admin de SonarQube"
  type        = string
  sensitive   = true
  default     = "turnero2024"
}

variable "prometheus_port" {
  description = "Puerto expuesto de Prometheus"
  type        = number
  default     = 9090
}

variable "grafana_port" {
  description = "Puerto expuesto de Grafana"
  type        = number
  default     = 3000
}

variable "sonarqube_port" {
  description = "Puerto expuesto de SonarQube"
  type        = number
  default     = 9000
}

variable "monitoring_config_path" {
  description = "Ruta absoluta a la carpeta monitoring/ del proyecto"
  type        = string
  default     = "../monitoring"
}
