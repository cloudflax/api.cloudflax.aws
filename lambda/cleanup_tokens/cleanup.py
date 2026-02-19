import boto3
import json
import os
import psycopg2
from datetime import datetime

def get_secrets_manager_client():
    endpoint_url = os.environ.get('SECRETS_MANAGER_ENDPOINT', 'http://host.docker.internal:4566')
    return boto3.client('secretsmanager', endpoint_url=endpoint_url, region_name='us-east-1')

def handler(event, context):
    print("Iniciando cleanup de refresh tokens expirados")
    
    secret_arn = os.environ.get('DB_SECRET_ARN')
    if not secret_arn:
        print("ERROR: DB_SECRET_ARN no configurado")
        return {"statusCode": 500, "body": "DB_SECRET_ARN missing"}

    client = get_secrets_manager_client()
    
    try:
        # Obtener credenciales de la base de datos
        secret_value = client.get_secret_value(SecretId=secret_arn)
        creds = json.loads(secret_value['SecretString'])
        
        # Conectar a la base de datos
        conn = psycopg2.connect(
            host=creds['host'],
            database=creds['dbname'],
            user=creds['username'],
            password=creds['password'],
            port=creds['port'],
            connect_timeout=5
        )
        conn.autocommit = True
        cur = conn.cursor()
        
        query = """
            DELETE FROM public.refresh_tokens
            WHERE expires_at < NOW()
               OR revoked_at IS NOT NULL;
        """
        cur.execute(query)
        deleted_count = cur.rowcount
        
        cur.close()
        conn.close()
        
        print(f"Cleanup exitoso. Tokens eliminados: {deleted_count}")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Cleanup successful",
                "deleted_count": deleted_count
            })
        }

    except Exception as e:
        print(f"ERROR durante el cleanup: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e)
            })
        }
