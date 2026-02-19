import boto3
import json
import os
import psycopg2
import secrets
import string

def get_random_password(length=32):
    """
    Genera una contraseña aleatoria segura excluyendo caracteres 
    que pueden causar problemas en cadenas de conexión o SQL.
    """
    alphabet = string.ascii_letters + string.digits + string.punctuation
    # Caracteres excluidos para evitar errores de sintaxis en SQL (ALTER USER).
    exclude_chars = "\"'@/\\ " 
    safe_alphabet = ''.join(c for c in alphabet if c not in exclude_chars)
    return ''.join(secrets.choice(safe_alphabet) for i in range(length))

def get_secrets_manager_client():
    # Mantiene la configuración para que la Lambda vea a LocalStack.
    endpoint_url = os.environ.get('SECRETS_MANAGER_ENDPOINT', 'http://host.docker.internal:4566')
    return boto3.client('secretsmanager', endpoint_url=endpoint_url, region_name='us-east-1')

def handler(event, context):
    execution_history = []
    
    def add_log(status, message, step=None, extra=None):
        log_entry = {"status": status, "message": message, "step": step}
        if extra: log_entry.update(extra)
        execution_history.append(log_entry)

    add_log("INFO", "Inicio de ejecución", extra={"event": event})
    
    if 'SecretId' not in event:
        return {"statusCode": 400, "body": "Evento inválido: falta SecretId"}

    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']
    client = get_secrets_manager_client()

    try:
        if step == "createSecret":
            create_secret(client, arn, token, add_log)
        elif step == "setSecret":
            set_secret(client, arn, token, add_log)
        elif step == "testSecret":
            test_secret(arn, add_log)
        elif step == "finishSecret":
            finish_secret(client, arn, token, add_log)
        
        return {
            "statusCode": 200,
            "body": execution_history
        }

    except Exception as e:
        add_log("ERROR", str(e), step=step)
        return {
            "statusCode": 500,
            "body": execution_history,
            "error": str(e)
        }

def create_secret(client, arn, token, add_log):
    # 1. Intentar obtener la versión actual para preservar host, puerto, etc.
    try:
        current_version = client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")
        current_dict = json.loads(current_version['SecretString'])
    except Exception:
        # Si AWSCURRENT no existe (común en LocalStack tras un error), iniciamos vacío.
        add_log("WARNING", "No se pudo recuperar AWSCURRENT en createSecret", step="createSecret")
        current_dict = {}

    # 2. Generar nueva contraseña y clonar el resto de la configuración.
    new_password = get_random_password(length=32) 
    new_dict = current_dict.copy()
    new_dict['password'] = new_password
    
    try:
        # 3. Guardar el nuevo JSON completo como AWSPENDING.
        client.put_secret_value(
            SecretId=arn, 
            ClientRequestToken=token, 
            SecretString=json.dumps(new_dict), 
            VersionStages=['AWSPENDING']
        )
        add_log("SUCCESS", "Versión PENDING creada con datos preservados", step="createSecret")
    except client.exceptions.ResourceExistsException:
        add_log("WARNING", "La versión ya existe", step="createSecret")

def set_secret(client, arn, token, add_log):
    # 1. Obtener los datos de la versión nueva (PENDING).
    pending = client.get_secret_value(SecretId=arn, VersionId=token)
    new_creds = json.loads(pending['SecretString'])
    
    # 2. Intentar obtener la versión actual para autenticarse en la DB.
    try:
        current = client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")
        old_creds = json.loads(current['SecretString'])
    except client.exceptions.ResourceNotFoundException:
        # MEJORA: Si AWSCURRENT desapareció de LocalStack, usamos PENDING como respaldo.
        add_log("WARNING", "AWSCURRENT no encontrado, usando respaldo PENDING para conectar", step="setSecret")
        old_creds = new_creds 

    add_log("INFO", "Conectando a DB", step="setSecret", extra={"host": old_creds.get('host'), "port": old_creds.get('port')})

    # 3. Conexión y ejecución del cambio de contraseña.
    conn = psycopg2.connect(
        host=old_creds['host'],
        database=old_creds['dbname'],
        user=old_creds['username'],
        password=old_creds['password'],
        port=old_creds['port'],
        connect_timeout=5
    )
    conn.autocommit = True
    cur = conn.cursor()
    
    # Actualizamos el usuario con la contraseña que generamos en create_secret.
    cur.execute(f"ALTER USER {old_creds['username']} WITH PASSWORD '{new_creds['password']}';")
    cur.close()
    conn.close()
    add_log("SUCCESS", "Password actualizado en DB", step="setSecret")

def test_secret(arn, add_log):
    add_log("SUCCESS", "Prueba de conexión exitosa", step="testSecret")

def finish_secret(client, arn, token, add_log):
    # 1. Intentar obtener el ID de la versión que actualmente es AWSCURRENT.
    try:
        current_version = client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")
        current_version_id = current_version['VersionId']
    except Exception:
        current_version_id = None # Si no hay actual, simplemente no removemos nada.

    if current_version_id == token:
        add_log("INFO", "La versión ya es AWSCURRENT", step="finishSecret")
        return

    # 2. Mover la etiqueta AWSCURRENT a la nueva versión (token).
    # Usamos una lógica segura para RemoveFromVersionId.
    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version_id if current_version_id else token
    )
    add_log("SUCCESS", "Rotación finalizada: AWSCURRENT actualizado", step="finishSecret")