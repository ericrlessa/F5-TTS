import json
import boto3
import os
import base64
import uuid

import logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

REGION_NAME = os.getenv("AWS_REGION", "us-east-1")
QUEUE_URL = os.environ["SQS_QUEUE_URL"]

sqs = boto3.client("sqs", region_name=REGION_NAME)
s3 = boto3.client("s3", region_name=REGION_NAME)
BUCKET_NAME = os.environ["BUCKET_NAME"]

def lambda_handler(event, context):
    try:
        # Parse input
        body = event.get("body")
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body).decode("utf-8")
        data = json.loads(body)

        model = data.get("model")
        gen_text = data.get("gen_text")

        if not model or not gen_text:
            return {"statusCode": 400, "body": "Missing 'model' or 'gen_text'"}

        # Decode and store text in S3
        text_bytes = gen_text.encode('utf-8')
        text_filename = f"{uuid.uuid4()}.txt"
        s3_key = f"{model}/gen/{text_filename}"

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key,
            Body=text_bytes,
            ContentType="text/plain"
        )

        message_body = {
            'bucket': BUCKET_NAME,
            's3_key_gen': s3_key,
            'model': model,
            's3_key_ref_text': f"{model}/ref_text.txt",
            's3_key_ref_audio': f"{model}/ref.wav",
        }

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message_body)
        )

        logger.info(f"Uploading to S3 at key: {s3_key}")
        logger.info(f"Sending SQS message: {message_body}")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "File uploaded to S3",
                "s3_key": s3_key
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": str(e)
        }
