from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import boto3
from mangum import Mangum
import os
from pydub import AudioSegment
import io

app = FastAPI()
handler = Mangum(app)

s3_client = boto3.client('s3', 'us-east-1')
BUCKET_NAME = os.environ.get("BUCKET_NAME")

@app.post("/clone-service")
async def clone_voice(
    model: str = Form(...),
    voice: str = Form(...),
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
        s3_key_audio = f"{model}/{voice}/ref.wav"
        s3_key_ref_text = f"{model}/{voice}/ref_text.txt"

        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key_audio,
            Body=combined_bytes,
            ContentType='audio/wav'
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