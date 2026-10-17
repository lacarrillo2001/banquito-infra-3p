# Configuracion del Google Cloud API Gateway para Banquito Switch

## Objetivo

Este documento define como debe configurarse `Google Cloud API Gateway` para que el sistema `switch` se comunique correctamente con `core`.

La arquitectura obligatoria es:

- `Cliente externo -> Ingress del switch -> servicios del switch`
- `Switch -> API Gateway -> Ingress del core -> servicios del core`

Reglas clave:

- El switch nunca debe llamar directamente a `Service` internos del namespace `banquito-core`
- El switch nunca debe llamar directamente a pods del core
- Toda comunicacion HTTP entre switch y core debe pasar por una sola URL base del API Gateway
- El API Gateway debe usar como backend el `Ingress` del core

## Contexto de arquitectura

El sistema esta desplegado en el mismo cluster de Kubernetes, pero en namespaces separados:

- `banquito-core`
- `banquito-switch`

Aunque ambos sistemas esten en el mismo cluster, deben mantenerse desacoplados a nivel de red aplicativa.

Eso significa que:

- el core publica sus APIs hacia el API Gateway
- el switch expone sus propias APIs hacia afuera por su propio `Ingress`
- el switch consume solo el API Gateway
- el switch no debe depender de nombres internos como:
  - `banquito-core-transaccional-3p`
  - `banquito-core-seguridad-3p`
  - `banquito-core-notificaciones-3p`

## Separacion entre Ingress del switch y API Gateway del core

Es importante no confundir estos dos componentes:

### Ingress del switch

El switch tiene su propio `Ingress` para exponer sus APIs HTTP hacia clientes externos.

Referencia actual:

- `Ingress`: `backend-sw`
- IP publica actual: `136.69.42.14`

Este `Ingress` sirve para entrar al switch, por ejemplo a rutas como:

- `/api/v1/batches`
- rutas HTTP propias del switch

### API Gateway del core

El `Google Cloud API Gateway` no existe para entrar al switch.

Su objetivo es servir como capa intermedia para que el switch consuma al core de forma desacoplada.

Referencia actual:

- URL publica del gateway: `https://banquito-gateway-42qi1h7a.uc.gateway.dev`

### Flujo correcto completo

- Cliente externo -> `Ingress del switch` -> servicios del switch
- Switch -> `API Gateway` -> `Ingress del core` -> `Service` del core correspondiente -> `Pod` del core

### Flujo incorrecto

- Cliente externo -> `API Gateway del core` -> switch
- Switch -> `Ingress del core` directo, saltandose el API Gateway
- Switch -> `Service` interno del core

## URL base unica del API Gateway

Se decidio usar una sola URL base para todas las integraciones del switch con core:

- Auth
- Core transaccional
- Notifications

URL base definida actualmente:

- `https://banquito-gateway-42qi1h7a.uc.gateway.dev`

Variables del switch alineadas a esta decision:

- `CORE_API_GATEWAY_BASE_URL`
- `AUTH_API_GATEWAY_BASE_URL`
- `NOTIFICATION_API_GATEWAY_BASE_URL`

Las tres deben apuntar a la misma URL.

## Backend real del API Gateway

El `API Gateway` no debe apuntar directamente a `Service` internos del namespace `banquito-core`.

Debe apuntar al punto de entrada HTTP ya expuesto por el core, es decir, a su `Ingress` actual.

Referencia actual del core:

- `Ingress`: `backend-core`
- IP publica actual: `136.68.235.162`

En otras palabras, el flujo correcto queda asi:

- `Switch -> API Gateway -> Ingress del core -> Service del core -> Pod del core`

El `Ingress` del core es quien se encarga de enrutar cada path al servicio interno correspondiente del core.

Ejemplo de enrutamiento dentro del `Ingress` del core:

- `/api/v1/auth/*` -> `banquito-core-seguridad-3p`
- `/api/v1/customers/*` -> `banquito-core-clientes-3p`
- `/api/v1/accounts/*` -> `banquito-core-transaccional-3p`
- `/api/v1/switch-core/*` -> `banquito-core-transaccional-3p`
- `/api/v1/notifications/*` -> `banquito-core-notificaciones-3p`

No debe quedar asi:

- `Switch -> API Gateway -> Service interno del Core`
- `Switch -> Service interno del Core`

## Que significa esto para la configuracion del gateway

El backend HTTP del `API Gateway` debe usar como upstream la entrada publica del core, actualmente:

- `http://136.68.235.162`

o el host/dominio equivalente cuando exista.

El gateway no debe intentar resolver ni conocer servicios internos de Kubernetes. Solo debe hablar con el `Ingress` del core.

Sobre ese backend, el gateway debe publicar y reenviar estas rutas sin romper el prefijo:

- `/api/v1/auth/*`
- `/api/v1/customers/*`
- `/api/v1/accounts/*`
- `/api/v1/switch-core/*`
- `/api/v1/notifications/*`

Ejemplos conceptuales:

- `https://banquito-gateway-42qi1h7a.uc.gateway.dev/api/v1/auth/client-token`
  -> backend `http://136.68.235.162/api/v1/auth/client-token`
- `https://banquito-gateway-42qi1h7a.uc.gateway.dev/api/v1/switch-core/company-account-validation`
  -> backend `http://136.68.235.162/api/v1/switch-core/company-account-validation`
- `https://banquito-gateway-42qi1h7a.uc.gateway.dev/api/v1/notifications/requests`
  -> backend `http://136.68.235.162/api/v1/notifications/requests`

## Rutas que el API Gateway debe exponer

El API Gateway debe publicar estas familias de rutas:

- `/api/v1/auth/*`
- `/api/v1/customers/*`
- `/api/v1/accounts/*`
- `/api/v1/switch-core/*`
- `/api/v1/notifications/*`

Estas rutas deben mantenerse compatibles con lo que ya espera el switch.

## Rutas especificas necesarias

### 1. Autenticacion

#### `POST /api/v1/auth/login`

Uso:

- autenticacion del servicio SFTP

Consumidor:

- `banquito-sw-sftp-3p`

Proposito:

- autenticar un usuario empresa antes de enviar o procesar archivos

#### `POST /api/v1/auth/logout`

Uso:

- cierre de sesion del flujo SFTP

Consumidor:

- `banquito-sw-sftp-3p`

Proposito:

- invalidar o cerrar sesion cuando corresponda

#### `POST /api/v1/auth/client-token`

Uso:

- obtener token tecnico para integraciones servicio a servicio

Consumidores:

- `banquito-sw-lotes-3p`
- `banquito-sw-pagos-internos-3p`
- `banquito-sw-facturacion-3p`
- `banquito-sw-reportes-3p`

Proposito:

- emitir token bearer tecnico usado para llamar endpoints del core y notificaciones

## 2. Clientes

#### `GET /api/v1/customers/by-identification/{identification}`

Uso:

- consulta de cliente o empresa por RUC o identificacion

Consumidor:

- `banquito-sw-lotes-3p`

Proposito:

- validar que la empresa exista y recuperar informacion relacionada al lote

## 3. Cuentas

#### `GET /api/v1/accounts/{accountNumber}`

Uso:

- consulta de cuenta bancaria

Consumidor:

- `banquito-sw-lotes-3p`

Proposito:

- validar que la cuenta exista y obtener datos necesarios para el procesamiento del lote

## 4. Switch Core

#### `POST /api/v1/switch-core/company-account-validation`

Uso:

- validar relacion empresa-cuenta

Consumidor:

- `banquito-sw-lotes-3p`

Proposito:

- comprobar que la empresa esta autorizada para operar con la cuenta indicada

#### `POST /api/v1/switch-core/payment-reservations`

Uso:

- crear reserva o fondeo del lote

Consumidor:

- `banquito-sw-lotes-3p`

Proposito:

- inmovilizar o reservar fondos antes de procesar pagos individuales

#### `POST /api/v1/switch-core/payment-reservations/{reservationId}/consume`

Uso:

- consumir reserva durante la liquidacion

Consumidor:

- `banquito-sw-pagos-internos-3p`

Proposito:

- aplicar el consumo de la reserva cuando un pago `on-us` se liquida correctamente

#### `POST /api/v1/switch-core/payment-reservations/service-fee`

Uso:

- cobro de comision del lote

Consumidor:

- `banquito-sw-facturacion-3p`

Proposito:

- cobrar la tarifa o comision asociada al procesamiento del lote

## 5. Notificaciones

#### `POST /api/v1/notifications/requests`

Uso:

- generacion de solicitudes de notificacion

Consumidor:

- `banquito-sw-reportes-3p`

Proposito:

- disparar correos o eventos de notificacion luego del procesamiento del lote

## Mapeo ruta -> servicio del core via Ingress

El API Gateway publica las rutas del core hacia el switch, pero quien termina enrutando al microservicio correcto es el `Ingress` del core.

### Auth

- `/api/v1/auth/*` -> `Ingress del core` -> servicio de seguridad del core

En el despliegue actual del core, estas rutas pertenecen al backend de seguridad.

### Customers

- `/api/v1/customers/*` -> `Ingress del core` -> servicio de clientes del core

### Accounts

- `/api/v1/accounts/*` -> `Ingress del core` -> servicio transaccional del core

### Switch Core

- `/api/v1/switch-core/*` -> `Ingress del core` -> servicio transaccional del core

### Notifications

- `/api/v1/notifications/*` -> `Ingress del core` -> servicio de notificaciones del core

## Metodos HTTP esperados

Resumen de metodos:

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/client-token`
- `GET /api/v1/customers/by-identification/{identification}`
- `GET /api/v1/accounts/{accountNumber}`
- `POST /api/v1/switch-core/company-account-validation`
- `POST /api/v1/switch-core/payment-reservations`
- `POST /api/v1/switch-core/payment-reservations/{reservationId}/consume`
- `POST /api/v1/switch-core/payment-reservations/service-fee`
- `POST /api/v1/notifications/requests`

## Headers que el gateway debe permitir

Como minimo, el API Gateway debe aceptar y reenviar correctamente:

- `Authorization`
- `Content-Type`
- `Accept`

Si el mecanismo final usa headers adicionales, tambien deben permitirse, por ejemplo:

- `x-api-key`
- headers de trazabilidad
- headers tecnicos internos

## Autenticacion esperada

El switch esta preparado principalmente para trabajar con `client-token`.

Variables asociadas:

- `CORE_API_GATEWAY_CLIENT_TOKEN_ENABLED=true`
- `CORE_API_GATEWAY_CLIENT_ID`
- `CORE_API_GATEWAY_CLIENT_SECRET`
- `CORE_API_GATEWAY_CLIENT_TOKEN_PATH=/api/v1/auth/client-token`

Y para notificaciones:

- `NOTIFICATION_API_GATEWAY_CLIENT_TOKEN_ENABLED=true`
- `NOTIFICATION_API_GATEWAY_CLIENT_ID`
- `NOTIFICATION_API_GATEWAY_CLIENT_SECRET`
- `NOTIFICATION_API_GATEWAY_CLIENT_TOKEN_PATH=/api/v1/auth/client-token`

Eso implica que el gateway debe permitir el acceso correcto al endpoint:

- `POST /api/v1/auth/client-token`

## Comportamiento esperado al probar conectividad

### Respuesta buena de conectividad

Estas respuestas indican que la ruta existe y hay conectividad:

- `200`
- `401`
- `403`

Interpretacion:

- `200`: acceso completo y funcional
- `401`: llegaste al backend pero falta autenticacion
- `403`: llegaste al backend pero no tienes permisos

### Respuesta mala de configuracion

- `404`: ruta no publicada o path incorrecto
- `5xx`: error del gateway o del backend
- timeout: gateway no puede enrutar o backend no responde
- error TLS: problema de SSL/certificado

## Pruebas minimas recomendadas

### Probar auth

- `POST /api/v1/auth/client-token`
- `POST /api/v1/auth/login`

### Probar switch core

- `POST /api/v1/switch-core/company-account-validation`
- `POST /api/v1/switch-core/payment-reservations`

### Probar consultas base

- `GET /api/v1/customers/by-identification/{identification}`
- `GET /api/v1/accounts/{accountNumber}`

### Probar notifications

- `POST /api/v1/notifications/requests`

## Reglas de diseno importantes

- No reescribir paths si el switch ya espera esos paths exactos
- No cambiar prefijos como `/api/v1/auth` o `/api/v1/switch-core`
- No mezclar rutas del switch dentro del gateway del core
- No hacer que el switch use nombres internos del core
- Mantener compatibilidad con bearer token y client-token

## Variables del switch que dependen del API Gateway

Estas variables deben quedar correctas en el despliegue del switch:

- `CORE_API_GATEWAY_BASE_URL`
- `AUTH_API_GATEWAY_BASE_URL`
- `NOTIFICATION_API_GATEWAY_BASE_URL`
- `CORE_API_GATEWAY_SWITCH_CORE_PATH`
- `CORE_API_GATEWAY_PAYMENT_RESERVATIONS_PATH`
- `CORE_API_GATEWAY_CUSTOMERS_BY_IDENTIFICATION_PATH`
- `CORE_API_GATEWAY_ACCOUNT_BY_NUMBER_PATH`
- `CORE_API_GATEWAY_COMPANY_ACCOUNT_VALIDATION_PATH`
- `CORE_API_GATEWAY_CLIENT_TOKEN_PATH`
- `AUTH_API_GATEWAY_LOGIN_PATH`
- `AUTH_API_GATEWAY_LOGOUT_PATH`
- `NOTIFICATION_API_GATEWAY_REQUESTS_PATH`

## Resumen final

Para que el switch funcione correctamente, el API Gateway debe:

- exponer una sola URL base publica
- apuntar al `Ingress` del core como backend HTTP
- enrutar rutas de auth, customers, accounts, switch-core y notifications
- respetar los paths exactos que espera el switch
- permitir autenticacion tecnica por `client-token`
- reenviar correctamente headers como `Authorization`
- devolver al menos `401/403` cuando la conectividad exista pero falte auth

Arquitectura final correcta:

- `Cliente externo -> Ingress del switch -> Switch`
- `Switch -> API Gateway -> Ingress del core -> Core`
