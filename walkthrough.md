# Walkthrough: Migración de Banquito Core a Kubernetes

Hemos completado la estructuración y migración de los servicios de Banquito Core desde Docker Compose a Kubernetes (K8s). A continuación, se detalla el trabajo realizado y cómo validar los resultados.

---

## Cambios Realizados

Se ha creado una estructura modular bajo el directorio `k8s/` del proyecto para facilitar el mantenimiento y la escalabilidad del sistema:

1. **Namespace (`k8s/namespace.yaml`)**:
   - Define el namespace `banquito-core` para aislar todos los recursos de la aplicación.

2. **Configuraciones y Secretos (Descentralizados)**:
   - En lugar de un ConfigMap y un Secret global, cada microservicio tiene su propio archivo `configmap.yaml` y `secret.yaml` (donde aplica) dentro de su directorio correspondiente (ej: `k8s/identity/configmap.yaml`). Esto independiza y aísla las variables y contraseñas de cada pod.

3. **Volúmenes Persistentes (`k8s/accounting/pvc.yaml`)**:
   - Define un `PersistentVolumeClaim` con nombre `accounting-reports-pvc` utilizando la clase de almacenamiento `standard` solicitada por el usuario, asignando `1Gi` de capacidad para los reportes contables de fin de día (EOD).

4. **Servicios de Aplicación (`k8s/<servicio>/`)**:
   - Cada servicio se ha estructurado con su propio manifiesto de `Deployment` y `Service` (tipo `ClusterIP` para comunicación interna por nombre DNS del clúster):
     - `mailpit`: Contenedor de Mailpit con puertos `8025` y `1025`, y probes de salud sobre HTTP `/api/v1/info`.
     - `identity`: Microservicio de identidad y acceso en el puerto `8081`. Probes de salud mediante Actuator `/actuator/health`.
     - `customer`: Microservicio de clientes con puertos `8082` (HTTP) y `9092` (gRPC).
     - `admin`: Microservicio de administración con puertos `8083` (HTTP) y `9093` (gRPC).
     - `accounting`: Microservicio contable con puertos `8084` (HTTP) y `9094` (gRPC), con el montaje del volumen `/reports/eod` asociado a la PVC.
     - `document`: Microservicio de documentos en los puertos `8086` (HTTP) y `9096` (gRPC) con la URI de MongoDB Atlas cargada de forma segura.
     - `notification`: Microservicio de notificaciones en los puertos `8087` (HTTP) y `9097` (gRPC) configurado para enviar correos a la instancia de `mailpit` interna.
     - `account`: Microservicio transaccional en el puerto `8085` (HTTP) que utiliza los DNS de Kubernetes para interactuar con los puertos gRPC de los demás servicios.
   - **Estrategia de Despliegue**: Todos los microservicios core se configuraron con `strategy.type: Recreate` para evitar deadlocks de asignación de memoria/CPU por solapamiento de contenedores o locks de volúmenes persistentes en clústeres restringidos.

5. **Balanceador e Ingress (`k8s/ingress/ingress.yaml`)**:
   - Define un recurso `Ingress` usando la clase `"gce"` (Google Cloud Load Balancer) para enrutar el tráfico externo hacia los microservicios correspondientes según los prefijos de ruta `pathType: Prefix`.

---

## Verificación y Pruebas Realizadas

### Validación Sintáctica y de Formato
Se ejecutó un script de verificación automatizada basado en `PyYAML` para cargar y analizar cada uno de los archivos creados.
- **Resultado**: Todos los archivos YAML son sintácticamente válidos y estructurados de acuerdo con las especificaciones de Kubernetes.

---

## Próximos Pasos (Despliegue en la Nube GKE)

Para aplicar la configuración en el clúster de Kubernetes en Google Cloud Engine (GKE):

1. **Configurar el contexto de GCP**:
   ```bash
   gcloud container clusters get-credentials <NOMBRE_DEL_CLUSTER> --region <REGION> --project <PROYECTO>
   ```

2. **Aplicar los manifiestos en orden**:
   ```bash
   # 1. Crear namespace
   kubectl apply -f k8s/namespace.yaml

   # 2. Crear PVC
   kubectl apply -f k8s/accounting/pvc.yaml

   # 3. Desplegar los servicios y sus respectivas configuraciones locales
   kubectl apply -f k8s/mailpit/
   kubectl apply -f k8s/identity/
   kubectl apply -f k8s/customer/
   kubectl apply -f k8s/admin/
   kubectl apply -f k8s/accounting/
   kubectl apply -f k8s/document/
   kubectl apply -f k8s/notification/
   kubectl apply -f k8s/account/

   # 4. Aplicar el Ingress
   kubectl apply -f k8s/ingress/ingress.yaml
   ```

3. **Verificar el estado**:
   ```bash
   kubectl get pods -n banquito-core
   kubectl get svc -n banquito-core
   kubectl get ingress -n banquito-core
   ```
