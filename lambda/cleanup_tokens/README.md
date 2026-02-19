# Lambda: cleanup_tokens

Función Lambda que limpia automáticamente la tabla `refresh_tokens` de PostgreSQL (Aurora). Se ejecuta cada minuto via CloudWatch Events y elimina tokens **expirados** (`expires_at < NOW()`) o **revocados** (`revoked_at IS NOT NULL`).

---

## Variables de entorno

| Variable | Descripción |
|---|---|
| `DB_SECRET_ARN` | ARN del secreto en Secrets Manager con las credenciales de la BD |
| `SECRETS_MANAGER_ENDPOINT` | Endpoint de Secrets Manager (LocalStack: `http://host.docker.internal:4566`) |

---

## Empaquetar con Docker

`psycopg2` debe compilarse para Amazon Linux. Instalar con `pip` normal genera un binario incompatible con el runtime de Lambda.

**Paso 1 — Instalar dependencias dentro del contenedor de Lambda:**

```bash
docker run --rm \
  --entrypoint bash \
  -v "$(pwd)/lambda/cleanup_tokens:/var/task" \
  -w /var/task \
  public.ecr.aws/lambda/python:3.9 \
  -c "pip install --upgrade pip --root-user-action=ignore && pip install psycopg2-binary --target /var/task --upgrade --root-user-action=ignore"
```

**Paso 2 — Generar el `.zip`:**

```bash
cd lambda/cleanup_tokens

zip -r cleanup_code.zip . \
  --exclude "*.pyc" \
  --exclude "__pycache__/*" \
  --exclude "README.md" \
  --exclude "cleanup_code.zip"
```

> Terraform también genera el `.zip` automáticamente al ejecutar `terraform apply` usando el bloque `archive_file` en `main.tf`.

---

## Prueba manual con LocalStack

```bash
awslocal lambda invoke \
  --function-name tf-localstack-cleanup-tokens-lambda \
  --payload '{}' \
  response.json && cat response.json
```
