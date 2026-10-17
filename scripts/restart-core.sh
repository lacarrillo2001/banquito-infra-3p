#!/bin/bash

set -e

SERVICE="${1:-all}"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW} Reiniciando Banquito Core Backend...${NC}"
echo -e "${YELLOW} Servicio: $SERVICE${NC}"

cd "$(dirname "$0")/../docker/core"

case "$SERVICE" in
    all)
        echo -e "${YELLOW} Reiniciando TODOS los servicios...${NC}"
        docker compose restart
        ;;
    *)
        echo -e "${YELLOW}Reiniciando servicio: $SERVICE${NC}"
        docker compose restart "$SERVICE"
        ;;
esac

echo -e "${GREEN} Reinicio completado${NC}"
echo -e "\n${YELLOW} Estado de contenedores:${NC}"
docker compose ps
