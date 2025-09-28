import re
from fastapi import FastAPI, Form, HTTPException
from fastapi.responses import JSONResponse
import boto3
from botocore.exceptions import ClientError
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

REGION_NAME = os.getenv("AWS_REGION", "ca-central-1")
QUEUE_URL = os.environ.get("SQS_REC_QUEUE_URL")
BUCKET_NAME = os.environ.get("BUCKET_NAME")

sqs = boto3.client("sqs", region_name=REGION_NAME)
s3 = boto3.client("s3", region_name="ca-central-1")

def file_exists(bucket_name: str, file_key: str) -> bool:
    try:
        s3.head_object(Bucket=bucket_name, Key=file_key)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            return False
        else:
            raise

@app.post("/generate-audio")
async def generate_audio_multiple_voices(
    user: str = Form(...),
    podcast: str = Form(...),
    episode: str = Form(...),
    gen_text: str = Form(...),
    extracted_content: str = Form(...),
    models: str = Form(...)
):
    try:

        models_host_guests = json.loads(models)

        logger.info(f"🎙️ Voices found: {models_host_guests}")

        voices = []
        for model in models_host_guests:
            s3_key_ref_text =  f"{model['s3_path']}/ref_text.txt"
            s3_key_ref_audio = f"{model['s3_path']}/ref.wav"

            voices.append({
                "name": model['model_name'],
                "s3_key_ref_text": s3_key_ref_text,
                "s3_key_ref_audio": s3_key_ref_audio
            })

        transcript_bytes = gen_text.encode("utf-8")
        s3_key_base = f"{user}/podcasts/{podcast}/{episode}"
        s3_key_gen_txt = f"{s3_key_base}/transcript.txt"
        s3_key_output_wav = f"{s3_key_base}/transcript.wav"

        extracted_content_bytes = extracted_content.encode("utf-8")
        s3_key_content_txt = f"{s3_key_base}/extracted_content.txt"

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key_gen_txt,
            Body=transcript_bytes,
            ContentType="text/plain"
        )

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key_content_txt,
            Body=extracted_content_bytes,
            ContentType="text/plain"
        )

        message_body = {
            "bucket": BUCKET_NAME,
            "s3_key_gen": s3_key_gen_txt,
            "s3_key_output": s3_key_output_wav,
            "voices": voices
        }

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message_body)
        )

        logger.info(f"✅ Uploaded text to S3: {s3_key_gen_txt}")
        logger.info(f"📤 Sent SQS message: {message_body}")

        return JSONResponse(
            status_code=200,
            content={"message": f"Text added to the queue. Audio generation will begin shortly. File to be processed: {s3_key_gen_txt}"}
        )

    except Exception as e:
        logger.exception("❌ Failed to process form submission")
        raise HTTPException(status_code=500, detail=str(e))