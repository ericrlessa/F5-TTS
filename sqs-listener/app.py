import boto3
import requests
import json
import time
import os
from io import BytesIO

import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 🔧 Config
QUEUE_URL = os.environ["SQS_QUEUE_URL"]
ENDPOINT_URL = os.getenv("ENDPOINT_URL", "http://localhost:8080/invocations")
REGION_NAME = os.getenv("AWS_REGION", "us-east-1")
WAIT_TIME_SECONDS = int(os.getenv("WAIT_TIME_SECONDS", 10))
MAX_MESSAGES = int(os.getenv("MAX_MESSAGES", 5))
VISIBILITY_TIMEOUT = int(os.getenv("VISIBILITY_TIMEOUT", 30))
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT_SECONDS", 3600))

# AWS clients
sqs = boto3.client("sqs", region_name=REGION_NAME)
s3 = boto3.client("s3", region_name=REGION_NAME)

def download_text(bucket, key):
    obj = s3.get_object(Bucket=bucket, Key=key)
    return obj["Body"].read().decode("utf-8")

def download_binary(bucket, key):
    obj = s3.get_object(Bucket=bucket, Key=key)
    return obj["Body"].read()

def process_message(message):
    try:
        body = json.loads(message["Body"])
        bucket = body.get("bucket")
        ref_text_key = body.get("s3_key_ref_text")
        ref_audio_key = body.get("s3_key_ref_audio")
        gen_key = body.get("s3_key_gen")
        
        ref_text = download_text(bucket, ref_text_key)
        ref_audio = download_binary(bucket, ref_audio_key)
        gen_text = download_text(bucket, gen_key)

        # Prepare multipart/form-data payload
        files = {
            "audio": ("ref.wav", BytesIO(ref_audio), "audio/wav"),
        }
        data = {
            "text": gen_text,
            "ref_text": ref_text
        }

        logger.info(f"📤 Sending multipart request to {ENDPOINT_URL}")
        response = requests.post(ENDPOINT_URL, data=data, files=files, timeout=REQUEST_TIMEOUT)
        logger.info(f"✅ Response status: {response.status_code}")

        return True

    except Exception as e:
        logger.error(f"❌ Error processing message: {e}")
        return False

def poll_queue():
    logger.info("🚀 Listening for messages...")
    while True:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=MAX_MESSAGES,
            WaitTimeSeconds=WAIT_TIME_SECONDS,
            VisibilityTimeout=VISIBILITY_TIMEOUT,
        )

        messages = response.get("Messages", [])
        if not messages:
            continue

        for msg in messages:
            receipt_handle = msg["ReceiptHandle"]
            success = process_message(msg)
            if success:
                sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=receipt_handle)
                logger.info("🗑️  Deleted message")
            else:
                logger.info("⚠️  Message left for retry")

        time.sleep(1)

if __name__ == "__main__":
    poll_queue()
