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
| `AWS_PROFILE` | Perfil de `~/.aws/credentials` (opcional) | No |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credenciales directas (opcional) | No |

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
