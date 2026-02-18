# API Cloudflax – AWS (LocalStack)

Infraestructura como código con **Terraform** para desplegar en **LocalStack** un clúster RDS Aurora PostgreSQL, un secreto en AWS Secrets Manager y una **Lambda de rotación automática** de contraseñas de base de datos.

## Descripción

Este repositorio define:

- **RDS Aurora PostgreSQL** (clúster + instancia) con base de datos `cloudflax`
- **Secrets Manager**: secreto que almacena credenciales de la base de datos (usuario, contraseña, host, puerto, dbname)
- **Lambda de rotación**: función Python que implementa el flujo de rotación en 4 pasos (`createSecret`, `setSecret`, `testSecret`, `finishSecret`) y actualiza la contraseña en PostgreSQL
- **Rotación automática**: configurada para ejecutarse cada 30 días

El provider de AWS está configurado para apuntar a **LocalStack** (endpoints en `localhost:4566`), permitiendo desarrollar y probar sin usar una cuenta AWS real.

## Requisitos previos

- [Terraform](https://www.terraform.io/downloads) (compatible con provider AWS ~> 5.0)
- [LocalStack](https://docs.localstack.cloud/) en ejecución (por defecto en `http://localhost:4566`)
- [Docker](https://www.docker.com/) (para empaquetar la Lambda con dependencias Linux)
- [awslocal](https://github.com/localstack/awscli-local) (para interactuar con LocalStack desde la terminal)
- PostgreSQL accesible para la Lambda (por ejemplo en `host.docker.internal:4510` si LocalStack corre en Docker)

## Estructura del proyecto

```
.
├── main.tf                    # Recursos Terraform (RDS, Secrets Manager, Lambda, IAM, rotación)
├── lambda/
│   ├── rotation.py           # Código de la Lambda de rotación
│   ├── rotation_code.zip     # Paquete desplegado (generado por el script de build)
│   └── # Crear carpeta temporal.sh   # Script para generar rotation_code.zip
└── README.md
```

## Empaquetado de la Lambda

La Lambda usa **Python 3.9** y depende de `psycopg2-binary`. El paquete debe construirse en un entorno Linux (por ejemplo con Docker) para que sea compatible con AWS Lambda.

Desde la raíz del proyecto:

```bash
docker run --rm -v $(pwd):/var/task public.ecr.aws/sam/build-python3.9:latest \
  pip install psycopg2-binary -t ./lambda
cd lambda
zip -r ../lambda/rotation_code.zip .
```

Esto genera `lambda/rotation_code.zip`, que es el artefacto referenciado en `main.tf`.

## Despliegue con Terraform

1. Asegúrate de que LocalStack está corriendo (por ejemplo con `localstack start`).

2. Inicializa Terraform e instala el provider:

   ```bash
   terraform init
   ```

3. Revisa el plan:

   ```bash
   terraform plan
   ```

4. Aplica la infraestructura:

   ```bash
   terraform apply
   ```

## Configuración relevante

- **Provider AWS**: credenciales de prueba (`access_key = "test"`, `secret_key = "test"`), región `us-east-1`, y endpoints de LocalStack para RDS, Secrets Manager, STS, IAM y Lambda.
- **Secreto**: el secreto guarda `username`, `password`, `host`, `port` y `dbname`. En el ejemplo, `host` es `host.docker.internal` y `port` es `4510` para que la Lambda (dentro de LocalStack) pueda conectar a Postgres en el host.
- **Lambda**: variable de entorno `SECRETS_MANAGER_ENDPOINT = "http://host.docker.internal:4566"` para que la función hable con Secrets Manager en LocalStack.

Puedes ajustar en `main.tf` el `host` y el `port` del secreto según dónde esté tu instancia PostgreSQL.

## Flujo de rotación (Lambda)

La Lambda implementa el flujo estándar de rotación de Secrets Manager:

| Paso            | Descripción breve                                                                 |
|-----------------|------------------------------------------------------------------------------------|
| `createSecret`  | Genera una nueva contraseña y guarda el JSON completo como versión `AWSPENDING`.  |
| `setSecret`     | Conecta a PostgreSQL con las credenciales actuales y ejecuta `ALTER USER ... WITH PASSWORD` con la nueva contraseña. |
| `testSecret`    | Marca la prueba de conexión como exitosa (puedes añadir una conexión real si lo deseas). |
| `finishSecret`  | Mueve la etiqueta `AWSCURRENT` a la nueva versión del secreto.                     |

La contraseña se genera con caracteres seguros evitando `" ' @ / \` y espacio para evitar problemas en cadenas de conexión y en `ALTER USER`.

## Rotación manual (LocalStack)

Para probar la rotación de la contraseña sin esperar a que se cumpla el periodo automático (30 días), puedes forzarla manualmente usando `awslocal`.

### Instalación de awslocal

Si no lo tienes instalado, puedes hacerlo mediante `pip`:

```bash
pip install awscli-local
```

### Ejecutar rotación

Ejecuta el siguiente comando para disparar el flujo de rotación de inmediato:

```bash
awslocal secretsmanager rotate-secret --secret-id tf-localstack-db-secret
```

Este comando solicita a Secrets Manager que inicie el proceso, lo cual invocará la función Lambda de rotación. Puedes verificar los logs de la Lambda en LocalStack para confirmar que los 4 pasos (`createSecret`, `setSecret`, `testSecret`, `finishSecret`) se ejecutan correctamente.

## Notas

- Este código está pensado para **entorno local con LocalStack**. Para AWS real habría que cambiar el provider (credenciales, región) y quitar o reemplazar los endpoints de LocalStack.
- No subas `terraform.tfstate` ni archivos con credenciales a control de versiones. Usa un backend remoto (p. ej. S3) y/o variables de entorno/secretos para datos sensibles en producción.
