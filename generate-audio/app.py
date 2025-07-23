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

REGION_NAME = os.getenv("AWS_REGION", "us-east-1")
QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
BUCKET_NAME = os.environ.get("BUCKET_NAME")

sqs = boto3.client("sqs", region_name=REGION_NAME)
s3 = boto3.client("s3", region_name="us-east-1")

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
    gen_text: str = Form(...)
):
    try:
        # Extract all names in brackets at the start of a line, e.g. [John], [Maria]
        name_pattern = r"^\[(.+?)\]"  # match [Name] at beginning of line
        names = re.findall(name_pattern, gen_text, flags=re.MULTILINE)

        # Remove duplicates while preserving order
        seen = set()
        unique_names = [n for n in names if not (n in seen or seen.add(n))]

        logger.info(f"🎙️ Voices found: {unique_names}")

        voices = []
        for voice_name in unique_names:
            pre_defined = file_exists(BUCKET_NAME, f"pre-defined/{voice_name}/ref.wav")
            if not pre_defined and not file_exists(BUCKET_NAME, f"{user}/voices/{voice_name}/ref.wav"):
                raise HTTPException(status_code=501, detail=f"Voice not found: {voice_name}")

            if pre_defined:
                s3_key_ref_text =  f"pre-defined/{voice_name}/ref_text.txt"
                s3_key_ref_audio = f"pre-defined/{voice_name}/ref.wav"
            else:
                s3_key_ref_text =  f"{user}/voices/{voice_name}/ref_text.txt"
                s3_key_ref_audio = f"{user}/voices/{voice_name}/ref.wav"

            voices.append({
                "name": voice_name,
                "s3_key_ref_text": s3_key_ref_text,
                "s3_key_ref_audio": s3_key_ref_audio
            })

        text_bytes = gen_text.encode("utf-8")
        filename = f"{uuid.uuid4()}"
        s3_key = f"{user}/podcasts/{podcast}/{episode}/{filename}"
        s3_key_gen_txt = s3_key + ".txt"
        s3_key_output_wav = s3_key + ".wav"

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key_gen_txt,
            Body=text_bytes,
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