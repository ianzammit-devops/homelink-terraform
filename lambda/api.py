import json
import os
import boto3
import hmac

secrets_client = boto3.client("secretsmanager")
cached_key = None

def get_api_key(secret_name):
    response = secrets_client.get_secret_value(SecretId=secret_name)
    secret = json.loads(response["SecretString"])
    return secret["key"]

def handler(event, context):
    global cached_key

    # Load + cache secret
    if cached_key is None:
        cached_key = get_api_key(os.environ["SECRET_NAME"])

    # Normalize headers
    headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
    provided_key = headers.get("x-api-key")

    # Validate API key
    if not provided_key or not hmac.compare_digest(provided_key, cached_key):
        return {
            "statusCode": 403,
            "body": "Forbidden"
        }

    # Simple routing (optional but useful)
    path = event.get("rawPath")

    if path == "/health":
        return {
            "statusCode": 200,
            "body": "OK"
        }

    if path == "/projects":
        return {
            "statusCode": 200,
            "body": json.dumps({"projects": ["proj1", "proj2"]})
        }

    return {
        "statusCode": 404,
        "body": "Not Found"
    }