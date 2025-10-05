import os
import boto3
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

REGION_NAME = os.getenv("AWS_REGION", "ca-central-1")

ECS_CLUSTER_NAME = os.environ.get('ECS_CLUSTER')
ECS_TASK_ARN = os.environ.get('ECS_TASK_ARN')
SERVICE_NAME = os.environ.get('SERVICE_NAME')

ASG_NAME    = os.environ.get("ASG_NAME")

ecs = boto3.client('ecs', region_name=REGION_NAME)
autoscaling = boto3.client('autoscaling', region_name=REGION_NAME)

def suicide():
    logger.info("Starting suicide process")
    update_ecs()
    update_asg()
    logger.info("Suicide process finished")


def update_ecs():
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
