# Deploy actual del Core en GKE

## Resumen

Actualmente el core backend esta desplegado en Google Kubernetes Engine (GKE) dentro de un unico namespace llamado `banquito-core`.

La solucion usa:

- `Kustomize` para aplicar manifiestos desde `k8s/`
- `Artifact Registry` para descargar imagenes
- `Google Secret Manager` + `External Secrets Operator` para secretos
- `Workload Identity` para que Kubernetes lea secretos sin credenciales estaticas
- `Ingress` de GKE por rutas (`path-based routing`)
- `1 pod por servicio`

## Estado actual operativo

Al momento de esta documentacion, todos los servicios del core estan levantados y en estado `1/1`:

- `banquito-core-seguridad-3p`
- `banquito-core-clientes-3p`
- `banquito-core-admin-3p`
- `banquito-core-contable-3p`
- `banquito-core-documentos-3p`
- `banquito-core-notificaciones-3p`
- `banquito-core-transaccional-3p`
- `mailpit`

Tambien existen los `Service` internos correspondientes y un `Ingress` publico.

## Namespace usado

Todos los recursos se despliegan en un unico namespace:

- `banquito-core`

Esto esta definido en:

- `k8s/kustomization.yaml`

## Estructura de despliegue

La base activa del despliegue esta en:

- `k8s/`

Los recursos principales incluidos son:

- `namespace.yaml`
- `serviceaccount.yaml`
- `configmap.yaml`
- `externalsecret.yaml`
- `pvc-accounting-reports.yaml`
- `deployment-mailpit.yaml`
- `deployment-seguridad.yaml`
- `deployment-clientes.yaml`
- `deployment-admin.yaml`
- `deployment-contable.yaml`
- `deployment-documentos.yaml`
- `deployment-notificaciones.yaml`
- `deployment-transaccional.yaml`
- `ingress.yaml`

## Imagenes desplegadas

Los microservicios usan imagenes desde Artifact Registry:

- `us-central1-docker.pkg.dev/banquitog2-p3/banquito/banquito-core-seguridad:prod`
- `us-central1-docker.pkg.dev/banquitog2-p3/banquito/banquito-core-clientes:prod`
- `us-central1-docker.pkg.dev/banquitog2-p3/banquito/banquito-core-admin:prod`
- `us-central1-docker.pkg.dev/banquitog2-p3/banquito/banquito-core-contable:prod`
- `us-central1-docker.pkg.dev/banquitog2-p3/banquito/banquito-core-documentos:prod`
- `us-central1-docker.pkg.dev/banquitog2-p3/banquito/banquito-core-notificaciones:prod`
- `us-central1-docker.pkg.dev/banquitog2-p3/banquito/banquito-core-transaccional:prod`

Mailpit usa:

- `axllent/mailpit:v1.20`

## Como se estan obteniendo los secretos

### 1. Secreto fuente en Google Secret Manager

El sistema usa un secreto llamado:

- `core`

Ese secreto esta en Google Secret Manager y contiene un JSON plano con claves como:

- `JWT_SECRET`
- `INTERNAL_SERVICE_KEY`
- `IDENTITY_DB_URL`
- `IDENTITY_DB_USER`
- `IDENTITY_DB_PASSWORD`
- `CUSTOMER_DB_URL`
- `CUSTOMER_DB_USER`
- `CUSTOMER_DB_PASSWORD`
- `ADMIN_DB_URL`
- `ADMIN_DB_USER`
- `ADMIN_DB_PASSWORD`
- `ACCOUNTING_DB_URL`
- `ACCOUNTING_DB_USER`
- `ACCOUNTING_DB_PASSWORD`
- `ACCOUNT_DB_URL`
- `ACCOUNT_DB_USER`
- `ACCOUNT_DB_PASSWORD`
- `NOTIFICATION_DB_URL`
- `NOTIFICATION_DB_USERNAME`
- `NOTIFICATION_DB_PASSWORD`
- `MONGODB_URI`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `IDENTITY_DEMO_PASSWORD`

### 2. Autenticacion desde Kubernetes hacia GCP

Kubernetes no usa archivos JSON de credenciales.
En su lugar usa `Workload Identity`.

La `Kubernetes Service Account` es:

- `banquito-core-apps`

Esta anotada para usar la `Google Service Account`:

- `banquiro-secret@banquitog2-p3.iam.gserviceaccount.com`

Archivo relevante:

- `k8s/serviceaccount.yaml`

### 3. Lectura del secreto desde Kubernetes

`External Secrets Operator` esta instalado en el cluster y usa:

- `SecretStore`: `banquito-core-secret-store`
- `ExternalSecret`: `core-secrets`

Definido en:

- `k8s/externalsecret.yaml`

El flujo es:

1. `SecretStore` se autentica con Google Secret Manager usando Workload Identity
2. `ExternalSecret` lee el secreto remoto `core`
3. Kubernetes materializa un `Secret` interno llamado:
   - `core-secrets`

### 4. Consumo de secretos por los pods

Cada deployment usa:

- `envFrom.configMapRef: banquito-core-config`
- `envFrom.secretRef: core-secrets`

Esto permite que las variables sensibles entren al contenedor como variables de entorno normales.

## Como se esta manejando la configuracion no sensible

La configuracion no sensible esta en un `ConfigMap` llamado:

- `banquito-core-config`

Archivo:

- `k8s/configmap.yaml`

Ejemplos de valores ahi:

- puertos HTTP y gRPC
- `SPRING_PROFILES_ACTIVE=docker`
- `APP_TIME_ZONE`
- `APP_TIMEZONE`
- flags de Flyway/JPA
- rutas Swagger/OpenAPI
- URLs internas entre servicios
- configuracion de Mailpit
- configuracion de notificaciones
- valores de demo no sensibles

## Comunicacion entre servicios

La comunicacion interna dentro del cluster se hace usando `Service` de Kubernetes.

Ejemplos:

- `http://banquito-core-admin-3p:8083`
- `http://banquito-core-notificaciones-3p:8087`
- `banquito-core-clientes-3p:9092`
- `banquito-core-contable-3p:9094`
- `banquito-core-documentos-3p:9096`

Esto reemplaza la comunicacion que antes se hacia en Docker Compose por nombre de contenedor.

## Ingress actual

Existe un `Ingress` publico:

- `banquito-core-ingress`

IP publica actual:

- `136.68.235.162`

Archivo:

- `k8s/ingress.yaml`

### Rutas expuestas actualmente

El `Ingress` enruta por prefijo:

- `/api/v1/identity` -> seguridad
- `/api/v1/auth` -> seguridad
- `/api/v1/iam` -> seguridad
- `/api/v1/onboarding` -> seguridad
- `/api/v1/customers` -> clientes
- `/api/v1/admin` -> admin
- `/api/v1/accounting` -> contable
- `/api/v1/accounts` -> transaccional
- `/api/v1/teller` -> transaccional
- `/api/v1/switch-core` -> transaccional
- `/api/v1/documents` -> documentos
- `/api/v1/notifications` -> notificaciones
- `/mailpit` -> mailpit

### Observacion importante sobre Mailpit

El `Ingress` enruta `/mailpit` hacia el servicio `mailpit`, pero Mailpit realmente sirve la UI en `/`.
Como el `Ingress` actual no hace rewrite de path, `http://136.68.235.162/mailpit` puede devolver `404`.

## Particularidades actuales del despliegue

### 1. Un pod base por servicio

Cada deployment esta configurado para iniciar con:

- `replicas: 1`

Actualmente estos servicios tienen autoscaling horizontal adicional:

- `banquito-core-seguridad-3p`
- `banquito-core-clientes-3p`
- `banquito-core-admin-3p`
- `banquito-core-transaccional-3p`

Todos quedaron configurados para:

- inicia en `1` replica
- crear replicas extra solo cuando la CPU promedio supera el umbral definido
- vuelve a bajar a `1` replica cuando la carga disminuye

Archivos relevantes:

- `k8s/core/hpa-seguridad.yaml`
- `k8s/core/hpa-clientes.yaml`
- `k8s/core/hpa-admin.yaml`
- `k8s/core/hpa-transaccional.yaml`

Ademas se cambio la estrategia a:

- `strategy.type: Recreate`

Esto evita rollouts con multiples pods simultaneos y mantiene el patron de "un pod por servicio".

### 2. Servicio de documentos

`banquito-core-documentos-3p` presento problemas porque el `MongoHealthIndicator` marcaba `DOWN` aunque la aplicacion si arrancaba.

Ajustes realizados:

- se agrego:
  - `MANAGEMENT_HEALTH_MONGO_ENABLED=false`
- se cambiaron los probes de HTTP a `tcpSocket`
- se agrego un `BackendConfig` de GKE para que el health check del Ingress use `GET /api-docs`, evitando que el backend quede `unhealthy` por el `MongoHealthIndicator`

Archivo relevante:

- `k8s/deployment-documentos.yaml`
- `k8s/backendconfig-documentos.yaml`

Con esto el pod ya queda `1/1`.

### 3. Servicio de seguridad

`banquito-core-seguridad-3p` necesito variables explicitas como:

- `SPRING_APPLICATION_NAME`
- `SERVER_PORT`
- `DEMO_DATA_ENABLED`
- `DEMO_PASSWORD`

Estas quedaron declaradas explicitamente en:

- `k8s/deployment-seguridad.yaml`

## Persistencia

El servicio contable usa almacenamiento persistente para reportes:

- `PersistentVolumeClaim`: `accounting-reports-pvc`

Montado en:

- `/reports/eod`

Archivo:

- `k8s/pvc-accounting-reports.yaml`

## Validacion actual del cluster

Recursos activos esperados en `banquito-core`:

- Pods de 8 servicios en `Running`
- Services internos para cada microservicio
- `Ingress` con IP publica
- `SecretStore` en `Valid`
- `ExternalSecret` en `SecretSynced`
- `Secret` de Kubernetes `core-secrets`
- `ConfigMap` `banquito-core-config`
- `PVC` para contable

## Como se despliega

Desde `core/backend`:

```powershell
kubectl apply -k k8s
```

## Como se valida

### Recursos del namespace

```powershell
kubectl get pods,svc,ingress,externalsecret,secretstore -n banquito-core
```

### Verificacion de pods

```powershell
kubectl get pods -n banquito-core
```

### Logs de un servicio

```powershell
kubectl logs deployment/banquito-core-seguridad-3p -n banquito-core
kubectl logs deployment/banquito-core-documentos-3p -n banquito-core
```

### Verificacion del secreto sincronizado

```powershell
kubectl get externalsecret core-secrets -n banquito-core
kubectl describe externalsecret core-secrets -n banquito-core
kubectl get secret core-secrets -n banquito-core
```

## Pruebas funcionales actuales

La IP publica del `Ingress` es:

- `http://136.68.235.162`

Pruebas validas:

- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/admin/metrics`
- `GET /api/v1/customers/subtypes`
- `GET /api/v1/accounting/accounting-dates/current`
- `GET /api/v1/documents/types`
- `GET /api/v1/notifications/templates`
- `GET /api/v1/accounts`

## Observaciones pendientes

- `BANQUITO_CUSTOMER_ACTIVATION_BASE_URL` sigue con placeholder y debe apuntar al frontend real
- `mailpit` por `Ingress` requiere reconsiderar rewrite o una exposicion dedicada si se quiere UI accesible en una ruta amigable
- el `Ingress` usa la anotacion `kubernetes.io/ingress.class: gce`, que ya es un enfoque legacy frente a `ingressClassName`
- los health checks por `Ingress` no estan expuestos como rutas publicas directas

## Estado general

El despliegue del core en GKE esta funcional para los siete microservicios y Mailpit, con secretos sincronizados desde Google Secret Manager mediante Workload Identity y External Secrets, y exposicion HTTP publica mediante un unico `Ingress` path-based.
