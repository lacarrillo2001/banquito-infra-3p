# Arquitectura Banquito Core v2

## Resumen Ejecutivo

Migración de infraestructura on-premise/VMs a servicios nativos de Google Cloud Platform (GCP). Se eliminan dependencias de Kong y RabbitMQ, reemplazándolos por Apigee X y Cloud Pub/Sub respectivamente. Las bases de datos migran de VMs a Cloud SQL. Los frontends se unifican en un cluster GKE independiente.

---

## Diagrama de Despliegue

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              GOOGLE CLOUD PLATFORM                                                │
│                                                                                                   │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                                           │   │
│  │                        APIGEE X (API Management)                                          │   │
│  │                                                                                           │   │
│  │  Rol: API Gateway único para toda la plataforma                                           │   │
│  │                                                                                           │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐    │   │
│  │  │  PreFlow (se ejecuta en toda petición):                                            │    │   │
│  │  │    ├── CORS-Policy      → Responde preflight OPTIONS (204)                        │    │   │
│  │  │    └── Spike-Arrest     → Protección DDoS (30 req/s)                              │    │   │
│  │  │                                                                                     │    │   │
│  │  │  Flujos públicos (sin VerifyJWT):                                                  │    │   │
│  │  │    ├── POST /api/v1/auth/login        → identity-access-service:8081              │    │   │
│  │  │    ├── POST /api/v1/auth/refresh      → identity-access-service:8081              │    │   │
│  │  │    ├── POST /api/v1/auth/forgot-password → identity-access-service:8081           │    │   │
│  │  │    ├── POST /api/v1/auth/reset-password → identity-access-service:8081            │    │   │
│  │  │    └── POST /api/v1/auth/activate-account → identity-access-service:8081          │    │   │
│  │  │                                                                                     │    │   │
│  │  │  Flujos protegidos (VerifyJWT + Route):                                            │    │   │
│  │  │    ├── /api/v1/admin/*              → core-admin-service:8083                     │    │   │
│  │  │    ├── /api/v1/customers/*          → core-customer-service:8082                  │    │   │
│  │  │    ├── /api/v1/accounts/*           → core-account-service:8085                   │    │   │
│  │  │    ├── /api/v1/teller/*             → core-account-service:8085                   │    │   │
│  │  │    ├── /api/v1/accounting/*         → core-accounting-service:8084                │    │   │
│  │  │    ├── /api/v1/iam/*                → identity-access-service:8081                │    │   │
│  │  │    ├── /api/v1/onboarding/*         → identity-access-service:8081                │    │   │
│  │  │    ├── /api/v1/documents/*          → document-service:8086                       │    │   │
│  │  │    ├── /api/v1/notifications/*      → notification-service:8087                   │    │   │
│  │  │    ├── /api/v1/batches/*            → batch-service:8016                          │    │   │
│  │  │    ├── /api/v1/switch-core/*        → core-account-service:8085                   │    │   │
│  │  │    ├── /api/v1/billing/*            → billing-service:8084                        │    │   │
│  │  │    ├── /api/v1/reports/*            → reporting-service:8019                      │    │   │
│  │  │    └── /api/v1/sftp/*               → sftp-service:8090                           │    │   │
│  │  │                                                                                     │    │   │
│  │  │  Target Servers via Private Service Connect (PSC):                                  │    │   │
│  │  │    Core:   <service>.banquito-core.svc.cluster.local:<port>                         │    │   │
│  │  │    Switch: <service>.banquito-switch.svc.cluster.local:<port>                       │    │   │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘    │   │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                   │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                                           │   │
│  │              GOOGLE CLOUD PUB/SUB (Bus de Eventos Asíncrono)                              │   │
│  │                                                                                           │   │
│  │  Reemplaza a RabbitMQ. Comunicación basada en eventos entre servicios.                   │   │
│  │                                                                                           │   │
│  │  ┌──────────────────────────┬──────────────────────────┬──────────────────────────┐       │   │
│  │  │                          │                          │                          │       │   │
│  │  │  core-account-events     │  core-customer-events    │  core-notification-events│       │   │
│  │  │                          │                          │                          │       │   │
│  │  │  Publican:               │  Publican:               │  Publican:               │       │   │
│  │  │  ├── Account Service     │  ├── Customer Service    │  ├── Account Service     │       │   │
│  │  │  └── Accounting Service  │  └── Switch Services     │  ├── Accounting Service  │       │   │
│  │  │                          │                          │  ├── Admin Service       │       │   │
│  │  │  Escuchan:               │  Escuchan:               │  └── Switch Services     │       │   │
│  │  │  ├── Accounting Service  │  ├── Identity Service    │                          │       │   │
│  │  │  ├── Notification Service│  └── Admin Service       │  Escucha:                │       │   │
│  │  │  └── Document Service    │                          │  └── Notification Service│       │   │
│  │  └──────────────────────────┴──────────────────────────┴──────────────────────────┘       │   │
│  │                                                                                           │   │
│  │  ┌──────────────────────────┬────────────────────────────────────────────────────────┐    │   │
│  │  │                          │                                                         │    │   │
│  │  │  switch-batch-events     │  cross-domain-events (Core ↔ Switch)                   │    │   │
│  │  │                          │                                                         │    │   │
│  │  │  Publican:               │  Eventos que requieren coordinación entre ambos dominios│    │   │
│  │  │  ├── Batch Service       │  ├── Transacciones que afectan contabilidad del Core    │    │   │
│  │  │  ├── On-Us Settlement    │  ├── Clientes creados desde Switch                      │    │   │
│  │  │  └── Billing Service     │  └── Notificaciones originadas en Switch                │    │   │
│  │  │                          │                                                         │    │   │
│  │  │  Escuchan:               │                                                         │    │   │
│  │  │  ├── Billing Service     │  Suscripciones: servicios de Core y Switch              │    │   │
│  │  │  ├── Reporting Service   │                                                         │    │   │
│  │  │  └── SFTP Service        │                                                         │    │   │
│  │  └──────────────────────────┴────────────────────────────────────────────────────────┘    │   │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                   │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                                           │   │
│  │  ┌─────────────────────────────────────────┐  ┌─────────────────────────────────────────┐ │   │
│  │  │                                         │  │                                         │ │   │
│  │  │  GKE Cluster 1: banquito-core            │  │  GKE Cluster 2: banquito-switch          │ │   │
│  │  │                                         │  │                                         │ │   │
│  │  │  Namespace: banquito-core                │  │  Namespace: banquito-switch              │ │   │
│  │  │  Tipo servicios: ClusterIP               │  │  Tipo servicios: ClusterIP               │ │   │
│  │  │  Conexión: solo vía Apigee (PSC)         │  │  Conexión: solo vía Apigee (PSC)         │ │   │
│  │  │                                         │  │                                         │ │   │
│  │  │  ┌─────────────┐ ┌─────────────┐       │  │  ┌──────────────┐ ┌──────────────┐      │ │   │
│  │  │  │ Identity    │ │ Customer    │       │  │  │ Batch Service│ │ On-Us        │      │ │   │
│  │  │  │ Access Svc  │ │ Service     │       │  │  │ :8016        │ │ Settlement   │      │ │   │
│  │  │  │ :8081       │ │ :8082       │       │  │  │              │ │ :8083        │      │ │   │
│  │  │  └──────┬──────┘ └──────┬──────┘       │  │  └──────┬───────┘ └──────┬───────┘      │ │   │
│  │  │         │               │               │  │         │               │              │ │   │
│  │  │  ┌──────┴──────┐ ┌──────┴──────┐       │  │  ┌──────┴───────┐ ┌──────┴───────┐      │ │   │
│  │  │  │ Admin Svc   │ │ Account Svc │       │  │  │ Billing Svc  │ │ Report Svc   │      │ │   │
│  │  │  │ :8083       │ │ :8085       │       │  │  │ :8084        │ │ :8019        │      │ │   │
│  │  │  └──────┬──────┘ └──────┬──────┘       │  │  └──────┬───────┘ └──────┬───────┘      │ │   │
│  │  │         │               │               │  │         │               │              │ │   │
│  │  │  ┌──────┴──────┐ ┌──────┴──────┐       │  │  ┌──────┴───────┐ ┌──────┴───────┐      │ │   │
│  │  │  │ Accounting  │ │ Document    │       │  │  │ SFTP Svc     │ │ RabbitMQ     │      │ │   │
│  │  │  │ Svc :8084   │ │ Svc :8086   │       │  │  │ :2222 / :8090│ │ :15672       │      │ │   │
│  │  │  └──────┬──────┘ └──────┬──────┘       │  │  └──────────────┘ └──────────────┘      │ │   │
│  │  │         │               │               │  │                                         │ │   │
│  │  │  ┌──────┴──────┐ ┌──────┴──────┐       │  │  Sidecars:                              │ │   │
│  │  │  │ Notification│ │ Mailpit     │       │  │  ├── Cloud SQL Auth Proxy (PostgreSQL)   │ │   │
│  │  │  │ Svc :8087   │ │ :8025       │       │  │  └── Pub/Sub Subscriber                  │ │   │
│  │  │  └─────────────┘ └─────────────┘       │  │                                         │ │   │
│  │  │                                         │  │                                         │ │   │
│  │  │  Sidecars:                              │  │  Comunicación con Core:                  │ │   │
│  │  │  ├── Cloud SQL Auth Proxy (MySQL)       │  │  ├── Síncrona → Apigee REST             │ │   │
│  │  │  └── Pub/Sub Subscriber                 │  │  └── Asíncrona → Pub/Sub                │ │   │
│  │  └─────────────────────────────────────────┘  └─────────────────────────────────────────┘ │   │
│  │                                                                                           │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │                                                                                   │   │   │
│  │  │  GKE Cluster 3: banquito-frontends                                                 │   │   │
│  │  │                                                                                   │   │   │
│  │  │  Namespace: banquito-frontends                                                     │   │   │
│  │  │  Tipo servicios: ClusterIP + Ingress (Cloud Load Balancer)                        │   │   │
│  │  │  Comunicación: exclusivamente con Apigee (NUNCA directo a backends)               │   │   │
│  │  │                                                                                   │   │   │
│  │  │  ┌──────────────────────────┐  ┌──────────────────────────┐                      │   │   │
│  │  │  │  Core Banca Web          │  │  Core Ventanilla          │                      │   │   │
│  │  │  │  Puerto: 3000            │  │  Puerto: 3001             │                      │   │   │
│  │  │  │  Framework: React + Vite  │  │  Framework: React + Vite  │                      │   │   │
│  │  │  │  VITE_API_BASE_URL =     │  │  VITE_API_BASE_URL =     │                      │   │   │
│  │  │  │  https://apigee.banquito │  │  https://apigee.banquito │                      │   │   │
│  │  │  │  .com/api/v1             │  │  .com/api/v1             │                      │   │   │
│  │  │  └──────────────────────────┘  └──────────────────────────┘                      │   │   │
│  │  │                                                                                   │   │   │
│  │  │  ┌──────────────────────────────────────────────────────────────────────────┐    │   │   │
│  │  │  │  Switch Frontend                                                          │    │   │   │
│  │  │  │  Puerto: 3002                                                             │    │   │   │
│  │  │  │  Framework: React + Vite                                                  │    │   │   │
│  │  │  │  VITE_API_BASE_URL = https://apigee.banquito.com/api/v1                   │    │   │   │
│  │  │  │  VITE_CORE_KONG_BASE_URL = https://apigee.banquito.com/api/v1             │    │   │   │
│  │  │  └──────────────────────────────────────────────────────────────────────────┘    │   │   │
│  │  │                                                                                   │   │   │
│  │  │  Ingress: Cloud Load Balancer (GCE) con HTTPS + SSL Certificate                  │   │   │
│  │  │  Dominio: *.banquito.com                                                          │   │   │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │   │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                   │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                                           │   │
│  │  ┌────────────────────────────────────────────┐  ┌────────────────────────────────────┐   │   │
│  │  │  Cloud SQL - MySQL                         │  │  Cloud SQL - PostgreSQL             │   │   │
│  │  │  Instancia: banquito-core-db                │  │  Instancia: banquito-switch-db       │   │   │
│  │  │  Motor: MySQL 8.0                          │  │  Motor: PostgreSQL 15                │   │   │
│  │  │  Storage: 100GB SSD (configurable)         │  │  Storage: 50GB SSD (configurable)   │   │   │
│  │  │  Conexión: Cloud SQL Auth Proxy (sidecar)  │  │  Conexión: Cloud SQL Auth Proxy     │   │   │
│  │  │                                            │  │            (sidecar)                  │   │   │
│  │  │  Databases:                                │  │                                      │   │   │
│  │  │  ├── core_identity_access_db               │  │  Databases:                          │   │   │
│  │  │  ├── core_customer_db                      │  │  ├── switch_batch_db                 │   │   │
│  │  │  ├── core_admin_db                         │  │  ├── switch_settlement_db            │   │   │
│  │  │  ├── core_account_db                       │  │  ├── switch_billing_db               │   │   │
│  │  │  ├── core_accounting_db                    │  │  ├── switch_reporting_db              │   │   │
│  │  │  └── core_notification_db                  │  │  ├── switch_sftp_db                  │   │   │
│  │  │                                            │  │  └── switch_api_gateway_db           │   │   │
│  │  │  Red: VPC compartida con GKE clusters       │  │                                      │   │   │
│  │  └────────────────────────────────────────────┘  │  Red: misma VPC que Core + GKE       │   │   │
│  │                                                  └────────────────────────────────────┘   │   │
│  │                                                                                           │   │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────┐    │   │
│  │  │                                                                                   │    │   │
│  │  │  MongoDB Atlas                                                                    │    │   │
│  │  │                                                                                   │    │   │
│  │  │  Cluster: core-document-cluster                                                   │    │   │
│  │  │  Database: core_document_db                                                        │    │   │
│  │  │  Proveedor: MongoDB Atlas (SaaS)                                                  │    │   │
│  │  │  Accesible desde: GKE Cluster 1 (banquito-core) — document-service                │    │   │
│  │  │  Colecciones: invoices, statements, contracts, supporting-documents               │    │   │
│  │  │                                                                                   │    │   │
│  │  │  Conexión: cadena de conexión estándar MongoDB + whitelist de IPs de GKE          │    │   │
│  │  └──────────────────────────────────────────────────────────────────────────────────┘    │   │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                   │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Flujos de Comunicación

### 1. Flujo Síncrono (REST HTTPS)

Toda comunicación síncrona entre frontends y backends (Core o Switch) pasa por Apigee.

```
  ┌──────────────┐     ┌──────────┐     ┌──────────────────┐     ┌──────────────────┐
  │  Frontend    │────▶│  APIGEE  │────▶│  GKE Cluster     │────▶│  Cloud SQL /     │
  │  (Cluster 3) │     │          │     │  (Core o Switch)  │     │  MongoDB         │
  │              │◀────│          │◀────│                   │◀────│                  │
  │  localhost   │     │  ✅ CORS │     │  ClusterIP        │     │  (datos)         │
  │  o dominio   │     │  ✅ JWT  │     │  vía PSC          │     │                  │
  └──────────────┘     └──────────┘     └──────────────────┘     └──────────────────┘
```

**Pasos:**
1. Frontend envía petición HTTPS a Apigee (incluyendo token JWT si es ruta protegida)
2. Apigee ejecuta PreFlow: CORS (responde OPTIONS inmediatamente) + SpikeArrest
3. Si la ruta es protegida, Apigee valida el JWT con VerifyJWT
4. Apigee enruta la petición al Target Server correspondiente vía PSC
5. El microservicio en GKE procesa la petición (lectura/escritura a Cloud SQL o MongoDB)
6. La respuesta regresa por la misma ruta

### 2. Flujo Asíncrono (Pub/Sub)

Comunicación basada en eventos entre servicios, reemplaza a RabbitMQ.

```
  ┌──────────────────┐     ┌──────────────────────────┐     ┌──────────────────┐
  │  Servicio Origen  │────▶│  Google Cloud Pub/Sub    │────▶│  Servicio        │
  │  (publicador)     │     │  (topic)                  │     │  (suscriptor)    │
  │                   │     │                           │     │                  │
  │  Account Svc      │     │  core-account-events      │     │  Accounting Svc  │
  │  (depósito creado)│     │                           │     │  (crea asiento)  │
  └──────────────────┘     └──────────────────────────┘     └──────────────────┘
```

**Casos de uso:**
| Evento | Publicador | Suscriptores | Propósito |
|---|---|---|---|
| Transacción creada | Account Service | Accounting, Notification, Document | Crear asiento contable, enviar comprobante, guardar documento |
| Cliente actualizado | Customer Service | Identity, Admin | Sincronizar datos de cliente en IAM |
| Lote procesado | Batch Service | Billing, Report, SFTP | Facturar, generar reportes, enviar archivo |
| Notificación solicitada | Cualquier servicio | Notification Service | Enviar email o SMS |

### 3. Flujo Cruzado (Switch ↔ Core)

El Switch Backend se comunica con el Core de la misma forma que los frontends: a través de Apigee.

```
  ┌──────────────────┐     ┌──────────┐     ┌──────────────────┐
  │  Switch Service  │────▶│  APIGEE  │────▶│  Core Service    │
  │  (GKE Cluster 2) │     │          │     │  (GKE Cluster 1) │
  │                  │     │          │     │                  │
  │  Batch Svc       │     │  Rutea   │     │  Account Svc     │
  │  (validar cuenta)│     │  /api/..  │     │  (responde)      │
  └──────────────────┘     └──────────┘     └──────────────────┘
```

Esto mantiene el mismo patrón que usaba Switch con Kong, pero ahora vía Apigee.

---

## Componentes y Responsabilidades

### Apigee X (API Gateway)

| Característica | Detalle |
|---|---|
| **Tipo** | SaaS (Google Cloud Apigee X) |
| **Función principal** | API Gateway, seguridad, ruteo | 
| **CORS** | Política declarativa en PreFlow |
| **Autenticación** | VerifyJWT con HMAC-SHA256 (mismo secreto que security-service) |
| **Rate Limiting** | SpikeArrest (30 req/s global) + Quota por ruta |
| **Ruteo** | Basado en path prefix a Target Servers en GKE |
| **Conexión a backends** | Private Service Connect (PSC) |
| **TLS** | HTTPS terminado en Apigee |

### Google Cloud Pub/Sub (Mensajería)

| Característica | Detalle |
|---|---|
| **Tipo** | SaaS (Google Cloud Pub/Sub) |
| **Reemplaza** | RabbitMQ (Switch) + comunicación HTTP interna |
| **Garantía** | At-least-once delivery |
| **Integración** | Spring Cloud GCP Pub/Sub Starter |
| **Topics** | account-events, customer-events, notification-events, batch-events, cross-domain-events |

### GKE Cluster 1 — banquito-core

| Microservicio | Puerto | Base de Datos | Propósito |
|---|---|---|---|
| identity-access-service | 8081 | Cloud SQL (core_identity_access_db) | Login, JWT, IAM, Onboarding |
| core-customer-service | 8082 | Cloud SQL (core_customer_db) | Clientes bancarios |
| core-admin-service | 8083 | Cloud SQL (core_admin_db) | Catálogos, sucursales, audit |
| core-accounting-service | 8084 | Cloud SQL (core_accounting_db) | Contabilidad, asientos, EOD |
| core-account-service | 8085 | Cloud SQL (core_account_db) | Cuentas, transacciones, teller |
| document-service | 8086 | MongoDB Atlas (core_document_db) | Documentos, comprobantes |
| notification-service | 8087 | Cloud SQL (core_notification_db) | Notificaciones email/SMS |
| mailpit | 8025 | — | Email testing (desarrollo) |

Todos los servicios son tipo **ClusterIP**. Su única vía de acceso externo es Apigee mediante Private Service Connect (PSC).

### GKE Cluster 2 — banquito-switch

| Microservicio | Puerto | Base de Datos | Propósito |
|---|---|---|---|
| batch-service | 8016 | Cloud SQL PG (switch_batch_db) | Procesamiento de lotes |
| on-us-settlement-service | 8083 | Cloud SQL PG (switch_settlement_db) | Pagos internos |
| billing-service | 8084 | Cloud SQL PG (switch_billing_db) | Facturación |
| reporting-service | 8019 | Cloud SQL PG (switch_reporting_db) | Reportes |
| sftp-service | 8090 / 2222 | Cloud SQL PG (switch_sftp_db) | Transferencia archivos SFTP |
| RabbitMQ | 15672 / 5672 | — | Mensajería interna (se mantiene hasta migración total a Pub/Sub) |

La comunicación con Core se realiza exclusivamente vía Apigee (REST síncrono) y Pub/Sub (eventos asíncronos).

### GKE Cluster 3 — banquito-frontends

| Frontend | Puerto | Framework | API Base URL |
|---|---|---|---|
| Core Banca Web | 3000 | React + Vite | `https://apigee.banquito.com/api/v1` |
| Core Ventanilla | 3001 | React + Vite | `https://apigee.banquito.com/api/v1` |
| Switch Frontend | 3002 | React + Vite | `https://apigee.banquito.com/api/v1` |

Ningún frontend tiene acceso directo a los clusters de backend. Todo el tráfico pasa por Apigee.

### Cloud SQL — MySQL (Core)

| Propiedad | Valor |
|---|---|
| **Instancia** | `banquito-core-db` |
| **Motor** | MySQL 8.0 |
| **Bases de datos** | 6 |
| **Conexión** | Cloud SQL Auth Proxy (sidecar en cada pod) |
| **Ubicación** | Misma región que GKE clusters |

### Cloud SQL — PostgreSQL (Switch)

| Propiedad | Valor |
|---|---|
| **Instancia** | `banquito-switch-db` |
| **Motor** | PostgreSQL 15 |
| **Bases de datos** | 6 |
| **Conexión** | Cloud SQL Auth Proxy (sidecar en cada pod) |
| **Ubicación** | Misma región que GKE clusters |

### MongoDB Atlas

| Propiedad | Valor |
|---|---|
| **Cluster** | `core-document-cluster` |
| **Base de datos** | `core_document_db` |
| **Acceso** | Document Service en GKE Cluster 1 |
| **Conexión** | Cadena MongoDB estándar + IP whitelist |

---

## Seguridad

| Aspecto | Implementación |
|---|---|
| **Autenticación externa** | JWT validado por Apigee (VerifyJWT) |
| **Autenticación interna (gRPC)** | InternalServiceKey (shared secret) — sin cambios |
| **CORS** | Apigee PreFlow (solo Apigee necesita configurarlo) |
| **DDoS** | SpikeArrest en Apigee (30 req/s) |
| **Rate Limiting** | Quota policy en Apigee por tipo de endpoint |
| **Conexión a DBs** | Cloud SQL Auth Proxy (IAM-based auth) + sidecar |
| **TLS** | Terminado en Apigee (frontends) y en Ingress (frontends cluster) |
| **Red** | Private Service Connect (Apigee → GKE), sin IPs públicas en backends |

---

## Comparativa: Arquitectura Anterior vs Nueva

| Componente | Anterior | Nueva | Beneficio |
|---|---|---|---|
| **API Gateway** | Kong (VM) + GCE Ingress (GKE) | Apigee X (SaaS) | Zero operations, CORS centralizado, JWT gateway-level |
| **CORS** | Kong (no usado por frontends) | Apigee PreFlow | Funciona siempre, sin configuración en backends |
| **Mensajería** | RabbitMQ (VM) | Cloud Pub/Sub | Serverless, escalable, integración nativa GCP |
| **Base de datos Core** | MySQL en VM (34.136.2.91) | Cloud SQL MySQL | Managed, backups automáticos, alta disponibilidad |
| **Base de datos Switch** | PostgreSQL local (Docker) | Cloud SQL PostgreSQL | Managed, backups automáticos, alta disponibilidad |
| **Cluster Core** | GKE (con GCE Ingress externo) | GKE (ClusterIP + PSC) | Sin exposición pública directa |
| **Cluster Switch** | Docker Compose (VM) | GKE (ClusterIP + PSC) | Orquestación, escalabilidad, misma plataforma |
| **Frontends** | Docker Compose (VM) | GKE (Ingress + HTTPS) | Unificado, SSL centralizado, escalable |
| **Infraestructura** | VMs manuales, SSH, Docker Compose | GCP Managed Services + GKE | Menos operación, más automatización |

---

## Netografía (conexiones entre componentes)

```
Frontends (GKE Cluster 3)
  └── HTTPS ──▶ Apigee ── PSC ──▶ GKE Cluster 1 (Core)
  └── HTTPS ──▶ Apigee ── PSC ──▶ GKE Cluster 2 (Switch)
  └── HTTPS ──▶ Cloud Load Balancer (para servir las SPA)

Core (GKE Cluster 1)
  ├── Cloud SQL Auth Proxy ──▶ Cloud SQL MySQL (banquito-core-db)
  ├── MongoDB driver ────────▶ MongoDB Atlas
  ├── Pub/Sub client ────────▶ Google Cloud Pub/Sub
  └── gRPC ─────────────────▶ Servicios Core (comunicación interna)

Switch (GKE Cluster 2)
  ├── Cloud SQL Auth Proxy ──▶ Cloud SQL PostgreSQL (banquito-switch-db)
  ├── HTTPS ────────────────▶ Apigee ── PSC ──▶ Core (GKE Cluster 1)
  ├── Pub/Sub client ────────▶ Google Cloud Pub/Sub
  └── RabbitMQ ──────────────▶ Switch services (comunicación interna)

Apigee
  ├── PSC ──────────────────▶ identity-access-service.banquito-core.svc.cluster.local:8081
  ├── PSC ──────────────────▶ core-customer-service.banquito-core.svc.cluster.local:8082
  ├── PSC ──────────────────▶ core-admin-service.banquito-core.svc.cluster.local:8083
  ├── PSC ──────────────────▶ core-accounting-service.banquito-core.svc.cluster.local:8084
  ├── PSC ──────────────────▶ core-account-service.banquito-core.svc.cluster.local:8085
  ├── PSC ──────────────────▶ document-service.banquito-core.svc.cluster.local:8086
  ├── PSC ──────────────────▶ notification-service.banquito-core.svc.cluster.local:8087
  ├── PSC ──────────────────▶ batch-service.banquito-switch.svc.cluster.local:8016
  ├── PSC ──────────────────▶ on-us-settlement-service.banquito-switch.svc.cluster.local:8083
  ├── PSC ──────────────────▶ billing-service.banquito-switch.svc.cluster.local:8084
  ├── PSC ──────────────────▶ reporting-service.banquito-switch.svc.cluster.local:8019
  └── PSC ──────────────────▶ sftp-service.banquito-switch.svc.cluster.local:8090
```
