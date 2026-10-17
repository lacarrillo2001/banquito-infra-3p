# GKE deploy

1. Instala External Secrets Operator en el cluster.
2. Crea una GSA con acceso `roles/secretmanager.secretAccessor` al secreto `core`.
3. Verifica que `k8s/serviceaccount.yaml` apunte a `banquiro-secret@banquitog2-p3.iam.gserviceaccount.com`.
4. Verifica que `k8s/externalsecret.yaml` use `clusterName: banquito-cluster`.
5. El `Ingress` enruta por path y no requiere hosts dedicados.
6. Aplica con `kubectl apply -k k8s`.

El secreto `core` debe existir en Google Secret Manager como JSON plano para que `ExternalSecret` pueda extraer sus claves y crear el `Secret` de Kubernetes `core-secrets`.

Todos los recursos se despliegan en un unico namespace: `banquito-core`.

Antes de desplegar, actualiza `BANQUITO_CUSTOMER_ACTIVATION_BASE_URL` en `k8s/configmap.yaml` con la URL real del frontend, porque `localhost` no sirve dentro de GKE.
