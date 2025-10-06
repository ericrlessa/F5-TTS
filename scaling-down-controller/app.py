import os
import json
import logging
import boto3


REGION_NAME = os.getenv("AWS_REGION", "ca-central-1")
ASG_NAME    = os.environ.get("ASG_NAME")

ecs = boto3.client('ecs', region_name=REGION_NAME)
autoscaling = boto3.client('autoscaling', region_name=REGION_NAME)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Processing {len(event['Records'])} messages")
    
    for record in event['Records']:
        try:
            message_body = record['body']
            message_id = record['messageId']
            
            logger.info(f"Processing message {message_id}")
            
            message_data = json.loads(message_body)
            
            process_message(message_data)
            
            logger.info(f"Successfully processed message {message_id}")
            
        except Exception as e:
            logger.error(f"Failed to process message {message_id}: {str(e)}")
            # Let the exception bubble up - SQS will handle retry/DLQ
            raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps(f"Processed {len(event['Records'])} messages")
    }

def process_message(message_data):
    logger.info(f"Processing: {message_data}")
    ecs_cluster_name = message_data["ecs_cluster_name"]
    ecs_service_name = message_data["ecs_service_name"]
    ecs_task_arn    = message_data["ecs_task_arn"]

    update_ecs(ecs_cluster_name, ecs_service_name, ecs_task_arn)
    update_asg()

    logger.info("Processing finished successfully")

def update_ecs(ecs_cluster_name, ecs_service_name, ecs_task_arn):
    logger.info(f"Getting current desired count for service {service}")
    service = ecs.describe_services(
        cluster=ecs_cluster_name,
        services=[ecs_service_name]
    )['services'][0]
    
    current_desired = service['desiredCount']
    logger.info(f"Current desired count: {current_desired}")
    
    new_desired = max(0, current_desired - 1)
    logger.info(f"Updating desired count to: {new_desired}")
    
    ecs.update_service(
        cluster=ecs_cluster_name,
        service=ecs_service_name,
        desiredCount=new_desired
    )
    logger.info("Successfully updated service desired count")
    
    logger.info(f"Stopping task: {ecs_task_arn}")
    ecs.stop_task(
        cluster=service,
        task=ecs_task_arn,
        reason='Nothing to do'
    )
    logger.info("Task stop command sent successfully")

def update_asg():
    # Get current ASG desired capacity
    logger.info(f"Getting current ASG desired capacity")

    asg_response = autoscaling.describe_auto_scaling_groups(
        AutoScalingGroupNames=[ASG_NAME]
    )
    
    current_asg_desired = asg_response['AutoScalingGroups'][0]['DesiredCapacity']
    logger.info(f"Current ASG desired capacity: {current_asg_desired}")
    
    new_asg_desired = max(0, current_asg_desired - 1)
    logger.info(f"Updating ASG desired capacity to: {new_asg_desired}")
    
    # Update ASG desired capacity
    autoscaling.set_desired_capacity(
        AutoScalingGroupName=ASG_NAME,
        DesiredCapacity=new_asg_desired,
        HonorCooldown=False
    )
    logger.info("Successfully updated ASG desired capacity")
