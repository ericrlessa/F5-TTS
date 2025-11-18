import os
import json
import boto3
import logging
#import jwt


logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client('lambda')

SCRAPER_FUNCTION_NAME = os.environ["SCRAPER_FUNCTION_NAME"]
API_ENDPOINT = os.environ['API_GATEWAY_ENDPOINT']

apigw_management = boto3.client('apigatewaymanagementapi',
                                endpoint_url=API_ENDPOINT)

def handler(event, context):

    logger.info("Starting handler...")

    connection_id = event['requestContext']['connectionId']
    route_key = event['requestContext']['routeKey']

    
    if route_key == '$connect':
        token = event['queryStringParameters'].get('token')
        verify_supabase_token(token)

        if not verify_supabase_token(token):
            return {'statusCode': 403}
        
        logger.info("connected!")
        
        return {'statusCode': 200}
    elif route_key == 'scrape':
        try:
            logger.info("starting scrape trigger")

            body = json.loads(event.get('body', '{}'))
            url = body.get('url')
            
            if not url:
                return send_error(connection_id, "URL is required")
            
            send_message(connection_id, {
                'status': 'processing', 
                'message': 'Scraping started...'
            })
            
            trigger_async_scraping(connection_id, url)
            
            return {'statusCode': 200}
            
        except Exception as e:
            return send_error(connection_id, f"Error: {str(e)}")
    else:
        return {'statusCode': 400}

def trigger_async_scraping(connection_id, url):
    logger.info(f"Calling another lambda to scrape url: {url} and connection_id: {connection_id}")
    
    lambda_client.invoke(
        FunctionName=SCRAPER_FUNCTION_NAME,
        InvocationType='Event',
        Payload=json.dumps({
            'connectionId': connection_id,
            'url': url
        })
    )

def send_message(connection_id, message):
    try:
        logger.info(f"Sending message: {message}")
        apigw_management.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps(message).encode('utf-8')
        )
    except Exception as e:
        logger.error(f"Failed to send to {connection_id}: {e}")

def send_error(connection_id, error_message):
    send_message(connection_id, {
        'status': 'error',
        'message': error_message
    })
    return {'statusCode': 400}

#TODO AUTHENTICATION
def verify_supabase_token(token):
    JWT_SECRET = "your-supabase-jwt-secret"
    SUPABASE_URL = "https://your-project.supabase.co"
    
    try:
        print(token)
        return True
        # decoded = jwt.decode(
        #     token,
        #     JWT_SECRET,
        #     algorithms=["HS256"],
        #     audience="authenticated",
        #     issuer=SUPABASE_URL
        # )
        # return decoded
    except Exception as e:
        return None