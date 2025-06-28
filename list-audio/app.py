import boto3
import os
from fastapi import FastAPI, HTTPException, Query
from mangum import Mangum
from typing import List, Optional
from pydantic import BaseModel
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

app = FastAPI()
handler = Mangum(app)

REGION_NAME = os.getenv("AWS_REGION", "us-east-1")
s3 = boto3.client("s3", region_name=REGION_NAME)
BUCKET_NAME = os.environ["BUCKET_NAME"]

class AudioFile(BaseModel):
    key: str
    url: str

@app.get("/audio", response_model=List[AudioFile])
def list_audio_files(model: Optional[str] = Query(..., description="Model to search audios")):
    try:
        if not model.endswith("/"):
            model += "/"

        model += "gen/"

        logger.info(f"Listing .wav files in bucket {BUCKET_NAME} with prefix '{model}'")

        paginator = s3.get_paginator("list_objects_v2")
        page_iterator = paginator.paginate(Bucket=BUCKET_NAME, Prefix=model)

        wav_files = []
        for page in page_iterator:
            if "Contents" in page:
                wav_files.extend(
                    [obj for obj in page["Contents"] if obj["Key"].endswith(".wav")]
                )

        if not wav_files:
            return []

        wav_files_sorted = sorted(wav_files, key=lambda x: x["LastModified"])

        result = []
        for obj in wav_files_sorted:
            presigned_url = s3.generate_presigned_url(
                ClientMethod="get_object",
                Params={"Bucket": BUCKET_NAME, "Key": obj["Key"]},
                ExpiresIn=3600,
            )
            result.append({"key": obj["Key"], "url": presigned_url})

        return result

    except Exception as e:
        logger.error(f"Error listing audio files: {e}")
        raise HTTPException(status_code=500, detail=str(e))
