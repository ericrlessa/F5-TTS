from fastapi import FastAPI, Form, HTTPException
from fastapi.responses import JSONResponse
import boto3
import os
import uuid
import json
from mangum import Mangum
import logging

# Setup
app = FastAPI()
handler = Mangum(app)

logger = logging.getLogger("uvicorn")
logger.setLevel(logging.INFO)

REGION_NAME = os.getenv("AWS_REGION", "us-east-1")
QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
BUCKET_NAME = os.environ.get("BUCKET_NAME")

sqs = boto3.client("sqs", region_name=REGION_NAME)
s3 = boto3.client("s3", region_name="us-east-1")

@app.post("/generate-audio")
async def generate_audio(
    model: str = Form(...),
    gen_text: str = Form(...)
):
    try:
        if not model or not gen_text:
            raise HTTPException(status_code=400, detail="Missing 'model' or 'gen_text'")

        # Save gen_text to S3
        text_bytes = gen_text.encode('utf-8')
        text_filename = f"{uuid.uuid4()}.txt"
        s3_key = f"{model}/gen/{text_filename}"

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key,
            Body=text_bytes,
            ContentType="text/plain"
        )

        # Send message to SQS
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

        logger.info(f"✅ Uploaded text to S3: {s3_key}")
        logger.info(f"📤 Sent SQS message: {message_body}")

        return JSONResponse(
            status_code=200,
            content={"message": f"Text added to the queue. Audio generation will begin shortly. File to be processed: {s3_key}"}
        )

    except Exception as e:
        logger.exception("❌ Failed to process form submission")
        raise HTTPException(status_code=500, detail=str(e))