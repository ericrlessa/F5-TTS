import os
import boto3
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

ecs = boto3.client('ecs')

ECS_CLUSTER_NAME = os.environ.get('ECS_CLUSTER')
ECS_TASK_ARN = os.environ.get('ECS_TASK_ARN')
SERVICE_NAME = os.environ.get('SERVICE_NAME')

def suicide():
    logger.info("Starting suicide process")
    
    # Get current desired count
    logger.info(f"Getting current desired count for service {SERVICE_NAME}")
    service = ecs.describe_services(
        cluster=ECS_CLUSTER_NAME,
        services=[SERVICE_NAME]
    )['services'][0]
    
    current_desired = service['desiredCount']
    logger.info(f"Current desired count: {current_desired}")
    
    new_desired = max(0, current_desired - 1)
    logger.info(f"Updating desired count to: {new_desired}")
    
    # Update desired count first
    ecs.update_service(
        cluster=ECS_CLUSTER_NAME,
        service=SERVICE_NAME,
        desiredCount=new_desired
    )
    logger.info("Successfully updated service desired count")
    
    # Then suicide
    logger.info(f"Stopping task: {ECS_TASK_ARN}")
    ecs.stop_task(
        cluster=ECS_CLUSTER_NAME,
        task=ECS_TASK_ARN,
        reason='Nothing to do'
    )
    logger.info("Task stop command sent successfully")