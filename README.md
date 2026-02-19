# API Cloudflax – AWS (LocalStack)

Infraestructura como código con **Terraform** para desplegar en **LocalStack** un clúster RDS Aurora PostgreSQL junto con los recursos de soporte necesarios.

## Recursos desplegados

| Recurso | Descripción |
|---|---|
| RDS Aurora PostgreSQL | Clúster + instancia con base de datos `cloudflax` |
| Secrets Manager | Secreto con credenciales de la BD (`username`, `password`, `host`, `port`, `dbname`) |
| Lambda `db_rotation` | Rotación automática de contraseña cada 30 días → [ver README](lambda/db_rotation/README.md) |
| Lambda `cleanup_tokens` | Limpieza de tokens expirados/revocados cada minuto → [ver README](lambda/cleanup_tokens/README.md) |
| IAM | Roles y políticas para ejecución de las Lambdas |
| CloudWatch Events | Regla de schedule para `cleanup_tokens` |

## Requisitos previos

- [Terraform](https://www.terraform.io/downloads) (provider AWS ~> 5.0)
- [LocalStack](https://docs.localstack.cloud/) en ejecución en `http://localhost:4566`
- [Docker](https://www.docker.com/) (para empaquetar las Lambdas con dependencias Linux)
- [awslocal](https://github.com/localstack/awscli-local) (`pip install awscli-local`)

## Estructura del proyecto

```
.
├── main.tf                          # Todos los recursos Terraform
├── lambda/
│   ├── db_rotation/
│   │   ├── rotation.py              # Lambda de rotación de credenciales
│   │   ├── rotation_code.zip        # Artefacto generado por Terraform
│   │   └── README.md
│   └── cleanup_tokens/
│       ├── cleanup.py               # Lambda de limpieza de tokens
│       ├── cleanup_code.zip         # Artefacto generado por Terraform
│       └── README.md
└── README.md
```

## Despliegue

```bash
# 1. Inicializar provider
terraform init

# 2. Revisar plan
terraform plan

# 3. Aplicar infraestructura
terraform apply
```

> Terraform genera los `.zip` de las Lambdas automáticamente mediante el bloque `archive_file` en `main.tf`. No es necesario empaquetar manualmente antes del primer `apply`.

## Configuración relevante

- **Provider**: credenciales de prueba (`test`/`test`), región `us-east-1`, endpoints apuntando a LocalStack (`localhost:4566`).
- **Secreto**: `host` configurado como `host.docker.internal:4510` para que las Lambdas (dentro del contenedor de LocalStack) alcancen PostgreSQL en el host.
- **Variable de entorno Lambda**: `SECRETS_MANAGER_ENDPOINT = "http://host.docker.internal:4566"`.

Ajusta `host` y `port` del secreto en `main.tf` según dónde corra tu instancia PostgreSQL.

## Notas

- Este código está pensado exclusivamente para **entorno local con LocalStack**. Para AWS real hay que eliminar los endpoints de LocalStack y usar credenciales reales.
- No subas `terraform.tfstate` ni archivos con credenciales a control de versiones.
