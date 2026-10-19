# ── Prometheus ────────────────────────────────────────────────────────────────
resource "docker_image" "prometheus" {
  name         = "prom/prometheus:latest"
  keep_locally = true
}

resource "docker_container" "prometheus" {
  name    = "turnero_prometheus"
  image   = docker_image.prometheus.image_id
  restart = "unless-stopped"

  ports {
    internal = 9090
    external = var.prometheus_port
  }

  # Monta el archivo de configuración de scraping desde la carpeta monitoring/
  volumes {
    host_path      = "${abspath(var.monitoring_config_path)}/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.devops.name
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=15d",
    "--web.enable-lifecycle"
  ]
}

# ── Grafana ───────────────────────────────────────────────────────────────────
resource "docker_image" "grafana" {
  name         = "grafana/grafana:latest"
  keep_locally = true
}

resource "docker_volume" "grafana_data" {
  name = "turnero_grafana_data"
}

resource "docker_container" "grafana" {
  name    = "turnero_grafana"
  image   = docker_image.grafana.image_id
  restart = "unless-stopped"

  ports {
    internal = 3000
    external = var.grafana_port
  }

  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}",
    "GF_PATHS_PROVISIONING=/etc/grafana/provisioning",
    "GF_USERS_ALLOW_SIGN_UP=false",
    "GF_ANALYTICS_REPORTING_ENABLED=false"
  ]

  # Datasource Prometheus (auto-configurado al arrancar)
  volumes {
    host_path      = "${abspath(var.monitoring_config_path)}/grafana/datasources"
    container_path = "/etc/grafana/provisioning/datasources"
    read_only      = true
  }

  # Dashboards (auto-provisionados)
  volumes {
    host_path      = "${abspath(var.monitoring_config_path)}/grafana/dashboards"
    container_path = "/etc/grafana/provisioning/dashboards"
    read_only      = true
  }

  # Datos persistentes (dashboards creados manualmente, etc.)
  volumes {
    volume_name    = docker_volume.grafana_data.name
    container_path = "/var/lib/grafana"
  }

  networks_advanced {
    name = docker_network.devops.name
  }

  depends_on = [docker_container.prometheus]
}
