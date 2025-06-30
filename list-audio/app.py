import boto3
import os
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import HTMLResponse
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

REGION_NAME = os.getenv("AWS_REGION", "us-east-1")
s3 = boto3.client("s3", region_name=REGION_NAME)
BUCKET_NAME = os.environ["BUCKET_NAME"]

class AudioFile(BaseModel):
    key: str
    url: str

@app.get("/", response_class=HTMLResponse)
async def homepage(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/audio", response_model=List[AudioFile])
def list_audio_files(model: Optional[str] = Query(..., description="Model to search audios")):
    try:
        if not model.endswith("/"):
            model += "/"
        model += "gen/"

        logger.info(f"Listing .wav and .txt files in bucket {BUCKET_NAME} with prefix '{model}'")

        paginator = s3.get_paginator("list_objects_v2")
        page_iterator = paginator.paginate(Bucket=BUCKET_NAME, Prefix=model)

        wav_files = []
        txt_files = []

        for page in page_iterator:
            if "Contents" in page:
                for obj in page["Contents"]:
                    key = obj["Key"]
                    if key.endswith(".wav"):
                        wav_files.append(obj)
                    elif key.endswith(".txt"):
                        txt_files.append(obj)

        wav_keys = {obj["Key"] for obj in wav_files}
        pending_txts = [txt for txt in txt_files if txt["Key"] + ".wav" not in wav_keys]

        all_files = wav_files + pending_txts
        if not all_files:
            return []

        all_files_sorted = sorted(all_files, key=lambda x: x.get("LastModified"), reverse=True)

        result = []
        for obj in all_files_sorted:
            key = obj["Key"]
            url = s3.generate_presigned_url(
                    ClientMethod="get_object",
                    Params={"Bucket": BUCKET_NAME, "Key": key},
                    ExpiresIn=3600,
            )

            result.append({"key": key, "url": url})

        return result

    except Exception as e:
        logger.error(f"Error listing audio files: {e}")
        raise HTTPException(status_code=500, detail=str(e))