# Lambda: db_rotation

Función Lambda que implementa la rotación automática de credenciales de la base de datos PostgreSQL (Aurora) usando AWS Secrets Manager. Se activa mediante el ciclo de rotación de Secrets Manager y ejecuta los cuatro pasos estándar: `createSecret`, `setSecret`, `testSecret` y `finishSecret`.

---

## Variables de entorno

| Variable | Descripción |
|---|---|
| `SECRETS_MANAGER_ENDPOINT` | Endpoint de Secrets Manager (LocalStack: `http://host.docker.internal:4566`) |

---

## Flujo de rotación

| Paso | Descripción |
|---|---|
| `createSecret` | Genera una nueva contraseña segura y la guarda como versión `AWSPENDING` en Secrets Manager |
| `setSecret` | Se conecta a la BD con las credenciales actuales y ejecuta `ALTER USER` con la nueva contraseña |
| `testSecret` | Verifica que la nueva versión es válida |
| `finishSecret` | Mueve la etiqueta `AWSCURRENT` a la nueva versión y completa la rotación |

---

## Empaquetar con Docker

`psycopg2` debe compilarse para Amazon Linux. Instalar con `pip` normal genera un binario incompatible con el runtime de Lambda.

**Paso 1 — Instalar dependencias dentro del contenedor de Lambda:**

```bash
docker run --rm \
  --entrypoint bash \
  -v "$(pwd)/lambda/db_rotation:/var/task" \
  -w /var/task \
  public.ecr.aws/lambda/python:3.9 \
  -c "pip install --upgrade pip --root-user-action=ignore && pip install psycopg2-binary --target /var/task --upgrade --root-user-action=ignore"
```

**Paso 2 — Generar el `.zip`:**

```bash
cd lambda/db_rotation

zip -r rotation_code.zip . \
  --exclude "*.pyc" \
  --exclude "__pycache__/*" \
  --exclude "README.md" \
  --exclude "rotation_code.zip"
```

> Terraform también genera el `.zip` automáticamente al ejecutar `terraform apply` usando el bloque `archive_file` en `main.tf`.

---

## Prueba manual con LocalStack

```bash
awslocal lambda invoke \
  --function-name tf-localstack-rotation-lambda \
  --payload '{"SecretId":"<ARN_DEL_SECRETO>","ClientRequestToken":"<TOKEN>","Step":"createSecret"}' \
  response.json && cat response.json
```
