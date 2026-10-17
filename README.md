# Banquito Infra 🏦

Infraestructura de despliegue para Banquito (Plataforma bancaria modular). Sistema centralizado de CI/CD usando GitHub Actions y Docker Compose para orquestar 15 microservicios.


## 📌 Diagrama de arquitectura de despligue
[🔗 Ver diagrama de despliegue (draw.io)](https://viewer.diagrams.net/?tags=%7B%7D&lightbox=1&highlight=0000ff&edit=_blank&layers=1&nav=1&title=despligue-banquito-v1-v2-v3.drawio&dark=auto#Uhttps%3A%2F%2Fdrive.google.com%2Fuc%3Fid%3D1TvSKqRV-spmtQ9MpZ9ghEQMWyl9uSvVH%26export%3Ddownload)

## Repositorio original 

https://github.com/CamilaParedes23/banquito-infra-3p

## 📋 Índice

- [Arquitectura](#arquitectura)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Requisitos](#requisitos)
- [Configuración Inicial](#configuración-inicial)
- [Despliegue](#despliegue)
- [Scripts de Utilidad](#scripts-de-utilidad)
- [Workflows CI/CD](#workflows-cicd)
- [Troubleshooting](#troubleshooting)

## 🏗️ Arquitectura

### Servicios Desplegados (15 total)

```
├── CORE SYSTEM (12 servicios)
│   ├── Backend (7)
│   │   ├── 🔲 Contable (8007)
│   │   ├── 🔲 Admin (8008)
│   │   ├── 🔲 Clientes (8009)
│   │   ├── 🔲 Transaccional (8010)
│   │   ├── 🔲 Notificación (8011)
│   │   ├── 🔲 Seguridad (8012)
│   │   └── 🔲 Documentos (8013)
│   └── Frontend (2)
│       ├── 🌐 Banca Web (3000)
│       └── 🌐 Ventanilla Frontend (3001)
│
└── SWITCH SYSTEM (7 servicios)
    ├── Backend (6)
    │   ├── 🔲 Enrutamiento (8014)
    │   ├── 🔲 Facturación (8015)
    │   ├── 🔲 Lotes (8016)
    │   ├── 🔲 Pagos Internos (8017)
    │   ├── 🔲 Pagos Externos (8018)
    │   └── 🔲 Reportes (8019)
    └── Frontend (1)
        └── 🌐 Switch Frontend (3002)
```

### Flujo de Despliegue

```
GitHub Action (workflow_dispatch)
         ↓
SSH a VM (GCP)
         ↓
Script Bash (deploy-core.sh / deploy-switch.sh)
         ↓
Docker Compose (pull + up -d)
         ↓
Contenedores Corriendo
```

## 📁 Estructura del Proyecto

```
banquito-infra/
│
├── .github/workflows/                          # GitHub Actions CI/CD
│   ├── deploy-core-back.yml                   # Deploy Backend Core
│   ├── deploy-core-front.yml                  # Deploy Frontend Core
│   ├── deploy-switch-back.yml                 # Deploy Backend Switch
│   └── deploy-switch-front.yml                # Deploy Frontend Switch
│
├── docker/                                     # Configuraciones Docker
│   ├── core/                                   # Core Backend Services
│   │   ├── docker-compose.yml                 # Orquestración Core Backend
│   │   └── .env                               # Variables de entorno
│   │
│   ├── core-frontend/                         # Core Frontend Services
│   │   ├── docker-compose.yml                 # Orquestración Core Frontend
│   │   └── .env                               # Variables de entorno
│   │
│   ├── switch/                                # Switch Backend Services
│   │   ├── docker-compose.yml                 # Orquestración Switch Backend
│   │   └── .env                               # Variables de entorno
│   │
│   └── switch-frontend/                       # Switch Frontend Service
│       ├── docker-compose.yml                 # Orquestración Switch Frontend
│       └── .env                               # Variables de entorno
│
├── scripts/                                    # Scripts de Despliegue
│   ├── deploy-core.sh                         # Deploy Core Backend [SERVICE]
│   ├── deploy-core-front.sh                   # Deploy Core Frontend [SERVICE]
│   ├── deploy-switch.sh                       # Deploy Switch Backend [SERVICE]
│   ├── deploy-switch-front.sh                 # Deploy Switch Frontend [SERVICE]
│   ├── restart-core.sh                        # Restart Core [SERVICE]
│   └── restart-switch.sh                      # Restart Switch [SERVICE]
│
├── docker-compose.yml                         # Master compose (opcional)
└── README.md                                  # Este archivo
```

## 📦 Requisitos

- Docker >= 20.10
- Docker Compose >= 2.0
- Git >= 2.25
- Bash >= 4.0
- curl
- SSH key configurada para acceso a VM

### En la VM (GCP):

```bash
# Instalación rápida
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt-get install -y docker-compose git

# Agregar usuario a grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

## 🔧 Configuración Inicial

### 1. Clonar Repositorio

```bash
git clone https://github.com/banquito/banquito-infra.git
cd banquito-infra
```

### 2. Configurar Variables de Entorno

**Local (.env files):**

```bash
# docker/core/.env (Variables compartidas)
DOCKER_USERNAME=tu_usuario_docker
SPRING_PROFILES_ACTIVE=prod

# Crear además archivos específicos para bases de datos:
# docker/core/.env.contable, .env.admin, .env.clientes, .env.transaccional, .env.notificacion, .env.seguridad, .env.documentos
# Ejemplo de contenido (.env.contable):
# DB_HOST=tu_db_host
# DB_PORT=5432
# DB_NAME=banquito_contable
# DB_USER=tu_usuario_db
# DB_PASSWORD=tu_contraseña_db
```

**GitHub Secrets:**

Configura en `Settings > Secrets and variables > Actions`:

```
GCP_VM_HOST          # IP o hostname de la VM
GCP_VM_USER          # Usuario SSH (ej: ubuntu)
GCP_SSH_KEY          # Private SSH key
DOCKER_USERNAME      # Usuario Docker Hub
DOCKER_PASSWORD      # Token Docker Hub
```

### 3. Permisos de Scripts

```bash
chmod +x scripts/*.sh
```

## 🚀 Despliegue

### Opción 1: Usar Workflows GitHub Actions (Recomendado)

Va a `Actions` en GitHub y dispara el workflow:

```
1. Selecciona el workflow (deploy-core-back, deploy-switch-back, etc)
2. Click en "Run workflow"
3. Selecciona el servicio a desplegar
4. Espera a que termine
```

**Parámetros disponibles:**

- `all` - Despliega todos los servicios del subsistema
- `contable` - Deploy solo Core Contable
- `admin` - Deploy solo Core Admin
- `clientes` - Deploy solo Core Clientes
- `transaccional` - Deploy solo Core Transaccional
- `notificacion` - Deploy solo Core Notificación
- `seguridad` - Deploy solo Core Seguridad
- `documentos` - Deploy solo Core Documentos

Para Switch:
- `all` - Despliega todos los servicios del subsistema
- `enrutamiento` - Deploy solo Enrutamiento
- `facturacion` - Deploy solo Facturación
- `lotes` - Deploy solo Lotes
- `pagos-internos` - Deploy solo Pagos Internos
- `pagos-externos` - Deploy solo Pagos Externos
- `reportes` - Deploy solo Reportes

### Opción 2: Desplegar Manualmente via SSH

```bash
# SSH a la VM
ssh usuario@tu_vm_host

# Navegar al repositorio
cd banquito-infra

# Deploy específico
bash scripts/deploy-core.sh contable        # Deploy Core Contable
bash scripts/deploy-switch.sh enrutamiento          # Deploy Switch Lotes

# Deploy todos
bash scripts/deploy-core.sh all              # Deploy todos Core Backend
bash scripts/deploy-switch.sh all            # Deploy todos Switch Backend
```

### Opción 3: Usar Docker Compose Maestro

```bash
# Todos los servicios
docker-compose up -d

# Servicios específicos
docker-compose up -d core-contable sw-enrutamiento

# Ver logs
docker-compose logs -f core-contable

# Detener
docker-compose down
```

## 🔄 Reiniciar Servicios

```bash
# Restart específico
bash scripts/restart-core.sh contable
bash scripts/restart-switch.sh enrutamiento

# Restart todos
bash scripts/restart-core.sh all
bash scripts/restart-switch.sh all

# Usando Docker Compose
cd docker/core
docker-compose restart core-contable
docker-compose restart                    # Restart todos
```

## 📜 Scripts de Utilidad

### deploy-core.sh

Deploy todos o servicio específico del subsistema Core Backend.

```bash
bash scripts/deploy-core.sh [SERVICE]     # SERVICE: all|contable|admin|clientes|transaccional|notificacion|seguridad|documentos
```

**Qué hace:**
- Navega a `docker/core`
- Realiza `docker-compose pull`
- Realiza `docker-compose up -d`
- Muestra estado de contenedores
- Coloriza output

### deploy-core-front.sh

Deploy Frontend del subsistema Core.

```bash
bash scripts/deploy-core-front.sh [SERVICE]  # SERVICE: all|banca-web|ventanilla-frontend
```

### deploy-switch.sh

Deploy todos o servicio específico del subsistema Switch Backend.

```bash
bash scripts/deploy-switch.sh [SERVICE]  # SERVICE: all|enrutamiento|facturacion|lotes|pagos-internos|pagos-externos|reportes
```

### deploy-switch-front.sh

Deploy Frontend del subsistema Switch.

```bash
bash scripts/deploy-switch-front.sh [SERVICE]  # SERVICE: all|sw-frontend
```

### restart-*.sh

Reinicia servicios sin hacer pull.

```bash
bash scripts/restart-core.sh [SERVICE]
bash scripts/restart-switch.sh [SERVICE]
```

## 🔄 Workflows CI/CD

Cuatro workflows automáticos en `.github/workflows/`:

### 1. deploy-core-back.yml

**Triggers:**
- `workflow_dispatch` - Manual desde Actions
- `repository_dispatch` - Disparo desde código

**Acciones:**
- SSH a VM GCP
- Ejecuta `scripts/deploy-core.sh [SERVICE]`
- Servicios: contable, admin, clientes, transaccional, notificacion, seguridad, documentos

### 2. deploy-core-front.yml

**Triggers:**
- `workflow_dispatch` - Manual desde Actions
- `repository_dispatch` - Disparo desde código

**Acciones:**
- SSH a VM frontend
- Ejecuta `scripts/deploy-core-front.sh [SERVICE]`
- Servicios: banca-web, ventanilla-frontend

### 3. deploy-switch-back.yml

Idéntico a core-back pero para Switch Backend.

### 4. deploy-switch-front.yml

Idéntico a core-front pero para Switch Frontend.

### Disparar desde Código

Declara eventos en tu repositorio:

```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/dispatches \
  -d '{"event_type":"deploy-core-back","client_payload":{"service":"contable"}}'
```

## 📊 Monitoreo

### Ver Logs

```bash
# En vivo
docker-compose logs -f core-contable

# Últimas N líneas
docker-compose logs --tail 100 core-contable

# Servicios específicos
docker-compose logs sw-enrutamiento sw-facturacion
```

### Health Check

Cada servicio tiene health checks:

```bash
# Verificar estado
curl -f http://localhost:8007/actuator/health   # Core Contable
curl -f http://localhost:8014/actuator/health   # Switch Enrutamiento
```

### Estadísticas de Contenedores

```bash
docker stats                    # CPU, RAM, Network
docker ps                        # Estado de contenedores
docker-compose ps              # Estado en el compose actual
```

## 🐛 Troubleshooting

### Contenedor no inicia

```bash
# Ver logs detallados
docker-compose logs core-contable

# Recrear contenedor
docker-compose up -d --force-recreate core-contable

# Eliminar y volver a crear
docker-compose rm -f core-contable
docker-compose up -d core-contable
```

### Puerto ya en uso

```bash
# Ver qué usa el puerto
lsof -i :8081

# Matar proceso
kill -9 PID

# O cambiar puerto en docker-compose.yml
```

### Problemas de conectividad entre contenedores

```bash
# Verificar red
docker network ls
docker network inspect banquito

# Reconectar contenedor a red
docker network disconnect banquito CONTAINER_ID
docker network connect banquito CONTAINER_ID
```

### Pull de imágenes fallando

```bash
# Verificar credenciales Docker
docker login

# Forzar login nuevo
docker logout
docker login

# Pull manual
docker pull tu_usuario/imagen:latest
```

### SSH no conecta

```bash
# Verificar key
ssh -i /path/to/key usuario@host

# Permisos correctos
chmod 600 /path/to/key
chmod 700 ~/.ssh
```

## 📝 Mejores Prácticas

1. **Siempre usa `scripts/` en lugar de docker directo**
   - Centraliza lógica
   - Fácil de mantener
   - Menos propenso a errores

2. **Usa servicios específicos cuando sea posible**
   - Minimiza tiempo de deploy
   - Reduce riesgo de downtime
   - `deploy-core.sh ventanilla` vs `deploy-core.sh all`

3. **Mantén `.env` actualizado**
   - No commitear credenciales
   - Usar GitHub Secrets
   - Revisar regularmente

4. **Monitorea health checks**
   - Verifica `actuator/health` regularmente
   - Configura alertas
   - Responde rápido ante fallos

5. **Backup de datos importante**
   - Bases de datos
   - Configuraciones
   - Historiales de logs

## 🤝 Contribución

Para cambios en infraestructura:

1. Crea una rama: `git checkout -b feature/mejorar-deploy`
2. Haz cambios
3. Testa localmente
4. Push y crea PR
5. Revisa cambios
6. Merge a main

## 📞 Contacto

Para preguntas o reportar problemas:

- 📧 Email: devops@banquito.com
- 💬 Slack: #infrastructure
- 🐛 Issues: GitHub Issues

---

**Última actualización:** 2026-05-31
**Versión:** 2.0 (Refactorización con Docker Compose y Scripts)
