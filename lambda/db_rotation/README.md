# Lambda: db_rotation

Función Lambda que implementa la rotación automática de credenciales de la base de datos PostgreSQL (Aurora) usando AWS Secrets Manager. Se activa mediante el ciclo de rotación de Secrets Manager y ejecuta los cuatro pasos estándar: `createSecret`, `setSecret`, `testSecret` y `finishSecret`.

---

## Variables de entorno

| Variable | Descripción |
|---|---|
| `AWS_REGION_NAME` | Región de AWS donde se encuentra Secrets Manager |

---

## Flujo de rotación

| Paso | Descripción |
|---|---|
| `createSecret` | Genera una nueva contraseña segura y la guarda como versión `AWSPENDING` en Secrets Manager |
| `setSecret` | Se conecta a la BD con las credenciales actuales y ejecuta `ALTER USER` con la nueva contraseña |
| `testSecret` | Verifica que la nueva versión es válida |
| `finishSecret` | Mueve la etiqueta `AWSCURRENT` a la nueva versión y completa la rotación |

---

## Empaquetado

Terraform genera el `.zip` automáticamente al ejecutar `plan`/`apply` con el bloque `archive_file` en `main.tf`. La función usa `psycopg2`; para que funcione en Lambda hay que añadir una **Lambda Layer** con `psycopg2` compilado para Amazon Linux (por ejemplo [psycopg2-lambda-layer](https://github.com/jetbridge/psycopg2-lambda-layer)) o incluir la dependencia en el paquete generado en un entorno compatible.

---

## Prueba manual en AWS

```bash
aws lambda invoke \
  --function-name cloudflax-sandbox-rotation-lambda \
  --payload '{"SecretId":"<ARN_DEL_SECRETO>","ClientRequestToken":"<TOKEN>","Step":"createSecret"}' \
  --region us-east-1 \
  response.json && cat response.json
```
