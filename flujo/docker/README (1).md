# 🔍 Consulta Automática de Procesos Judiciales - Rama Judicial Colombia

## 📋 Descripción

Automatización que consulta procesos judiciales en la página oficial de la Rama Judicial de Colombia, extrae los resultados en formato CSV y los envía por correo electrónico usando Gmail.

---

## 🏗️ Arquitectura

```
[Gmail - Recibir] → [Code - Construir Script] → [HTTP Request - Browserless] → [Code - Limpiar CSV] → [Gmail - Enviar]
```

---

## 🛠️ Tecnologías Utilizadas

| Tecnología | Versión | Descripción |
|---|---|---|
| n8n | latest | Plataforma de automatización |
| Browserless | latest | Chrome headless para scraping |
| Puppeteer | integrado | Automatización del navegador |
| Docker | - | Contenedores |
| Docker Compose | - | Orquestación de servicios |

---

## 📁 Estructura del Proyecto

```
docker/
│
├── docker-compose.yml       # Configuración de servicios Docker
└── README.md                # Este archivo
```

---

## ⚙️ Requisitos Previos

- Docker Desktop instalado
- Docker Compose instalado
- Cuenta de Gmail configurada en n8n
- Acceso a internet

---

## 🚀 Instalación y Configuración

### 1. Clonar o crear la carpeta del proyecto

```bash
mkdir docker
cd docker
```

### 2. Crear el archivo `docker-compose.yml`

```yaml
version: '3.8'

services:

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - browserless
    restart: unless-stopped

  browserless:
    image: browserless/chrome:latest
    container_name: browserless
    ports:
      - "3000:3000"
    environment:
      - MAX_CONCURRENT_SESSIONS=5
      - MAX_QUEUE_LENGTH=10
      - TIMEOUT=60000
      - KEEP_ALIVE=true
    restart: unless-stopped

volumes:
  n8n_data:
```

### 3. Levantar los servicios

```bash
docker-compose up -d
```

### 4. Verificar que estén corriendo

```bash
docker ps
```

Debes ver dos contenedores activos:
- `n8n` en el puerto `5678`
- `browserless` en el puerto `3000`

### 5. Acceder a n8n

```
http://localhost:5678
```

---

## 🔄 Flujo de Automatización en n8n

### Nodo 1 — Gmail (Trigger)
- Escucha correos entrantes
- Extrae el campo `snippet` con el nombre a consultar

### Nodo 2 — Code (Construir Script)
- Recibe el nombre desde Gmail via `$input.first().json.snippet`
- Construye el script de Puppeteer con el nombre dinámico
- Envía el código a Browserless

```javascript
const nombre = $input.first().json.snippet;
```

### Nodo 3 — HTTP Request (Browserless)
- **Method:** POST
- **URL:** `http://browserless:3000/function`
- **Body:**
```json
{
  "code": "{{ $json.code }}",
  "context": {}
}
```

### Nodo 4 — Code (Limpiar CSV)
- Parsea la respuesta de Browserless
- Limpia el CSV de caracteres UTF-16
- Convierte a binario para adjuntar en Gmail

```javascript
const data = JSON.parse($input.first().json.data);
const csvLimpio = data.csvContenido.replace(/\u0000/g, '');
```

### Nodo 5 — Gmail (Enviar)
- Envía el correo con el CSV adjunto
- **To:** destinatario
- **Attachment Field Name:** `attachment`

---

## 🌐 Página Consultada

```
https://consultaprocesos.ramajudicial.gov.co/Procesos/NombreRazonSocial
```

### Pasos que realiza el scraper:
1. Selecciona el radio button de búsqueda por nombre
2. Selecciona **Persona Natural** en el dropdown
3. Ingresa el nombre a consultar
4. Hace clic en **Consultar**
5. Cierra alertas si aparecen
6. Entra al detalle de la fila 6
7. Intenta descargar **DOC** → si no está disponible descarga **CSV**
8. Captura el contenido del archivo

---

## 📧 Resultado

El destinatario recibe un correo con:
- **Asunto:** `Procesos judiciales - {nombre consultado}`
- **Mensaje:** Adjunto encontrarás los procesos judiciales
- **Adjunto:** Archivo CSV con los procesos encontrados

---

## 🐛 Solución de Problemas

| Error | Causa | Solución |
|---|---|---|
| `ERR_CONNECTION_REFUSED` | Puerto no mapeado | Verificar `docker-compose.yml` |
| `Module 'puppeteer' is disallowed` | n8n no permite módulos externos | Usar Browserless vía HTTP Request |
| `Bad request` | Token incorrecto o body mal formado | Verificar URL y Body del HTTP Request |
| `no binary field 'attachment'` | Espacio extra en el campo | Borrar y escribir `attachment` manualmente |
| `CSV con caracteres \u0000` | CSV en formato UTF-16 | Usar `.replace(/\u0000/g, '')` |

---

## 📌 Comandos Útiles

```bash
# Levantar servicios
docker-compose up -d

# Detener servicios
docker-compose down

# Ver logs de n8n
docker logs n8n

# Ver logs de browserless
docker logs browserless

# Ver contenedores activos
docker ps

# Eliminar contenedor específico
docker rm -f nombre_contenedor
```

---

## 👤 Autor

Proyecto desarrollado con n8n + Browserless + Puppeteer para automatización de consultas judiciales en Colombia.
