import boto3
import os
from fastapi import FastAPI, HTTPException, Form, UploadFile, File
from mangum import Mangum
from typing import Optional
from pydantic import BaseModel
import logging
from fastapi.responses import JSONResponse
from pydub import AudioSegment
import io

logger = logging.getLogger()
logger.setLevel(logging.INFO)

app = FastAPI()
handler = Mangum(app)

s3Resource = boto3.resource("s3")
s3 = boto3.client("s3", region_name="ca-central-1")
BUCKET_NAME = os.environ["BUCKET_NAME"]

def generate_presigned_url(key):
    return s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": BUCKET_NAME, "Key": key},
        ExpiresIn=3600,
    )

@app.get("/voices/{id}")
def voice(id: str):
    try:
        logger.info(f"Generating voice pre signed url to bucket {BUCKET_NAME} id {id}")

        wav_prefix = f"voices/{id}/ref.wav"
        txt_prefix = f"voices/{id}/ref_text.txt"

        return {            
            "url_wav": generate_presigned_url(wav_prefix),
            "url_txt": generate_presigned_url(txt_prefix)
        }

    except Exception as e:
        logger.error(f"Error listing audio files: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/voices/{id}")
async def delete(id: str):
    try:
        s3_voice = f"voices/{id}"

        bucket = s3Resource.Bucket(BUCKET_NAME)

        response = bucket.objects.filter(Prefix=s3_voice).delete()
        print(f"Delete response: {response}")

        return JSONResponse(
            status_code=200,
            content={
                "message": "Delete successful"
            }
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/voices/{id}")
async def clone(
    id: str,
    ref_text: str = Form(...),
    audio: UploadFile = File(...)
):
    try:
        # Read raw bytes from uploaded audio file
        audio_bytes = await audio.read()

        # Load audio with pydub
        audio_segment = AudioSegment.from_file(io.BytesIO(audio_bytes))

        # Generate 2 seconds of silence with same parameters as input audio
        silence = AudioSegment.silent(duration=2000, frame_rate=audio_segment.frame_rate)

        # Append silence to the original audio
        combined = audio_segment + silence

        # Export combined audio back to bytes in WAV format
        buf = io.BytesIO()
        combined.export(buf, format="wav")
        buf.seek(0)
        combined_bytes = buf.read()

        # Save to S3
        s3_key_audio = f"voices/{id}/ref.wav"
        s3_key_ref_text = f"voices/{id}/ref_text.txt"

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key_audio,
            Body=combined_bytes,
            ContentType='audio/wav'
        )

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key_ref_text,
            Body=ref_text,
            ContentType='text/plain'
        )

        return JSONResponse(
            status_code=200,
            content={
                "message": "Upload successful",
                "audio_file": s3_key_audio,
                "text_file": s3_key_ref_text
            }
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))