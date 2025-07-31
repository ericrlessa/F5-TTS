import boto3
import os
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from mangum import Mangum
from typing import List, Optional
from pydantic import BaseModel
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

app = FastAPI()
handler = Mangum(app)

app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

s3 = boto3.client("s3", region_name="ca-central-1")
BUCKET_NAME = os.environ["BUCKET_NAME"]

class AudioFile(BaseModel):
    key: str
    url_txt: str
    url_wav: Optional[str]

def generate_presigned_url(key):
    return s3.generate_presigned_url(
                        ClientMethod="get_object",
                        Params={"Bucket": BUCKET_NAME, "Key": key},
                        ExpiresIn=3600,
                    )

@app.get("/", response_class=HTMLResponse)
async def homepage(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/audio", response_model=List[AudioFile])
def list_audio_files(model: Optional[str] = Query(..., description="Model to search audios"),
                         referenceAudio: bool = Query(False, description="Return reference audio?")):
    try:
        if not model.endswith("/"):
            model += "/"

        logger.info(f"Listing .wav and .txt files in bucket {BUCKET_NAME} with prefix '{model}'")

        paginator = s3.get_paginator("list_objects_v2")
        page_iterator = paginator.paginate(Bucket=BUCKET_NAME, Prefix=model)

        wav_files = []
        txt_files = []

        for page in page_iterator:
            if "Contents" in page:
                for obj in page["Contents"]:
                    key = obj["Key"]
                    isReferenceAudio = key.endswith("ref.wav")
                    isReferenceText = key.endswith("ref_text.txt")
                    if key.endswith(".wav") and (
                        (not referenceAudio and not isReferenceAudio) or
                        (referenceAudio and isReferenceAudio)
                    ):
                        wav_files.append(obj)
                    elif key.endswith(".txt") and (
                        (not referenceAudio and not isReferenceText) or
                        (referenceAudio and isReferenceText)
                    ):
                        txt_files.append(obj)

        txt_files = sorted(txt_files, key=lambda x: x.get("LastModified"), reverse=True)

        result = []
        for txt in txt_files:
            key = txt["Key"]
            url_txt = generate_presigned_url(key)

            if(referenceAudio):
                key_wav = key.replace('ref_text.txt', 'ref.wav')
            else:
                matching_wavs = (wav["Key"] for wav in wav_files if wav["Key"].startswith(key.removesuffix(".txt")))
                key_wav = next(matching_wavs, None)

            url_wav = generate_presigned_url(key_wav) if key_wav else None
            
            voice = key
            parts = key.split("/")
            if len(parts) >= 3 and parts[2]:
                voice = parts[2]

            result.append({
                "key": voice,
                "url_txt": url_txt,
                "url_wav": url_wav
            })

        return result

    except Exception as e:
        logger.error(f"Error listing audio files: {e}")
        raise HTTPException(status_code=500, detail=str(e))