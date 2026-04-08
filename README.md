# API Cloudflax – AWS Infrastructure

Infraestructura como código con **Terraform** para AWS. Todos los recursos se despliegan directamente en una cuenta real de AWS.

## Recursos desplegados

| Recurso | Descripción |
|---|---|
| RDS Aurora PostgreSQL | Clúster + instancia con base de datos `cloudflax` |
| Secrets Manager | Secreto con credenciales de la BD (`username`, `password`, `host`, `port`, `dbname`) |
| Lambda `db_rotation` | Rotación automática de contraseña cada 30 días → [ver README](lambda/db_rotation/README.md) |
| Lambda `cleanup_tokens` | Limpieza de tokens expirados/revocados cada minuto → [ver README](lambda/cleanup_tokens/README.md) |
| IAM | Roles y políticas para ejecución de las Lambdas |
| SES | Identidad de email y template de verificación |
| CloudWatch Events | Regla de schedule para `cleanup_tokens` |
| DynamoDB | Tabla `cloudflax-<ENV>-api-throttle-locks` (pk/sk, TTL `expires_at`, on-demand, cifrado y PITR) |

## Requisitos previos

- [Terraform](https://www.terraform.io/downloads) (provider AWS ~> 5.0)
- [AWS CLI](https://aws.amazon.com/cli/) configurado con credenciales válidas

## Configuración

Copia `.env.example` a `.env` y ajusta los valores:

```bash
cp .env.example .env
```

| Variable | Descripción | Requerida |
|---|---|---|
| `ENVIRONMENT` | Entorno de despliegue (`sandbox`, `staging`, `production`) | Sí |
| `AWS_REGION` | Región de AWS | Sí |
| `SES_EMAIL_IDENTITY` | Email verificado en SES | Sí |
| `DB_PASSWORD` | Contraseña inicial del clúster RDS | Sí |
| `DB_SECRET_ARN` | ARN del secreto en Secrets Manager usado por Lambdas | Sí |
| `AWS_PROFILE` | Perfil de `~/.aws/credentials` (opcional) | No |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credenciales directas (opcional) | No |
| `api_throttle_locks_table_name` | Nombre AWS de la tabla throttle (ver `terraform.tfvars.example`) | No |

## Estructura del proyecto

```
.
├── main.tf                          # Todos los recursos Terraform
├── .env                             # Variables de entorno (no subir a VCS)
├── .env.example                     # Plantilla de variables
├── Makefile                         # Comandos de conveniencia
├── templates/
│   ├── auth-verify-email.html       # Template SES HTML
│   └── auth-verify-email.txt        # Template SES texto plano
└── lambda/
    ├── db_rotation/
    │   ├── rotation.py              # Lambda de rotación de credenciales
    │   ├── rotation_code.zip        # Artefacto generado por Terraform
    │   └── README.md
    └── cleanup_tokens/
        ├── cleanup.py               # Lambda de limpieza de tokens
        ├── cleanup_code.zip         # Artefacto generado por Terraform
        └── README.md
```

## Despliegue

```bash
# 1. Inicializar provider
make init

# 2. Revisar plan
make plan

# 3. Aplicar infraestructura
make apply
```

## Notas

- Los nombres de los recursos incluyen el valor de `ENVIRONMENT` para permitir múltiples entornos en la misma cuenta.
- No subas `.env`, `terraform.tfstate` ni archivos con credenciales a control de versiones.
- `DB_PASSWORD` es la contraseña **inicial** del clúster; una vez que la rotación automática esté activa, Secrets Manager la gestiona.
- **DynamoDB:** tabla única para throttle (reenvío verificación email + ventana por IP): claves `pk`/`sk`, TTL en `expires_at` (número epoch). Nombre por defecto `cloudflax-<ENVIRONMENT>-api-throttle-locks`. El rol de las Lambdas existentes tiene permiso sobre esta tabla. Outputs: `dynamodb_api_throttle_locks_table_name` y `dynamodb_api_throttle_locks_table_arn` (y alias `dynamodb_table_*`). Si ya desplegaste la versión anterior con `for_each` de tablas, `terraform plan` puede proponer **eliminar** esas tablas antiguas y crear esta; revisa el plan antes de aplicar.
