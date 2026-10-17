# ðŸš€ GuÃ­a RÃ¡pida de Comandos - Banquito Infra

## Despliegue RÃ¡pido

### Deploy desde GitHub Actions (Recomendado)
```bash
1. Ve a https://github.com/banquito/banquito-infra/actions
2. Selecciona:
   - deploy-core-back.yml
   - deploy-core-front.yml
   - deploy-switch-back.yml
   - deploy-switch-front.yml
3. Click "Run workflow" â†’ Selecciona servicio â†’ Espera
```

### Deploy Manual via SSH
```bash
ssh usuario@vm_host
cd banquito-infra

# Core Backend
bash scripts/deploy-core.sh all              # Todos
bash scripts/deploy-core.sh contable         # Solo contable
bash scripts/deploy-core.sh contable         # Solo contable
bash scripts/deploy-core.sh admin            # Solo admin
bash scripts/deploy-core.sh clientes         # Solo clientes
bash scripts/deploy-core.sh transaccional    # Solo transaccional
bash scripts/deploy-core.sh notificacion     # Solo notificación
bash scripts/deploy-core.sh seguridad        # Solo seguridad
bash scripts/deploy-core.sh documentos       # Solo documentos

# Core Frontend
bash scripts/deploy-core-front.sh all        # Todos
bash scripts/deploy-core-front.sh banca-web # Solo banca-web
bash scripts/deploy-core-front.sh ventanilla-frontend

# Switch Backend
bash scripts/deploy-switch.sh all            # Todos
bash scripts/deploy-switch.sh enrutamiento
bash scripts/deploy-switch.sh facturacion
bash scripts/deploy-switch.sh enrutamiento
bash scripts/deploy-switch.sh pagos-internos
bash scripts/deploy-switch.sh pagos-externos
bash scripts/deploy-switch.sh reportes        # Solo reportes

# Switch Frontend
bash scripts/deploy-switch-front.sh all
bash scripts/deploy-switch-front.sh sw-frontend
```

### Deploy con Docker Compose Maestro
```bash
cd banquito-infra

# Todo de una vez
docker-compose up -d

# Solo especÃ­ficos
docker-compose up -d core-contable sw-api-gateway

# Ver logs
docker-compose logs -f core-contable
docker-compose logs --tail 100 sw-enrutamiento

# Detener todo
docker-compose down
```

## Reiniciar Servicios

### Sin hacer Pull (mÃ¡s rÃ¡pido)
```bash
bash scripts/restart-core.sh all
bash scripts/restart-core.sh contable
bash scripts/restart-switch.sh all
bash scripts/restart-switch.sh enrutamiento
```

### Con Docker Compose
```bash
cd docker/core
docker-compose restart
docker-compose restart core-contable

cd ../switch
docker-compose restart sw-enrutamiento
```

## Monitoreo y DiagnÃ³stico

### Ver Estado de Contenedores
```bash
# Compose actual
docker-compose ps

# Todos
docker ps

# Detalles
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Ver Logs
```bash
# En vivo
docker-compose logs -f core-contable

# Ãšltimas 50 lÃ­neas
docker-compose logs --tail 50 core-contable

# EspecÃ­ficos
docker-compose logs sw-enrutamiento sw-facturacion

# Sin timestamp
docker-compose logs --no-log-prefix core-ventanilla
```

### Health Checks
```bash
# Core API Gateway
curl -f http://localhost:8007/actuator/health

# Switch API Gateway
curl -f http://localhost:8014/actuator/health

# Todos
curl -s http://localhost:8081/actuator/health | jq .
curl -s http://localhost:8082/actuator/health | jq .
curl -s http://localhost:8083/actuator/health | jq .
```

### EstadÃ­sticas
```bash
# CPU/RAM en tiempo real
docker stats

# Por contenedor especÃ­fico
docker stats banquito-core-contable

# Verificar puertos
lsof -i :8007
lsof -i :8014
```

## ConfiguraciÃ³n

### Editar Variables de Entorno
```bash
# Core Backend
nano docker/core/.env

# Core Frontend
nano docker/core-frontend/.env

# Switch Backend (Variables compartidas)
nano docker/switch/.env
# Bases de datos específicas:
nano docker/switch/.env.enrutamiento

# Switch Frontend
nano docker/switch-frontend/.env
```

### DespuÃ©s de cambiar .env
```bash
cd docker/core
docker-compose pull
docker-compose up -d
```

## Problemas Comunes

### Contenedor no inicia
```bash
# Ver logs detallados
docker-compose logs core-ventanilla

# Recrear
docker-compose up -d --force-recreate core-ventanilla

# Reset total
docker-compose rm -f core-ventanilla
docker-compose up -d core-ventanilla
```

### Puerto ya en uso
```bash
# Ver quÃ© usa
lsof -i :8081

# Matar proceso
kill -9 PID

# O cambiar puerto en docker-compose.yml
```

### Docker Compose no encuentra .env
```bash
cd docker/core
docker-compose up -d              # Debe estar en el mismo dir

# O especificar:
docker-compose --env-file .env up -d
```

### No puede conectar a VM
```bash
# Verificar clave
ssh -i ~/.ssh/id_rsa usuario@host

# Permisos correctos
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh

# Test de conexiÃ³n
ssh -v usuario@host
```

### Problema con red banquito
```bash
# Verificar red
docker network ls
docker network inspect banquito

# Recrear red
docker network rm banquito
docker-compose up -d    # Se recrea automÃ¡ticamente

# Reconectar contenedor
docker network disconnect banquito CONTAINER_ID
docker network connect banquito CONTAINER_ID
```

## Scripts Ãštiles

### Restart todos los servicios
```bash
#!/bin/bash
cd banquito-infra

bash scripts/restart-core.sh all
bash scripts/restart-switch.sh all

echo "âœ… Todos reiniciados"
docker-compose ps
```

### Health check de todo
```bash
#!/bin/bash
echo "ðŸ” Verificando health..."

for port in 8081 8082 8083 8084 8085 8090 3000 3001 8086 8087 8088 8089 8091 8080 3002; do
  if curl -sf http://localhost:$port/actuator/health > /dev/null 2>&1 || \
     curl -sf http://localhost:$port > /dev/null 2>&1; then
    echo "âœ… Puerto $port OK"
  else
    echo "âŒ Puerto $port FAIL"
  fi
done
```

### Logs de mÃºltiples servicios
```bash
#!/bin/bash
docker-compose logs -f \
  core-api-gateway \
  sw-api-gateway \
  core-ventanilla \
  sw-enrutamiento
```

## GitHub Secrets Necesarios

Configura en `Settings > Secrets and variables > Actions`:

```
GCP_VM_HOST          â†’  IP o hostname de la VM
GCP_VM_USER          â†’  Usuario SSH (ej: ubuntu)
GCP_SSH_KEY          â†’  -----BEGIN OPENSSH PRIVATE KEY-----
DOCKER_USERNAME      â†’  tu_usuario_docker
DOCKER_PASSWORD      â†’  token_docker_hub
VM_HOST              â†’  IP de VM frontend
VM_USER              â†’  usuario SSH
VM_SSH_KEY           â†’  Private SSH key
```

## Backup y Limpieza

### Ver uso de disco
```bash
docker system df
docker volume ls
```

### Limpiar imÃ¡genes no usadas
```bash
docker image prune -a

# Con confirmaciÃ³n
docker image prune -a --force
```

### Limpiar todo (âš ï¸ CUIDADO)
```bash
# Solo contenedores parados
docker container prune

# Todo: imÃ¡genes, volÃºmenes, redes no usadas
docker system prune -a --volumes
```

## Shortcuts Ãštiles

Agrega a `~/.bashrc` o `~/.zshrc`:

```bash
alias binfra='cd ~/banquito-infra'
alias bdeploy-core='bash scripts/deploy-core.sh'
alias bdeploy-switch='bash scripts/deploy-switch.sh'
alias blogs='docker-compose logs -f'
alias bps='docker-compose ps'
alias brestart='bash scripts/restart-core.sh all && bash scripts/restart-switch.sh all'
```

Luego:
```bash
binfra          # Ir a la carpeta
bdeploy-core ventanilla   # Deploy rÃ¡pido
blogs core-api-gateway    # Ver logs
bps             # Ver estado
brestart        # Reiniciar todo
```

---

**Ãšltima actualizaciÃ³n:** 2026-05-31
**VersiÃ³n:** 2.0
