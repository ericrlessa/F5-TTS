import boto3
import os
from fastapi import FastAPI, HTTPException, Form
from fastapi.responses import JSONResponse
from mangum import Mangum
from typing import Optional
from pydantic import BaseModel
import logging
import json
import base64
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

app = FastAPI()
handler = Mangum(app)

s3 = boto3.client("s3", region_name="ca-central-1")
s3Resource = boto3.resource("s3")

batch = boto3.client('batch', region_name='ca-central-1')

BUCKET_NAME = os.environ["BUCKET_NAME"]

REGION_NAME = os.getenv("AWS_REGION", "ca-central-1")
JOB_DEFINITION = os.environ.get("JOB_DEFINITION")

class AudioFile(BaseModel):
    url_txt: str
    url_wav: Optional[str]

def generate_presigned_url(key):
    try:
        # Check if the object exists
        s3.head_object(Bucket=BUCKET_NAME, Key=key)
    except ClientError as e:
        if e.response['Error']['Code'] == "404":
            # Key does not exist
            return None
        else:
            raise

    # Key exists, generate presigned URL
    return s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": BUCKET_NAME, "Key": key},
        ExpiresIn=3600,
    )

@app.get("/episodes/{id}", response_model=AudioFile)
def podcast(id: str):
    try:
        logger.info(f"Generating podcast pre signed url to bucket {BUCKET_NAME} id {id}")

        txt_prefix = f"episodes/{id}/transcript.txt"
        wav_prefix = f"episodes/{id}/audio.wav"

        return {            
            "url_txt": generate_presigned_url(txt_prefix),
            "url_wav": generate_presigned_url(wav_prefix)
        }

    except Exception as e:
        logger.error(f"Error listing audio files: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def file_exists(bucket_name: str, file_key: str) -> bool:
    try:
        s3.head_object(Bucket=bucket_name, Key=file_key)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            return False
        else:
            raise

def submit_batch_job(encoded_message, estimated_duration, plan, episode):
    job_name = f"episode-{episode}"

    if not plan:
        raise Exception("Plan not defined!")

    queue = f"{plan}-job-queue"

    attemptDurationSeconds = estimated_duration + 180
    if(attemptDurationSeconds < 600):
        attemptDurationSeconds = 600

    response = batch.submit_job(
        jobName=job_name,
        jobQueue=queue,
        jobDefinition=JOB_DEFINITION,
        containerOverrides={
            'command': [
            'serve',
            '--message-body', encoded_message
            ]
        },
        timeout={
            'attemptDurationSeconds': attemptDurationSeconds
        }
    )
    
    print(f"Job submitted successfully: {response['jobId']}")
    return response

@app.post("/episodes/{id}")
async def create(
    id: str,
    gen_text: str = Form(...),
    extracted_content: str = Form(...),
    models: str = Form(...),
    estimated_duration: int = Form(...),
    plan: str = Form(...),
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
        s3_key_base = f"episodes/{id}"
        s3_key_gen_txt = f"{s3_key_base}/transcript.txt"
        s3_key_output_wav = f"{s3_key_base}/audio.wav"

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
            "voices": voices,
            "estimated_duration": estimated_duration
        }

        encoded_message = base64.b64encode(json.dumps(message_body).encode()).decode()

        submit_batch_job(encoded_message, estimated_duration, plan, id)

        logger.info(f"✅ Uploaded text to S3: {s3_key_gen_txt}")
        logger.info(f"📤 Submitted job message: {message_body}")

        return JSONResponse(
            status_code=200,
            content={"message": f"Text added to the queue. Audio generation will begin shortly. File to be processed: {s3_key_gen_txt}"}
        )

    except Exception as e:
        logger.exception("❌ Failed to process form submission")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/episodes/{id}")
async def delete(id: str):
    try:
        s3_episode = f"episodes/{id}"

        bucket = s3Resource.Bucket(BUCKET_NAME)

        response = bucket.objects.filter(Prefix=s3_episode).delete()
        print(f"Delete response: {response}")

        return JSONResponse(
            status_code=200,
            content={
                "message": "Delete successful"
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))