import boto3
import requests
import json
import time
import os
from io import BytesIO

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

def is_gen_key(record):
    key = record["s3"]["object"]["key"]
    return "/gen/" in key and key.endswith(".txt")

def download_text(bucket, key):
    obj = s3.get_object(Bucket=bucket, Key=key)
    return obj["Body"].read().decode("utf-8")

def download_binary(bucket, key):
    obj = s3.get_object(Bucket=bucket, Key=key)
    return obj["Body"].read()

def extract_base_path(key):
    parts = key.split("/")
    return "/".join(parts[:-2]) + "/"

def process_message(message):
    try:
        body = json.loads(message["Body"])
        records = body.get("Records", [])

        for record in records:
            if not is_gen_key(record):
                continue

            bucket = record["s3"]["bucket"]["name"]
            gen_key = record["s3"]["object"]["key"]
            base_path = extract_base_path(gen_key)

            ref_text_key = base_path + "ref_text.txt"
            ref_audio_key = base_path + "ref.wav"

            print(f"⬇️  Downloading from s3://{bucket}/{gen_key}")
            gen_text = download_text(bucket, gen_key)
            ref_text = download_text(bucket, ref_text_key)
            ref_audio = download_binary(bucket, ref_audio_key)

            # Prepare multipart/form-data payload
            files = {
                "audio": ("ref.wav", BytesIO(ref_audio), "audio/wav"),
            }
            data = {
                "text": gen_text,
                "ref_text": ref_text
            }

            print(f"📤 Sending multipart request to {ENDPOINT_URL}")
            response = requests.post(ENDPOINT_URL, data=data, files=files, timeout=REQUEST_TIMEOUT)
            print(f"✅ Response status: {response.status_code}")

        return True

    except Exception as e:
        print(f"❌ Error processing message: {e}")
        return False

def poll_queue():
    print("🚀 Listening for messages...")
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
                print("🗑️  Deleted message")
            else:
                print("⚠️  Message left for retry")

        time.sleep(1)

if __name__ == "__main__":
    poll_queue()
