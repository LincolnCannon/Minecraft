import json
import os
import boto3

DEFAULT_REGION = 'us-west-2'
DEFAULT_CLUSTER = 'minecraft'
DEFAULT_SERVICE = 'minecraft-server'

REGION = os.environ.get('REGION', DEFAULT_REGION)
CLUSTER = os.environ.get('CLUSTER', DEFAULT_CLUSTER)
SERVICE = os.environ.get('SERVICE', DEFAULT_SERVICE)

if REGION is None or CLUSTER is None or SERVICE is None:
    raise ValueError("Missing environment variables")

# Response headers for Lambda Function URL. Do not set Access-Control-Allow-Origin
# here — the Function URL CORS config (in CDK) sends it; sending it from Lambda too
# would duplicate the header and cause a CORS error in the browser.
HTTP_HEADERS = {
    'Content-Type': 'application/json',
}


def is_http_request(event):
    """True if this invocation is from Lambda Function URL (or API Gateway HTTP)."""
    ctx = event.get('requestContext') or {}
    return 'http' in ctx or 'httpMethod' in ctx


def http_response(status_code, body_dict):
    return {
        'statusCode': status_code,
        'headers': HTTP_HEADERS,
        'body': json.dumps(body_dict),
    }


def lambda_handler(event, context):
    """Updates the desired count for a service. Returns HTTP response when invoked via Function URL."""

    ecs = boto3.client('ecs', region_name=REGION)
    response = ecs.describe_services(
        cluster=CLUSTER,
        services=[SERVICE],
    )

    desired = response["services"][0]["desiredCount"]

    if desired == 0:
        ecs.update_service(
            cluster=CLUSTER,
            service=SERVICE,
            desiredCount=1,
        )
        print("Updated desiredCount to 1")
        if is_http_request(event):
            return http_response(200, {'status': 'started', 'message': 'Server start requested.'})
    else:
        print("desiredCount already at 1")
        if is_http_request(event):
            return http_response(200, {'status': 'already_running', 'message': 'Server is already running or starting.'})

    if is_http_request(event):
        return http_response(200, {'status': 'ok'})
