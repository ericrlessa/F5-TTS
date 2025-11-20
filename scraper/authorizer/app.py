import os
import logging
import jwt
from typing import Dict, Any, Optional
from urllib import parse

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Constants
JWT_SECRET = os.environ["JWT_SECRET"]
ISSUER_URL_JWT = os.environ["ISSUER_URL_JWT"]
JWT_ALGORITHMS = ["HS256"]
JWT_AUDIENCE = "authenticated"

class AuthorizationError(Exception):
    """Custom exception for authorization failures"""
    pass

def validate_token(token: str) -> Dict[str, Any]:
    """
    Validate JWT token and return decoded payload
    """
    try:
        decoded = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=JWT_ALGORITHMS,
            audience=JWT_AUDIENCE,
            issuer=ISSUER_URL_JWT,
            options={"verify_exp": True}
        )
        return decoded
    except jwt.ExpiredSignatureError:
        logger.warning("JWT token has expired")
        raise AuthorizationError("Token expired")
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid JWT token: {str(e)}")
        raise AuthorizationError("Invalid token")
    except Exception as e:
        logger.error(f"Unexpected error during token validation: {str(e)}")
        raise AuthorizationError("Token validation failed")

def extract_token_from_header(event: Dict[str, Any]) -> Optional[str]:
    """
    Extract JWT token from Authorization header
    Returns token if found, None otherwise
    """
    try:
        auth_header = event.get('headers', {}).get('Authorization', '')
        if not auth_header:
            auth_header = event.get('headers', {}).get('authorization', '')
        
        if not auth_header:
            return None
        
        # Handle "Bearer <token>" format
        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            logger.warning("Invalid Authorization header format")
            return None
        
        return parts[1]
    except Exception as e:
        logger.error(f"Error extracting token from header: {str(e)}")
        return None

def extract_token_from_query_string(event: Dict[str, Any]) -> Optional[str]:
    """
    Extract JWT token from query string parameters
    Returns token if found, None otherwise
    """
    try:
        query_string = event.get('queryStringParameters', {})
        
        # Check for token in query string
        token = query_string.get('token')
        if token:
            return token
        
        # Also check multiValueQueryStringParameters for compatibility
        multi_value_params = event.get('multiValueQueryStringParameters', {})
        token_list = multi_value_params.get('token', [])
        if token_list:
            return token_list[0]
        
        return None
    except Exception as e:
        logger.error(f"Error extracting token from query string: {str(e)}")
        return None

def extract_token(event: Dict[str, Any]) -> str:
    """
    Extract JWT token from either Authorization header or query string
    """
    # Try header first (preferred method)
    token = extract_token_from_header(event)
    if token:
        logger.info("Token found in Authorization header")
        return token
    
    # Fall back to query string
    token = extract_token_from_query_string(event)
    if token:
        logger.info("Token found in query string")
        return token
    
    # No token found
    raise AuthorizationError("No token found in Authorization header or query string")

def generate_policy(principal_id: str, effect: str, resource: str, context: Optional[Dict] = None) -> Dict[str, Any]:
    """
    Generate IAM policy for API Gateway
    """
    policy = {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }
            ]
        }
    }
    
    if context:
        policy['context'] = context
    
    return policy

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda authorizer for API Gateway
    """
    logger.info("Starting authorizer...")
    logger.debug(f"Event: {event}")

    try:
        # Extract token from either header or query string
        token = extract_token(event)
        
        # Validate token
        decoded_payload = validate_token(token)
        
        # Get the method ARN from the event
        method_arn = event.get('methodArn')
        if not method_arn:
            logger.error("Missing methodArn in event")
            return generate_policy('unknown', 'Deny', '*')
        
        # Extract user information for context (optional but useful)
        user_context = {
            'user_id': decoded_payload.get('sub', 'unknown'),
            'issuer': decoded_payload.get('iss', ''),
            'audience': decoded_payload.get('aud', ''),
            'auth_source': 'header' if extract_token_from_header(event) else 'query_string'
        }
        
        logger.info(f"Authorized user: {user_context['user_id']} via {user_context['auth_source']}")
        
        # Generate allow policy
        return generate_policy(
            principal_id=user_context['user_id'],
            effect='Allow',
            resource=method_arn,
            context=user_context
        )
        
    except AuthorizationError as e:
        logger.warning(f"Authorization failed: {str(e)}")
        method_arn = event.get('methodArn', '*')
        return generate_policy('unauthorized', 'Deny', method_arn)
        
    except Exception as e:
        logger.error(f"Unexpected error in authorizer: {str(e)}")
        method_arn = event.get('methodArn', '*')
        return generate_policy('error', 'Deny', method_arn)