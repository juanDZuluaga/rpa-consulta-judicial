# Contenido

- [Herramienta utilizada y versión](#herramienta-utilizada-y-versión)
- [Stack tecnológico](#stack-tecnológico)
- [¿Por qué N8N?](#por-qué-n8n)
- [Resumen de la solución](#resumen-de-la-solución)
- [Descripción general](#descripción-general)
- [Diagrama ASCII del flujo](#diagrama-ascii-del-flujo)
- [Cómo configurar y ejecutar el bot](#cómo-configurar-y-ejecutar-el-bot)
  - [Requisitos previos](#requisitos-previos)
  - [Estructura del proyecto](#estructura-del-proyecto)
  - [Levantar el entorno](#levantar-el-entorno)
  - [Contenedores en ejecución](#contenedores-en-ejecución)
  - [Configuración de credenciales en n8n](#configuración-de-credenciales-en-n8n)
  - [Crear la tabla de logs en PostgreSQL](#crear-la-tabla-de-logs-en-postgresql)
  - [Importar el flujo en n8n](#importar-el-flujo-en-n8n)
  - [Formato del correo disparador](#formato-del-correo-disparador)
  - [Variables de configuración](#variables-de-configuración)
- [Decisiones técnicas clave](#decisiones-técnicas-clave)
  - [Estrategia para identificar el sexto resultado](#estrategia-para-identificar-el-sexto-resultado)
  - [Cómo se extrae el nombre del correo](#cómo-se-extrae-el-nombre-del-correo)
  - [Cómo se maneja la descarga del archivo](#cómo-se-maneja-la-descarga-del-archivo)
  - [Estrategia DOC → CSV (fallback)](#estrategia-doc--csv-fallback)
  - [Arquitectura de logs con PostgreSQL](#arquitectura-de-logs-con-postgresql)
  - [Manejo de errores](#manejo-de-errores)
- [Entregables del repositorio](#entregables-del-repositorio)

---

# Herramienta utilizada y versión

## Stack tecnológico

| Atributo             | Detalle                                    |
|----------------------|--------------------------------------------|
| Herramienta RPA      | N8N (self-hosted vía Docker)               |
| Versión              | n8nio/n8n:latest                           |
| Motor de navegación  | Browserless/Chrome (browserless/chrome:latest) |
| Base de datos        | PostgreSQL 15 (logs_db)                    |
| Orquestación         | Docker Compose v3.8                        |
| Correo               | Gmail (OAuth2 vía credencial n8n)          |

## ¿Por qué N8N?

- Flujos visuales exportables como JSON y versionables con Git.
- Integración nativa con Gmail sin código adicional.
- Nodos de código JavaScript para lógica personalizada.
- Compatible con Browserless para scraping sin instalar Puppeteer localmente.
- Despliegue en Docker: aislado, reproducible y sin dependencias del sistema operativo host.

---

# Resumen de la solución

## Descripción general

El flujo automatiza end-to-end la consulta de procesos judiciales en la Rama Judicial de Colombia. Al recibir un correo electrónico con el nombre de una persona, el bot navega al portal judicial, extrae el sexto resultado, descarga el reporte en CSV y lo envía adjunto por correo al área responsable. Todos los eventos quedan registrados en PostgreSQL.

## Diagrama ASCII del flujo

> *(Ver imagen `flujo_completo.png` en la carpeta `/screenshots`)*

---

# Cómo configurar y ejecutar el bot

## Requisitos previos

- Docker Desktop instalado y en ejecución (Windows, Mac o Linux).
- Cuenta Gmail con acceso OAuth2 configurado en n8n.
- Puertos disponibles: `5678` (n8n), `3000` (Browserless), `5432` (PostgreSQL).
- Git para clonar el repositorio.

## Estructura del proyecto

```
E:\usuario\rpa-consulta-judicial
├── flujo\
│   ├── docker\
│   ├── .idea\                        <- Configuración del IDE
│   ├── n8n\                          <- (volumen externo: docker_n8n_data)
│   ├── docker-compose.yml            <- Orquestación de servicios
│   └── rpa-consulta-judicial.json
├── export_logs.bat                   <- Script para exportar logs a .txt
├── /screenshots
│   ├── flujo_completo.png        <- Captura del flujo en n8n
│   ├── ejecucion_exitosa.png     <- Captura de ejecución correcta
│   └── video_flujo.mp4           <- Video de ejecución correcta
└── logs\
    └── logs.txt                      <- Logs exportados desde PostgreSQL
```

## Levantar el entorno

Abrir una terminal en la carpeta raíz del proyecto y ejecutar:

```bash
# 1. Crear el volumen externo de n8n (solo la primera vez)
docker volume create docker_n8n_data

# 2. Levantar todos los servicios
docker-compose up -d

# 3. Verificar que los contenedores estén corriendo
docker ps
```

## Contenedores en ejecución

| Servicio    | Imagen                        | Puerto |
|-------------|-------------------------------|--------|
| n8n         | n8nio/n8n:latest              | 5678   |
| browserless | browserless/chrome:latest     | 3000   |
| Postgres    | postgres:15                   | 5432   |

## Configuración de credenciales en n8n

1. Abrir `http://localhost:5678` en el navegador.
2. Ir a **Settings > Credentials > Add Credential** (o **Workflow > Credentials > Create new > Credentials**).
3. Agregar credencial de tipo **Gmail OAuth2** con tu cuenta de correo.
4. Agregar credencial **PostgreSQL**:
   - host: `postgres`
   - port: `5432`
   - user: `n8n`
   - password: `n8n123`
   - db: `logs_db`

## Ingreso al a base de datos a través de la consola de Docker o en su defecto poweeshelltablas
docker exec -it postgres psql -U n8n -d logs_db

## ver tablas
\dt

## Crear la tabla de logs en PostgreSQL
SELECT * FROM logs;


## Crear la tabla de logs en PostgreSQL

Ejecutar el siguiente SQL **una sola vez** en la base de datos:

```sql
CREATE TABLE IF NOT EXISTS logs (
  id        SERIAL PRIMARY KEY,
  timestamp VARCHAR(50),
  step      VARCHAR(100),
  status    VARCHAR(50),
  message   TEXT
);
```

## Importar el flujo en n8n

1. Abrir n8n en `http://localhost:5678`.
2. Clic en el menú hamburguesa (arriba izquierda) → **Import from File**.
3. Seleccionar el archivo `flujo/rpa-consulta-judicial.json` del repositorio.
4. Asignar las credenciales de Gmail y PostgreSQL a los nodos correspondientes.
5. Clic en **Save** y luego en **Execute Workflow**.

## Formato del correo disparador

El correo que activa el flujo debe cumplir este formato:

```
Asunto: Consulta_nombre
Cuerpo:  Oscar Martinez Davila
```

> El subject debe contener `Consulta_nombre` y el mensaje debe estar marcado como no leído (`is:unread`).

## Variables de configuración

| Variable          | Valor actual                                              | Dónde configurar              |
|-------------------|-----------------------------------------------------------|-------------------------------|
| Correo destino    | jhrey@tcc.com.co                                          | Nodo Gmail – Send             |
| Correo evaluador  | jhrey@tcc.com.co                                          | Asunto del correo             |
| Label Gmail       | INBOX                                                     | Nodo Gmail - Get Many         |
| Filtro subject    | `Consulta_nombre is:unread`                               | Nodo Gmail – Search           |
| URL Rama Judicial | https://consultaprocesos.ramajudicial.gov.co/...          | Script Puppeteer              |
| PostgreSQL Host   | postgres                                                  | Credencial PostgreSQL en n8n  |
| PostgreSQL DB     | logs_db                                                   | Credencial PostgreSQL en n8n  |
| Browserless URL   | http://browserless:3000/function                          | Nodo HTTP Request             |
| Timeout scraping  | 30000 ms                                                  | Script Puppeteer              |

---

# Decisiones técnicas clave

## Estrategia para identificar el sexto resultado

El script Puppeteer espera a que cargue la tabla con `table tbody tr` y luego accede al índice fijo `[5]` (base 0 = sexta fila). Se usa `waitForSelector` con timeout de 30 segundos para garantizar que la página haya cargado completamente antes de intentar acceder a los elementos. No se usan coordenadas fijas ni sleeps arbitrarios.

## Cómo se extrae el nombre del correo

El nodo de Gmail retorna el campo `snippet` (resumen del mensaje). El nodo JS lo toma con `$input.first().json.snippet` y lo inyecta directamente en el template del código Puppeteer mediante interpolación de cadena (template literals). Esto garantiza que cualquier nombre de texto plano funcione sin transformaciones adicionales.

## Cómo se maneja la descarga del archivo

Se usa `page.setRequestInterception(true)` para interceptar la respuesta HTTP del archivo CSV directamente en memoria. Esto evita la complejidad del manejo de directorios de descarga en un entorno Docker. El contenido se retorna como string en el JSON de respuesta de Browserless y luego el nodo JS lo convierte a binario con `helpers.prepareBinaryData`.

## Estrategia DOC → CSV (fallback)

El bot intenta primero descargar el documento en formato DOC. Si el proceso muestra un modal indicando que no está disponible, hace clic en **Volver** y reintenta con la opción **Descargar CSV** (hasta 3 intentos con espera de 2 segundos entre cada uno).

**Estrategia CSV → DOC (HTML)**

El bot obtiene la información en formato CSV desde la fuente de datos. Posteriormente, mediante un script en JavaScript, se procesa este contenido para transformarlo en una estructura HTML.

Este HTML es diseñado cuidadosamente para representar la información en una tabla clara, ordenada y visualmente presentable, facilitando su lectura y análisis.

Una vez generada la estructura, el contenido HTML se convierte en un archivo binario con formato `.doc`, compatible con Microsoft Word. Finalmente, este archivo es adjuntado y enviado automáticamente a través de Gmail como documento.

## Arquitectura de logs con PostgreSQL

Como el entorno corre en Docker y *Write Files to Disk* no estaba disponible directamente en esta versión de n8n, se optó por persistir los logs en PostgreSQL (contenedor en el mismo Docker Compose). Esto ofrece ventajas adicionales: consultas SQL, filtros por fecha y exportación con un solo clic vía `export_logs.bat`. El flujo registra tres puntos de control: inicio, resultado de scraping y fin del envío.

## Manejo de errores

| Escenario de error        | Manejo implementado                                                                                                                                         |
|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Page timeout              | `waitForSelector` con timeout 30 s. Si la página no responde, Browserless retorna un error que se registra en PostgreSQL con `status='error'`.              |
| Modal DOC no disponible   | El bot detecta el texto del modal activo y hace fallback automático a CSV con hasta 3 reintentos.                                                            |
| Tabla vacía               | El script verifica que haya al menos 6 filas antes de hacer clic. Si hay menos, retorna `{ error: 'No hay suficientes filas' }`.                            |
| Snippet vacío             | Si `snippet` está vacío o indefinido, el nombre consultado será `'N/A'` y el log registrará el fallo.                                                       |
| Gmail error               | n8n notifica el error en la interfaz visual y el log de PostgreSQL lo captura con `status='error'`; si se detecta un error en un nodo, manda informe del error al Gmail del consultante con el nodo exacto del fallo. |

---

# Entregables del repositorio

```
/rpa-consulta-judicial
├── /flujo
│  └──  /Docker
│     ├── /.idea
│     ├── /n8n
│     ├── docker-compose.yml            <- Orquestación Docker
│     └── README.md                     <- Este documento
├── rpa-consulta-judicial.json    <- Exportación del flujo n8n
├── /screenshots
│   ├── flujo_completo.png        <- Captura del flujo en n8n
│   ├── ejecucion_exitosa.png     <- Captura de ejecución correcta
│   └── video_flujo.mp4           <- Video de ejecución correcta
└── /logs
    ├── logs.txt                  <- Log de ejecución exitosa
    ├── export_logs.bat           <- Script exportación logs
    └── README.docx               <- Este documento
```
