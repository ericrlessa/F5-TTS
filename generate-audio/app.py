import json
import boto3
import os
import base64
import uuid

s3 = boto3.client("s3")
BUCKET_NAME = os.environ["BUCKET_NAME"]

def lambda_handler(event, context):
    try:
        # Parse input
        body = event.get("body")
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body).decode("utf-8")
        data = json.loads(body)

        model = data.get("model")
        gen_text_b64 = data.get("gen_text")

        if not model or not gen_text_b64:
            return {"statusCode": 400, "body": "Missing 'model' or 'gen_text'"}

        # Decode and store text in S3
        text_bytes = base64.b64decode(gen_text_b64)
        text_filename = f"{uuid.uuid4()}.txt"
        s3_key = f"{model}/{text_filename}"

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key,
            Body=text_bytes,
            ContentType="text/plain"
        )

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
