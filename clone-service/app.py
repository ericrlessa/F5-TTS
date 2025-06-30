from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import boto3
from mangum import Mangum
import os

app = FastAPI()
handler = Mangum(app)

# Set up your AWS S3 client
s3_client = boto3.client('s3')
BUCKET_NAME = os.environ.get("BUCKET_NAME")  # fallback for testing

@app.post("/clone-service")
async def clone_voice(
    model: str = Form(...),
    ref_text: str = Form(...),
    audio: UploadFile = File(...)
):
    try:
        # Read raw bytes from uploaded audio file
        audio_bytes = await audio.read()

        # Save to S3
        s3_key_audio = f"{model}/ref.wav"
        s3_key_ref_text = f"{model}/ref_text.txt"

        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key_audio,
            Body=audio_bytes,
            ContentType=audio.content_type or 'audio/wav'
        )

        s3_client.put_object(
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