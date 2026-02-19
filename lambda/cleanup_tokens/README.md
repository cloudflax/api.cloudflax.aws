# Lambda: cleanup_tokens

Función Lambda encargada de eliminar los `refresh_tokens` expirados de la base de datos PostgreSQL (Aurora). Se ejecuta de forma automática cada minuto mediante una regla de CloudWatch Events.

---

## Estructura de archivos

```
lambda/cleanup_tokens/
├── cleanup.py          # Código fuente del handler
├── psycopg2/           # Dependencia empaquetada manualmente (driver PostgreSQL)
│   ├── __init__.py
│   ├── extensions.py
│   ├── extras.py
│   └── ...
└── README.md
```

> **Importante:** `psycopg2` se incluye directamente en la carpeta porque AWS Lambda no tiene este driver disponible de forma nativa. Se debe usar la versión compilada para Amazon Linux (`psycopg2-binary` o un wheel pre-compilado), no la instalada en tu máquina local.

---

## Cómo empaquetar la Lambda

Terraform genera el `.zip` automáticamente usando el bloque `archive_file` definido en `main.tf`. Sin embargo, cuando quieras probar o subir el paquete manualmente, sigue estos pasos:

### Opción 1 — Empaquetado automático con Terraform (recomendado)

Terraform comprime toda la carpeta `lambda/cleanup_tokens/` en `cleanup_code.zip` cada vez que ejecutas:

```bash
terraform apply
```

El bloque responsable en `main.tf` es:

```hcl
data "archive_file" "cleanup_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/cleanup_tokens"
  output_path = "${path.module}/lambda/cleanup_tokens/cleanup_code.zip"
}
```

### Opción 2 — Empaquetado manual desde la terminal

Desde la raíz del proyecto:

```bash
cd lambda/cleanup_tokens
zip -r cleanup_code.zip . \
  --exclude "*.pyc" \
  --exclude "__pycache__/*" \
  --exclude "README.md" \
  --exclude "cleanup_code.zip"
```

Esto genera `cleanup_code.zip` con el handler y la dependencia `psycopg2` listos para desplegar.

### Opción 3 — Reinstalar dependencias para Amazon Linux

Si necesitas actualizar o reparar la dependencia `psycopg2` para que sea compatible con el runtime de Lambda (`python3.9` en Amazon Linux 2):

```bash
# Requiere Docker
pip install \
  --platform mlinux_2_x86_64 \
  --target ./lambda/cleanup_tokens \
  --implementation cp \
  --python-version 3.9 \
  --only-binary=:all: \
  psycopg2-binary
```

> Instalar `psycopg2` con `pip install psycopg2` normal **no funciona** en Lambda porque el binario compilado para tu OS local no es compatible con Amazon Linux.

---

## Variables de entorno requeridas

| Variable                  | Descripción                                              |
|---------------------------|----------------------------------------------------------|
| `DB_SECRET_ARN`           | ARN del secreto en Secrets Manager con las credenciales de la BD |
| `SECRETS_MANAGER_ENDPOINT`| Endpoint de Secrets Manager (para LocalStack: `http://host.docker.internal:4566`) |

---

## Qué hace el handler

1. Lee `DB_SECRET_ARN` del entorno.
2. Obtiene las credenciales de la BD desde AWS Secrets Manager.
3. Abre una conexión a PostgreSQL con `psycopg2`.
4. Ejecuta:
   ```sql
   DELETE FROM public.refresh_tokens WHERE expires_at < NOW();
   ```
5. Retorna un JSON con el número de tokens eliminados o un error en caso de fallo.

---

## Ejecución programada

La Lambda es invocada cada minuto por la siguiente regla de CloudWatch definida en `main.tf`:

```hcl
resource "aws_cloudwatch_event_rule" "cleanup_schedule" {
  name                = "cleanup-tokens-every-minute"
  schedule_expression = "rate(1 minute)"
}
```

---

## Prueba manual con LocalStack

```bash
awslocal lambda invoke \
  --function-name tf-localstack-cleanup-tokens-lambda \
  --payload '{}' \
  response.json && cat response.json
```
