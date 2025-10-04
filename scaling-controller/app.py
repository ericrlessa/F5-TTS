import os
import json
import logging
import boto3
import math

REGION_NAME = os.getenv("AWS_REGION", "ca-central-1")

FREE_PODCAST_QUEUE_URL  = os.environ.get("FREE_PODCAST_QUEUE_URL")
SHORT_PODCAST_QUEUE_URL  = os.environ.get("SHORT_PODCAST_QUEUE_URL")
MEDIUM_PODCAST_QUEUE_URL = os.environ.get("MEDIUM_PODCAST_QUEUE_URL")
LARGE_PODCAST_QUEUE_URL   = os.environ.get("LARGE_PODCAST_QUEUE_URL")

FREE_SERVICE_ECS   = os.environ.get("FREE_SERVICE_ECS")
SHORT_SERVICE_ECS   = os.environ.get("SHORT_SERVICE_ECS")
MEDIUM_SERVICE_ECS  = os.environ.get("MEDIUM_SERVICE_ECS")
LARGE_SERVICE_ECS    = os.environ.get("LARGE_SERVICE_ECS")

ECS_CLUSTER_NAME   = os.environ.get("ECS_CLUSTER_NAME")

sqs = boto3.client("sqs", region_name=REGION_NAME)
ecs = boto3.client("ecs", region_name=REGION_NAME)

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

    estimated_duration = message_data["estimated_duration"]
    estimated_duration = math.ceil(estimated_duration / 60)
    plan = message_data.get("plan")

    if plan and plan == 'free':
        service_ecs = FREE_SERVICE_ECS
        podcast_queue_url = FREE_PODCAST_QUEUE_URL
        messages_per_instances = 20
    elif estimated_duration <= 15:
        service_ecs = SHORT_SERVICE_ECS
        podcast_queue_url = SHORT_PODCAST_QUEUE_URL
        messages_per_instances = 10
    elif estimated_duration > 15 and estimated_duration <= 40:
        service_ecs = MEDIUM_SERVICE_ECS
        podcast_queue_url = MEDIUM_PODCAST_QUEUE_URL
        messages_per_instances = 5
    else:
        service_ecs = LARGE_SERVICE_ECS
        podcast_queue_url = LARGE_PODCAST_QUEUE_URL
        messages_per_instances = 1

    scale_ecs_service(service_ecs, podcast_queue_url, messages_per_instances)
    forward(podcast_queue_url, message_data)

def forward(queue_url, message_data):
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps(message_data)
    )

def get_total_pending_messages(queue_url):
    response = sqs.get_queue_attributes(
        QueueUrl=queue_url,
        AttributeNames=[
            'ApproximateNumberOfMessages',           # Messages available
            'ApproximateNumberOfMessagesNotVisible', # Messages in flight
            'ApproximateNumberOfMessagesDelayed'     # Delayed messages
        ]
    )
    
    attributes = response['Attributes']
    
    # Extract the counts
    available_messages = int(attributes['ApproximateNumberOfMessages'])
    in_flight_messages = int(attributes['ApproximateNumberOfMessagesNotVisible'])
    delayed_messages = int(attributes['ApproximateNumberOfMessagesDelayed'])
    total_messages = available_messages + in_flight_messages + delayed_messages
    
    return total_messages

def count_running_instances(ecs_service):
    response = ecs.describe_services(
        cluster=ECS_CLUSTER_NAME,
        services=[ecs_service]
    )

    service = response['services'][0]
    
    running_count = service['runningCount']
    desired_count = service['desiredCount']
    pending_count = service['pendingCount']

    logger.info(f"count_running_instances: running_count-{running_count} desired_count-{desired_count}, pending_count-{pending_count}")

    return running_count, desired_count, pending_count


def scale_ecs_service(ecs_service, podcast_queue_url, messages_per_instances):

    logger.info(f"Verifying service {ecs_service} to scale")

    total_pending_messages = get_total_pending_messages(podcast_queue_url)
    _, desired_count, _ = count_running_instances(ecs_service)

    logger.info(f"Total pending messages: {total_pending_messages}")

    expected_instances = math.ceil( total_pending_messages / messages_per_instances )

    logger.info(f"Expected instances: {expected_instances} Desired count: {desired_count}")

    if desired_count < expected_instances:
        scale(ecs_service, expected_instances) # scale up
    # elif desired_count > expected_instances and total_pending_messages < desired_count:
    #     kill_idle_task(ecs_service, desired_count - total_pending_messages)
    #     scale(ecs_service, total_pending_messages) # scale down, there is instance doing nothing


def scale(service, desiredCount):
    logger.info(f"Scaling service: {service} Desired count: {desiredCount}")
    ecs.update_service(
        cluster=ECS_CLUSTER_NAME,
        service=service,
        desiredCount=desiredCount
    )

# def kill_idle_task(service, number_tasks):
#     # Get all tasks in the service
#     response = ecs.list_tasks(
#         cluster=ECS_CLUSTER_NAME,
#         serviceName=service
#     )
    
#     task_arns = response['taskArns']
    
#     tasks = ecs.describe_tasks(
#         cluster=ECS_CLUSTER_NAME,
#         tasks=task_arns
#     )['tasks']
    
#     tasks_killed = 0
#     for task in tasks:
#         # Get the task's private IP
#         eni = task['attachments'][0]['details']
#         private_ip = next(d['value'] for d in eni if d['name'] == 'privateIPv4Address')
        
#         # Call /ping endpoint
#         try:
#             response = requests.get(f'http://{private_ip}:8080/ping', timeout=5)

#             if not is_processing(response):
#                 stop(task['taskArn'])
#                 tasks_killed = tasks_killed + 1
#                 if tasks_killed >= number_tasks:
#                     break;

#         except Exception as e:
#             print(f"Task {task['taskArn']} failed: {e}")


# def stop(task):
#     ecs.stop_task(
#         cluster=ECS_CLUSTER_NAME,
#         task=task,
#         reason='Manual stop'
#     )

# def is_processing(response):
#     if response.status_code != 200:
#         return False
#     else:
#         json_data = response.json()
#         return json_data.processing


    