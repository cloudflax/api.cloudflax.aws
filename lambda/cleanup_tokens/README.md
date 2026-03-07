# Lambda: cleanup_tokens

Función Lambda que limpia automáticamente la tabla `refresh_tokens` de PostgreSQL (Aurora). Se ejecuta cada minuto via CloudWatch Events y elimina tokens **expirados** (`expires_at < NOW()`) o **revocados** (`revoked_at IS NOT NULL`).

---

## Variables de entorno

| Variable | Descripción |
|---|---|
| `DB_SECRET_ARN` | ARN del secreto en Secrets Manager con las credenciales de la BD |
| `AWS_REGION_NAME` | Región de AWS donde se encuentra Secrets Manager |

---

## Empaquetado

Terraform genera el `.zip` automáticamente al ejecutar `plan`/`apply` con el bloque `archive_file` en `main.tf`. La función usa `psycopg2`; para que funcione en Lambda hay que añadir una **Lambda Layer** con `psycopg2` compilado para Amazon Linux (por ejemplo [psycopg2-lambda-layer](https://github.com/jetbridge/psycopg2-lambda-layer)) o incluir la dependencia en el paquete generado en un entorno compatible.

---

## Prueba manual en AWS

```bash
aws lambda invoke \
  --function-name cloudflax-sandbox-cleanup-lambda \
  --payload '{}' \
  --region us-east-1 \
  response.json && cat response.json
```
