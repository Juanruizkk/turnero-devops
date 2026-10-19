# Documentación — Infraestructura Terraform

Este módulo provisiona el stack de observabilidad y calidad de TurneroApp usando el
provider Docker de Terraform. Crea y gestiona contenedores locales de Prometheus,
Grafana y SonarQube sobre una red Docker compartida.

---

## Archivos

| Archivo | Responsabilidad |
|---------|----------------|
| `main.tf` | Provider Docker + red compartida |
| `monitoring.tf` | Contenedores Prometheus y Grafana |
| `quality.tf` | Contenedor SonarQube |
| `variables.tf` | Variables configurables (puertos, passwords, rutas) |
| `outputs.tf` | URLs de acceso impresas al finalizar `apply` |

---

## main.tf

### Propósito
Punto de entrada de Terraform. Define la versión mínima requerida, el provider que
se va a usar y la red Docker que comparten todos los contenedores.

### Recursos

#### `docker_network.devops`
Crea una red bridge llamada `turnero_devops`. Todos los contenedores del stack se
conectan a esta red, lo que les permite comunicarse entre sí usando el nombre del
contenedor como hostname (por ejemplo, Grafana accede a Prometheus como
`http://turnero_prometheus:9090`).

```hcl
resource "docker_network" "devops" {
  name   = "turnero_devops"
  driver = "bridge"
}
```

### Provider
Usa `kreuzwerker/docker ~> 3.0` apuntando al socket Docker del host a través de
`var.docker_host`. El valor por defecto (`unix:///var/run/docker.sock`) funciona en
Linux y WSL2. En Windows con Docker Desktop usar
`npipe:////./pipe/docker_engine`.

### Alternativa Azure (comentada)
El archivo incluye un bloque comentado para usar el provider `azurerm` con
Floci-AZ, que emula Azure Resource Manager localmente sin costo. Permite migrar
a nube sin cambiar el código de recursos.

---

## monitoring.tf

### Propósito
Define los contenedores de Prometheus y Grafana junto con sus volúmenes y
configuraciones de provisioning automático.

### Recursos

#### `docker_image.prometheus` / `docker_image.grafana`
Descarga las imágenes desde Docker Hub. `keep_locally = true` evita que Terraform
las elimine al hacer `destroy`, preservando el caché de imagen.

#### `docker_container.prometheus`
| Propiedad | Valor |
|-----------|-------|
| Imagen | `prom/prometheus:latest` |
| Puerto | `var.prometheus_port` → 9090 interno |
| Restart | `unless-stopped` |
| Config | `monitoring/prometheus.yml` montado como read-only |
| Retención | 15 días de series de tiempo |

Flags de inicio:
- `--config.file` — apunta al archivo de scrape config montado
- `--storage.tsdb.path` — directorio de datos internos
- `--storage.tsdb.retention.time=15d` — descarta métricas con más de 15 días
- `--web.enable-lifecycle` — habilita el endpoint `/-/reload` para recargar config sin reiniciar

#### `docker_volume.grafana_data`
Volumen Docker nombrado `turnero_grafana_data` para persistir dashboards creados
manualmente y la configuración interna de Grafana entre reinicios.

#### `docker_container.grafana`
| Propiedad | Valor |
|-----------|-------|
| Imagen | `grafana/grafana:latest` |
| Puerto | `var.grafana_port` → 3000 interno |
| Restart | `unless-stopped` |
| Depends on | `docker_container.prometheus` |

Volúmenes montados:
- `monitoring/grafana/datasources/` → `/etc/grafana/provisioning/datasources` (read-only)
  Provisiona automáticamente Prometheus como datasource al arrancar.
- `monitoring/grafana/dashboards/` → `/etc/grafana/provisioning/dashboards` (read-only)
  Provisiona automáticamente el dashboard `turnero-api.json` al arrancar.
- `turnero_grafana_data` → `/var/lib/grafana`
  Persistencia de datos internos de Grafana.

Variables de entorno configuradas:
- `GF_SECURITY_ADMIN_PASSWORD` — contraseña del admin (desde `var.grafana_admin_password`)
- `GF_PATHS_PROVISIONING` — directorio de provisioning
- `GF_USERS_ALLOW_SIGN_UP=false` — deshabilita registro público
- `GF_ANALYTICS_REPORTING_ENABLED=false` — deshabilita telemetría a Grafana Labs

---

## quality.tf

### Propósito
Provisiona SonarQube Community Edition para análisis estático de código local.
Complementa el análisis en SonarCloud (CI) con una instancia local para desarrollo.

### Recursos

#### `docker_image.sonarqube`
Usa la imagen `sonarqube:10-community` (versión gratuita).

#### Volúmenes Docker
SonarQube requiere 3 volúmenes nombrados para persistir su estado:

| Volumen | Ruta en contenedor | Contenido |
|---------|-------------------|-----------|
| `turnero_sonarqube_data` | `/opt/sonarqube/data` | Base de datos H2, índices de análisis |
| `turnero_sonarqube_logs` | `/opt/sonarqube/logs` | Logs de la aplicación |
| `turnero_sonarqube_extensions` | `/opt/sonarqube/extensions` | Plugins instalados |

#### `docker_container.sonarqube`
| Propiedad | Valor |
|-----------|-------|
| Imagen | `sonarqube:10-community` |
| Puerto | `var.sonarqube_port` → 9000 interno |
| Restart | `unless-stopped` |

Variable de entorno:
- `SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true` — deshabilita los checks de Elasticsearch
  que fallan en máquinas con recursos limitados o sin ajuste de `vm.max_map_count`.

> **Nota Linux/WSL2:** Si SonarQube no arranca, ejecutar:
> ```bash
> wsl -d docker-desktop sysctl -w vm.max_map_count=524288
> ```

---

## variables.tf

Define todas las variables configurables del módulo. Ninguna es obligatoria — todas
tienen valores por defecto funcionales.

| Variable | Tipo | Default | Sensible | Descripción |
|----------|------|---------|----------|-------------|
| `docker_host` | `string` | `unix:///var/run/docker.sock` | No | Socket del daemon Docker |
| `grafana_admin_password` | `string` | `turnero2024` | **Sí** | Contraseña admin de Grafana |
| `sonarqube_admin_password` | `string` | `turnero2024` | **Sí** | Contraseña admin de SonarQube |
| `prometheus_port` | `number` | `9090` | No | Puerto expuesto de Prometheus |
| `grafana_port` | `number` | `3000` | No | Puerto expuesto de Grafana |
| `sonarqube_port` | `number` | `9000` | No | Puerto expuesto de SonarQube |
| `monitoring_config_path` | `string` | `../monitoring` | No | Ruta a la carpeta `monitoring/` |

Las variables marcadas como `sensitive = true` no se imprimen en los logs de
`terraform plan` ni `terraform apply`.

### Sobreescribir variables en CLI

```bash
# Cambiar puerto de Grafana (si el 3000 está ocupado)
terraform apply -var="grafana_port=3001"

# Windows con Docker Desktop
terraform apply -var="docker_host=npipe:////./pipe/docker_engine"

# Múltiples variables
terraform apply \
  -var="docker_host=npipe:////./pipe/docker_engine" \
  -var="grafana_port=3001"
```

---

## outputs.tf

Imprime las URLs de acceso al finalizar `terraform apply`.

| Output | Valor | Descripción |
|--------|-------|-------------|
| `prometheus_url` | `http://localhost:9090` | UI de Prometheus |
| `grafana_url` | `http://localhost:3000` | Dashboard Grafana |
| `sonarqube_url` | `http://localhost:9000` | Análisis SonarQube |
| `red_devops` | `turnero_devops` | Nombre de la red Docker compartida |

Ver los outputs sin hacer apply:
```bash
terraform output
```

---

## Recursos creados por `terraform apply`

En total se crean **11 recursos**:

| # | Tipo | Nombre | Descripción |
|---|------|--------|-------------|
| 1 | `docker_network` | `devops` | Red bridge compartida |
| 2 | `docker_image` | `prometheus` | Imagen prom/prometheus |
| 3 | `docker_image` | `grafana` | Imagen grafana/grafana |
| 4 | `docker_image` | `sonarqube` | Imagen sonarqube:10-community |
| 5 | `docker_volume` | `grafana_data` | Persistencia Grafana |
| 6 | `docker_volume` | `sonarqube_data` | Datos SonarQube |
| 7 | `docker_volume` | `sonarqube_logs` | Logs SonarQube |
| 8 | `docker_volume` | `sonarqube_extensions` | Plugins SonarQube |
| 9 | `docker_container` | `prometheus` | Contenedor Prometheus |
| 10 | `docker_container` | `grafana` | Contenedor Grafana |
| 11 | `docker_container` | `sonarqube` | Contenedor SonarQube |

---

## Comandos de referencia

```bash
# Inicializar (descarga provider kreuzwerker/docker)
terraform init

# Ver qué va a crear sin ejecutar
terraform plan -var="docker_host=npipe:////./pipe/docker_engine"

# Crear infraestructura
terraform apply -var="docker_host=npipe:////./pipe/docker_engine"

# Ver outputs
terraform output

# Destruir todo (no elimina las imágenes Docker por keep_locally = true)
terraform destroy -var="docker_host=npipe:////./pipe/docker_engine"

# Verificar formato
terraform fmt -check -recursive

# Validar sintaxis
terraform validate
```
