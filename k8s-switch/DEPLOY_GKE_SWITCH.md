# Deploy del Switch en GKE

## Resumen

El switch se despliega en un namespace separado del core:

- `banquito-switch`

La comunicacion obligatoria hacia el core es:

- `Switch -> Google Cloud API Gateway -> Core`

El switch nunca debe consumir `Service` internos del namespace `banquito-core`.

## Archivos base

La base del despliegue esta en:

- `k8s-switch/`

Recursos principales:

- `namespace.yaml`
- `serviceaccount.yaml`
- `configmap.yaml`
- `externalsecret.yaml`
- `deployment-lotes.yaml`
- `deployment-pagos-internos.yaml`
- `deployment-pagos-externos.yaml`
- `deployment-facturacion.yaml`
- `deployment-reportes.yaml`
- `deployment-sftp.yaml`
- `ingress.yaml`

## URL del API Gateway

Se configuro una sola URL base para Core/Auth/Notification:

- `https://banquito-gateway-42qi1h7a.uc.gateway.dev`

Variables usadas en `k8s-switch/configmap.yaml`:

- `CORE_API_GATEWAY_BASE_URL`
- `AUTH_API_GATEWAY_BASE_URL`
- `NOTIFICATION_API_GATEWAY_BASE_URL`

## Secreto remoto en Google Secret Manager

El secreto remoto esperado se llama:

- `switch`

Archivo JSON base listo para cargar:

- `k8s-switch/switch-secret-gsm.json`

## Valores que debes completar antes de cargar el secreto

Reemplaza estos placeholders en `k8s-switch/switch-secret-gsm.json`:

- `CORE_API_GATEWAY_CLIENT_SECRET`
- `NOTIFICATION_API_GATEWAY_CLIENT_SECRET`

Opcionalmente completa si aplica a tu flujo:

- `SFTP_USER_EMPRESA_SIERRAAZUL_USERNAME`
- `SFTP_USER_EMPRESA_SIERRAAZUL_COMPANY_RUC`
- `SFTP_USER_EMPRESA_SIERRAAZUL_CUSTOMER_UUID`
- `SWITCH_BILLING_FALLBACK_COMPANY_RUC`
- `SWITCH_BILLING_FALLBACK_SOURCE_ACCOUNT_NUMBER`

## Crear la Google Service Account del switch

Ejemplo recomendado:

```bash
gcloud iam service-accounts create banquito-switch-gsa `
  --display-name="Banquito Switch GKE"
```

La GSA quedaria asi:

- `banquito-switch-gsa@banquitog2-p3.iam.gserviceaccount.com`

Actualiza luego `k8s-switch/serviceaccount.yaml` con ese valor.

## Permisos IAM minimos recomendados

### Secret Manager

Para leer el secreto remoto `switch`:

```bash
gcloud secrets add-iam-policy-binding switch `
  --member="serviceAccount:banquito-switch-gsa@banquitog2-p3.iam.gserviceaccount.com" `
  --role="roles/secretmanager.secretAccessor"
```

### Pub/Sub

Para publicar y consumir eventos:

```bash
gcloud projects add-iam-policy-binding banquitog2-p3 `
  --member="serviceAccount:banquito-switch-gsa@banquitog2-p3.iam.gserviceaccount.com" `
  --role="roles/pubsub.publisher"

gcloud projects add-iam-policy-binding banquitog2-p3 `
  --member="serviceAccount:banquito-switch-gsa@banquitog2-p3.iam.gserviceaccount.com" `
  --role="roles/pubsub.subscriber"
```

Si luego necesitan administrar topics/subscriptions desde codigo, agrega tambien:

```bash
gcloud projects add-iam-policy-binding banquitog2-p3 `
  --member="serviceAccount:banquito-switch-gsa@banquitog2-p3.iam.gserviceaccount.com" `
  --role="roles/pubsub.editor"
```

## Enlazar Workload Identity

### 1. Crear la KSA en Kubernetes

La KSA ya esta definida como:

- `banquito-switch-apps`

### 2. Anotar la KSA con la GSA real

Actualiza `k8s-switch/serviceaccount.yaml` y deja:

```yaml
annotations:
  iam.gke.io/gcp-service-account: banquito-switch-gsa@banquitog2-p3.iam.gserviceaccount.com
```

### 3. Permitir que la KSA use la GSA

```bash
gcloud iam service-accounts add-iam-policy-binding `
  banquito-switch-gsa@banquitog2-p3.iam.gserviceaccount.com `
  --role="roles/iam.workloadIdentityUser" `
  --member="serviceAccount:banquitog2-p3.svc.id.goog[banquito-switch/banquito-switch-apps]"
```

## Cargar el secreto `switch`

Si no existe:

```bash
gcloud secrets create switch --replication-policy="automatic"
```

Agregar la version:

```bash
gcloud secrets versions add switch `
  --data-file="k8s-switch/switch-secret-gsm.json"
```

## Validar External Secrets Operator

El cluster debe tener `External Secrets Operator` instalado.

Verifica:

```bash
kubectl get crd externalsecrets.external-secrets.io
kubectl get crd secretstores.external-secrets.io
```

## Desplegar el switch

```bash
kubectl apply -k k8s-switch
```

## Verificaciones iniciales

```bash
kubectl get ns
kubectl get pods -n banquito-switch
kubectl get svc -n banquito-switch
kubectl get ingress -n banquito-switch
kubectl get externalsecret -n banquito-switch
kubectl get secret -n banquito-switch
```

## Verificaciones de logs

```bash
kubectl logs -n banquito-switch deploy/banquito-sw-lotes-3p
kubectl logs -n banquito-switch deploy/banquito-sw-pagos-internos-3p
kubectl logs -n banquito-switch deploy/banquito-sw-pagos-externos-3p
kubectl logs -n banquito-switch deploy/banquito-sw-facturacion-3p
kubectl logs -n banquito-switch deploy/banquito-sw-reportes-3p
kubectl logs -n banquito-switch deploy/banquito-sw-sftp-3p
```

## Puntos criticos antes de producir

- Reemplazar la GSA placeholder en `k8s-switch/serviceaccount.yaml`
- Cargar secretos reales del API Gateway client-token
- Verificar acceso real de Cloud SQL desde GKE
- Confirmar que el API Gateway permita las rutas usadas por el switch
- Revisar si el `LoadBalancer` SFTP en `2222` debe restringirse por IP o firewall
