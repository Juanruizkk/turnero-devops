terraform {
  required_version = ">= 1.5"

  required_providers {
    # Provider Docker: gestiona contenedores locales
    # Documentación: https://registry.terraform.io/providers/kreuzwerker/docker
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# ── Provider Docker (local) ───────────────────────────────────────────────────
# Apunta al daemon Docker local. En Linux usa el socket Unix.
# En Windows con Docker Desktop, el host es tcp://localhost:2375
provider "docker" {
  host = var.docker_host
}

# ── Red compartida para todos los servicios DevOps ───────────────────────────
resource "docker_network" "devops" {
  name   = "turnero_devops"
  driver = "bridge"
}

# ──────────────────────────────────────────────────────────────────────────────
# ALTERNATIVA — Floci-AZ (emulación local de Azure)
#
# Floci-AZ permite usar el provider azurerm de HashiCorp sin gastar en nube.
# Para activarlo:
#   1. Instalar Floci: https://floci.io/floci-az/
#   2. Ejecutar: floci-az start
#   3. Descomentar el bloque de abajo y comentar el provider docker de arriba
#
# terraform {
#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~> 3.0"
#     }
#   }
# }
#
# provider "azurerm" {
#   features {}
#   skip_provider_registration = true
#   # Floci-AZ escucha en el mismo endpoint que Azure Resource Manager
#   endpoint = "http://localhost:8080"
#   subscription_id = "00000000-0000-0000-0000-000000000000"
# }
# ──────────────────────────────────────────────────────────────────────────────
