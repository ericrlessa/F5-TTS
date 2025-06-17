import boto3
import time

# Get account and region info dynamically
session = boto3.session.Session()
region = session.region_name
account_id = boto3.client("sts").get_caller_identity()["Account"]

# Define names
role = f"arn:aws:iam::{account_id}:role/sagemaker-execution-role"
ecr_image_uri = f"{account_id}.dkr.ecr.{region}.amazonaws.com/f5tts:latest"
model_name = "f5tts-model"
endpoint_config_name = "f5tts-endpoint-config"
endpoint_name = "f5tts"

sm_client = boto3.client("sagemaker", region_name=region)

# Step 1: Create Model
sm_client.create_model(
    ModelName=model_name,
    ExecutionRoleArn=role,
    PrimaryContainer={
        "Image": ecr_image_uri,
        "Mode": "SingleModel",
        "Environment": {
            "SAGEMAKER_REGION": region,
        }
    }
)

# Step 2: Create Endpoint Config
sm_client.create_endpoint_config(
    EndpointConfigName=endpoint_config_name,
    ProductionVariants=[
        {
            "VariantName": "AllTraffic",
            "ModelName": model_name,
            "InstanceType": "ml.g4dn.xlarge",
            "InitialInstanceCount": 1,
        }
    ]
)

# Step 3: Deploy Endpoint
sm_client.create_endpoint(
    EndpointName=endpoint_name,
    EndpointConfigName=endpoint_config_name
)

# Wait for endpoint to be ready
print("⏳ Waiting for endpoint to be in service...")
while True:
    status = sm_client.describe_endpoint(EndpointName=endpoint_name)["EndpointStatus"]
    print(f" - Current status: {status}")
    if status in ["InService", "Failed"]:
        break
    time.sleep(15)

if status == "InService":
    print(f"✅ SageMaker endpoint '{endpoint_name}' is ready!")
else:
    print(f"❌ Endpoint creation failed: {status}")
