from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse
import boto3
from mangum import Mangum
from urllib.parse import unquote
import os

app = FastAPI()
handler = Mangum(app)

s3_client = boto3.resource('s3')
BUCKET_NAME = os.environ.get("BUCKET_NAME")

@app.delete("/voice")
async def clone_voice(
    model: str = Query(..., description="Model name"),
    voice: str = Query(..., description="Voice name")
):
    try:

        voice_decoded = unquote(voice)

        s3_voice = f"{model}/voices/{voice_decoded}"

        print(f"s3_voice: {s3_voice}")


        bucket = s3_client.Bucket(BUCKET_NAME)

        print(f"BUCKET_NAME: {BUCKET_NAME}")

           # First, list what exists with this prefix
        objects_list = list(bucket.objects.filter(Prefix=s3_voice))
        print(f"Found {len(objects_list)} objects to delete:")  # Debug log
        
        for obj in objects_list:
            print(f"  - {obj.key}")  # Debug log
        
        if not objects_list:
            return {"message": "No objects found to delete", "prefix": s3_voice}
        
        # Perform deletion
        response = bucket.objects.filter(Prefix=s3_voice).delete()
        print(f"Delete response: {response}")  # Debug log

        return JSONResponse(
            status_code=200,
            content={
                "message": "Delete successful"
            }
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))