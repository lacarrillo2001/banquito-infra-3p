# Guía: Gestión de Secretos con Google Secret Manager y Kubernetes

Este documento analiza cómo se gestionan actualmente los secretos en la infraestructura de Kubernetes de **Banquito Core** y describe el proceso detallado para implementar una arquitectura segura utilizando **Google Secret Manager** y **External Secrets Operator (ESO)**.

---

## 1. Análisis del Estado Actual

En los manifiestos actuales, los secretos globales están definidos en [global-secret.yaml](file:///c:/Users/Andresl/Documents/GitHub/Arqui_Proyecto_P2/banquito-infra/k8s/global-secret.yaml):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: banquito-global-secret
  namespace: banquito-core
type: Opaque
data:
  MYSQL_PASSWORD: QmFuUXVpdG9Sb290MjAyNiE=
  MONGODB_URI: bW9uZ29kYitzcnY6Ly9sYW5kcmVzY2EyMDAxX2RiX3VzZXI6SmI1TEl1dVFjclFIU1FXbUBjbHVzdGVyMC5oZGJrbXltLm1vbmdvZGIubmV0L2NvcmVfZG9jdW1lbnRfZGI/cmV0cnlXcml0ZXM9dHJ1ZSZ3PW1ham9yaXR5JmFwcE5hbWU9Q2x1c3RlcjA=
  # ... otros secretos
```

### Problema de Seguridad
* Los valores bajo la clave `data` están codificados en **Base64**. Esto **no es encriptación**. Cualquier persona con acceso al repositorio Git puede descifrar contraseñas sensibles (como las credenciales de bases de datos de producción) simplemente ejecutando `echo "base64_string" | base64 --decode`.
* Subir secretos en texto claro o Base64 a repositorios Git públicos o privados viola los principios de seguridad de la industria y la conformidad de auditoría.

---

## 2. Arquitectura Objetivo: Integración con Google Secret Manager

Para resolver esto de forma nativa en **Google Cloud Platform (GCP)** y **Google Kubernetes Engine (GKE)**, implementaremos el siguiente flujo:

```mermaid
graph TD
    A[Google Secret Manager] -->|Almacena llaves de forma segura| B[GCP IAM / Workload Identity]
    B -->|Autoriza lectura| C[External Secrets Operator - ESO]
    C -->|Monitorea y Sincroniza| D[K8s Secret nativo: banquito-global-secret]
    D -->|Inyecta variables de entorno| E[Microservicios Core]
```

### Ventajas:
1. **Cero cambios de código**: El microservicio seguirá leyendo el Secret nativo `banquito-global-secret`.
2. **Seguridad**: Los secretos reales nunca se guardan en el repositorio de Git.
3. **Rotación automática**: Si cambias la contraseña en Google Cloud, se sincroniza en Kubernetes sin redesplegar código o recrear pods manualmente.

---

## 3. Guía de Implementación Paso a Paso

### Paso 1: Habilitar Secret Manager en GCP
Ejecuta en tu terminal de Google Cloud SDK:
```bash
gcloud services enable secretmanager.googleapis.com --project=banquitog2-p3
```

### Paso 2: Crear los Secretos en GCP
Crea un secreto en Secret Manager llamado `banquito-global-secrets`. Puedes almacenar los secretos como un JSON estructurado para mayor facilidad de lectura:

**Nombre del Secreto en GCP:** `banquito-global-secrets`  
**Valor del secreto (JSON):**
```json
{
  "MYSQL_ROOT_PASSWORD": "Admin.1234",
  "MYSQL_PASSWORD": "BanQuitoRoot2026!",
  "MONGO_INITDB_ROOT_USERNAME": "banquito_mongo",
  "MONGO_INITDB_ROOT_PASSWORD": "BanQuitoMongo2026!",
  "JWT_SECRET": "BanQuitoIdentityJwtSecretKeyForDevelopmentOnlyChangeMe2026",
  "INTERNAL_SERVICE_KEY": "BanQuitoInternalServiceKey2026ChangeMe",
  "MONGODB_URI": "mongodb+srv://landresca2001_db_user:Jb5LIuuQcrQHSQWm@cluster0.hdbkmym.mongodb.net/core_document_db?retryWrites=true&w=majority&appName=Cluster0",
  "KONG_PG_PASSWORD": "BanQuitoKong2026!"
}
```

---

### Paso 3: Configurar Workload Identity en GKE
Workload Identity asocia una cuenta de servicio de Kubernetes (KSA) con una cuenta de servicio de Google Cloud (GSA) sin usar llaves fijas ni credenciales estáticas.

1. **Crear la cuenta de servicio de GCP (GSA):**
   ```bash
   gcloud iam service-accounts create secret-manager-reader \
       --project=banquitog2-p3
   ```

2. **Asignar permisos a la GSA para leer Secret Manager:**
   ```bash
   gcloud projects add-iam-policy-binding banquitog2-p3 \
       --member="serviceAccount:secret-manager-reader@banquitog2-p3.iam.gserviceaccount.com" \
       --role="roles/secretmanager.secretAccessor"
   ```

3. **Vincular la GSA con la Service Account de Kubernetes (KSA):**
   ```bash
   gcloud iam service-accounts add-iam-policy-binding secret-manager-reader@banquitog2-p3.iam.gserviceaccount.com \
       --role roles/iam.workloadIdentityUser \
       --member "serviceAccount:banquitog2-p3.svc.id.goog[banquito-core/eso-service-account]" \
       --project=banquitog2-p3
   ```

---

### Paso 4: Instalar External Secrets Operator (ESO) en GKE
Agrega el repositorio Helm e instálalo en el clúster:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace
```

---

### Paso 5: Definir los Manifiestos de Kubernetes
Crea los siguientes archivos YAML en la carpeta de infraestructura de tu repositorio (por ejemplo, en `k8s/secrets-config/`):

#### 1. Cuenta de Servicio de Kubernetes ([eso-sa.yaml](file:///c:/Users/Andresl/Documents/GitHub/Arqui_Proyecto_P2/banquito-infra/k8s/secrets-config/eso-sa.yaml))
Este manifiesto asocia la cuenta de servicio del clúster con la cuenta de GCP mediante la anotación de Workload Identity:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eso-service-account
  namespace: banquito-core
  annotations:
    iam.gke.io/gcp-service-account: secret-manager-reader@banquitog2-p3.iam.gserviceaccount.com
```

#### 2. Conector a Secret Manager ([secret-store.yaml](file:///c:/Users/Andresl/Documents/GitHub/Arqui_Proyecto_P2/banquito-infra/k8s/secrets-config/secret-store.yaml))
Define cómo se conecta Kubernetes a Google Secret Manager:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcp-secret-store
  namespace: banquito-core
spec:
  provider:
    gcpsm:
      projectID: banquitog2-p3
      auth:
        workloadIdentity:
          serviceAccountRef:
            name: eso-service-account
```

#### 3. Recurso External Secret ([external-secret.yaml](file:///c:/Users/Andresl/Documents/GitHub/Arqui_Proyecto_P2/banquito-infra/k8s/secrets-config/external-secret.yaml))
Este recurso define cómo se mapea el secreto de GCP (`banquito-global-secrets`) al secreto interno de Kubernetes (`banquito-global-secret`). Como el secreto en GCP es un JSON, usamos `dataFrom` para extraer las claves directamente:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: banquito-global-secret
  namespace: banquito-core
spec:
  refreshInterval: 1h # Frecuencia de sincronización automática
  secretStoreRef:
    name: gcp-secret-store
    kind: SecretStore
  target:
    name: banquito-global-secret # El nombre final del Secret que consumirán los pods
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: banquito-global-secrets
```

Una vez que apliques estos archivos al clúster (`kubectl apply -f k8s/secrets-config/`), el operador automáticamente creará `banquito-global-secret` de forma dinámica y segura. Puedes eliminar el antiguo [global-secret.yaml](file:///c:/Users/Andresl/Documents/GitHub/Arqui_Proyecto_P2/banquito-infra/k8s/global-secret.yaml) del repositorio Git.
