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
transform_job_name = "f5tts-batch-job"

input_s3_uri = "s3://voice-clone-f5/input/"
output_s3_uri = "s3://voice-clone-f5/output/"

sm_client = boto3.client("sagemaker", region_name=region)

# Step 1: Create Model (if not already created)
try:
    sm_client.describe_model(ModelName=model_name)
    print(f"✅ Model '{model_name}' already exists.")
except sm_client.exceptions.ValidationException:
    print(f"📦 Creating model '{model_name}'...")
    sm_client.create_model(
        ModelName=model_name,
        ExecutionRoleArn=role,
        PrimaryContainer={
            "Image": ecr_image_uri,
            "Environment": {
                "SAGEMAKER_REGION": region,
            }
        }
    )

# Step 2: Start Batch Transform Job
print(f"🚀 Starting batch transform job '{transform_job_name}'...")
sm_client.create_transform_job(
    TransformJobName=transform_job_name,
    ModelName=model_name,
    TransformInput={
        "DataSource": {
            "S3DataSource": {
                "S3DataType": "S3Prefix",
                "S3Uri": input_s3_uri
            }
        },
        "ContentType": "multipart/form-data",  # if needed; adjust based on your server
        "SplitType": "None"
    },
    TransformOutput={
        "S3OutputPath": output_s3_uri
    },
    TransformResources={
        "InstanceType": "ml.m5.xlarge",
        "InstanceCount": 1
    }
)

# Step 3: Wait for job to finish
print("⏳ Waiting for batch transform job to complete...")
while True:
    status = sm_client.describe_transform_job(TransformJobName=transform_job_name)["TransformJobStatus"]
    print(f" - Current status: {status}")
    if status in ["Completed", "Failed", "Stopped"]:
        break
    time.sleep(15)

if status == "Completed":
    print(f"✅ Batch transform job '{transform_job_name}' completed successfully.")
    print(f"📂 Output available at: {output_s3_uri}")
else:
    print(f"❌ Batch transform job failed with status: {status}")
