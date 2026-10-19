# ── SonarQube Community ───────────────────────────────────────────────────────
# Requiere vm.max_map_count >= 524288 en el host Linux.
# En Windows/WSL2: wsl -d docker-desktop sysctl -w vm.max_map_count=524288

resource "docker_image" "sonarqube" {
  name         = "sonarqube:10-community"
  keep_locally = true
}

resource "docker_volume" "sonarqube_data" {
  name = "turnero_sonarqube_data"
}

resource "docker_volume" "sonarqube_logs" {
  name = "turnero_sonarqube_logs"
}

resource "docker_volume" "sonarqube_extensions" {
  name = "turnero_sonarqube_extensions"
}

resource "docker_container" "sonarqube" {
  name    = "turnero_sonarqube"
  image   = docker_image.sonarqube.image_id
  restart = "unless-stopped"

  ports {
    internal = 9000
    external = var.sonarqube_port
  }

  env = [
    # Deshabilita checks de ES que fallan en entornos con recursos limitados
    "SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true"
  ]

  volumes {
    volume_name    = docker_volume.sonarqube_data.name
    container_path = "/opt/sonarqube/data"
  }

  volumes {
    volume_name    = docker_volume.sonarqube_logs.name
    container_path = "/opt/sonarqube/logs"
  }

  volumes {
    volume_name    = docker_volume.sonarqube_extensions.name
    container_path = "/opt/sonarqube/extensions"
  }

  networks_advanced {
    name = docker_network.devops.name
  }
}
